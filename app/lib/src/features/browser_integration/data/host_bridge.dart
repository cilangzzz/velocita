// ignore_for_file: avoid_relative_lib_imports
// Second-instance / Native-Messaging host bridge.
//
// `main.dart` calls [runAsSecondInstance] *after* the port-bind probe
// shows the port is taken. This function races the two external-input
// sources — stdin (Native Messaging) and `app_links` initial URI
// (velocita:// wake-up) — for ~200 ms, picks the first one that
// yields a real payload, POSTs it into the primary, and signals
// `main.dart` to exit.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:logging/logging.dart';

import 'native_messaging_host.dart';

final _log = Logger('Velocita.HostBridge');

/// Maximum time we wait for either stdin (NM) or the OS-spawned URL
/// (deep link) to become readable. After this, the caller proceeds
/// with the GUI as if it were the primary.
const Duration _hostRaceWindow = Duration(milliseconds: 200);

/// Possible outcomes of the race.
sealed class _HostProbe {
  const _HostProbe();
}

class _HostNmFrame extends _HostProbe {
  const _HostNmFrame(this.frame, this.origin);
  final NativeMessagingFrame frame;
  final String origin;
}

class _HostDeepLink extends _HostProbe {
  const _HostDeepLink(this.uri);
  final Uri uri;
}

class _HostTimeout extends _HostProbe {
  const _HostTimeout();
}

/// Entry point for the "I am a second instance" branch.
///
/// Returns the URL we should forward to the primary, or `null` when
/// the race window elapsed with no input (the caller then proceeds
/// with GUI startup).
Future<({String url, String? referer, String? tabTitle, String source})?>
    runAsSecondInstance() async {
  // We don't bind here — `main.dart` already verified the port is in
  // use. Instead, race the two external-input sources.
  final nmFuture = _tryReadNativeMessagingFrame();
  final linkFuture = _tryReadInitialDeepLink();

  final first = await Future.any<_HostProbe>([
    nmFuture,
    linkFuture,
    Future<_HostProbe>.delayed(_hostRaceWindow, () => const _HostTimeout()),
  ]);

  switch (first) {
    case _HostNmFrame(:final frame):
      // Native Messaging: re-emit the JSON body into the primary, then
      // write a JSON ack back to the browser so it doesn't hang.
      final body = jsonDecode(frame.jsonText);
      if (body is! Map) {
        await writeFrame(stdout, {'ok': false, 'error': 'invalid body'});
        return null;
      }
      final url = (body['url'] as String?)?.trim();
      if (url == null || url.isEmpty) {
        await writeFrame(stdout, {'ok': false, 'error': 'missing url'});
        return null;
      }
      final ok = await _postToPrimary('/api/host', {
        'url': url,
        'referer': body['referer'],
        'tabTitle': body['tabTitle'],
        'source': 'hostForward',
      });
      await writeFrame(stdout, {
        'ok': ok,
        if (!ok) 'error': 'primary not reachable',
      });
      return (url: url, referer: null, tabTitle: null, source: 'hostForward');
    case _HostDeepLink(:final uri):
      final url = uri.queryParameters['url'];
      if (url == null || url.isEmpty) {
        _log.warning('velocita:// link has no url query param — dropping');
        return null;
      }
      await _postToPrimary('/api/deeplink', {
        'url': url,
        'referer': uri.queryParameters['referer'],
        'tabTitle': uri.queryParameters['tabTitle'],
        'source': 'deepLink',
      });
      return (
        url: url,
        referer: uri.queryParameters['referer'],
        tabTitle: uri.queryParameters['tabTitle'],
        source: 'deepLink',
      );
    case _HostTimeout():
      _log.info('race window elapsed with no input');
      return null;
  }
}

// ── NM stdin probe ───────────────────────────────────────────

/// Tries to read one full Native Messaging frame from stdin within
/// the race window. Returns `null` (via [_HostTimeout]) if no data
/// arrives in time.
Future<_HostProbe> _tryReadNativeMessagingFrame() async {
  try {
    final frame = await readFrame(stdin).timeout(_hostRaceWindow);
    // argv[1] is the caller origin (Chrome only). We don't use it
    // today but capturing it makes debugging easier.
    final origin = (Platform.executableArguments.length > 1)
        ? Platform.executableArguments[1]
        : '';
    return _HostNmFrame(frame, origin);
  } on TimeoutException {
    return const _HostTimeout();
  } on FormatException catch (e) {
    _log.warning('stdin probe: not a valid NM frame ($e)');
    return const _HostTimeout();
  } catch (e) {
    _log.warning('stdin probe: $e');
    return const _HostTimeout();
  }
}

// ── deep-link probe ──────────────────────────────────────────

/// Reads the `app_links` initial URI (the URL the OS handed us as
/// `argv[0]` when launching for a `velocita://…` click). Returns
/// [_HostTimeout] if no such URI exists.
Future<_HostProbe> _tryReadInitialDeepLink() async {
  try {
    final appLinks = AppLinks();
    final initial = await appLinks.getInitialLink();
    if (initial == null) return const _HostTimeout();
    if (initial.scheme != 'velocita') return const _HostTimeout();
    return _HostDeepLink(initial);
  } catch (e) {
    _log.warning('app_links probe: $e');
    return const _HostTimeout();
  }
}

// ── forwarders ───────────────────────────────────────────────

Future<bool> _postToPrimary(String path, Map<String, Object?> payload) async {
  HttpClient? client;
  try {
    client = HttpClient();
    final req = await client.post('127.0.0.1', 16800, path);
    req.headers.set('Content-Type', 'application/json');
    req.write(jsonEncode(payload));
    final res = await req.close();
    return res.statusCode == 200;
  } catch (e) {
    _log.warning('POST $path failed: $e');
    return false;
  } finally {
    client?.close(force: true);
  }
}
