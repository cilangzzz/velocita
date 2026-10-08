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

/// Read the initial `velocita://add?url=…` deep link the OS handed
/// us in argv. Returns `null` when there is no such link, when
/// `app_links` fails, or when the URL is malformed.
///
/// Two independent paths are tried:
///   1. `app_links.getInitialLink()` — works for production builds
///      launched directly via the OS protocol handler (one argv
///      entry: the URL).
///   2. `Platform.executableArguments` scan — works for `flutter run`
///      dev mode where extra debug args push `argc` past 2 (the
///      Windows `app_links` plugin hard-rejects any `argc != 2`),
///      and as a defense in depth against the same plugin failing
///      silently in other edge cases.
Future<({String url, String? referer, String? tabTitle, String source})?>
    readInitialDeepLink() async {
  // Try `app_links` first; fall back to a direct argv scan on
  // failure (which includes the `flutter run` argc-mismatch case).
  Uri? initial;
  try {
    final appLinks = AppLinks();
    initial = await appLinks.getInitialLink();
  } catch (e) {
    _log.warning('app_links.getInitialLink failed: $e');
  }
  initial ??= _scanArgvForVelocitaLink();
  if (initial == null) return null;
  if (initial.scheme != 'velocita') return null;
  final url = initial.queryParameters['url'];
  if (url == null || url.isEmpty) return null;
  return (
    url: url,
    referer: initial.queryParameters['referer'],
    tabTitle: initial.queryParameters['tabTitle'],
    source: 'deepLink',
  );
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
///
/// Falls back to a direct `Platform.executableArguments` scan when
/// `app_links` is unavailable or rejects the current argv (the
/// Windows plugin's hard-coded `argc != 2` check is the typical
/// culprit when launching under `flutter run`).
Future<_HostProbe> _tryReadInitialDeepLink() async {
  Uri? initial;
  try {
    final appLinks = AppLinks();
    initial = await appLinks.getInitialLink();
  } catch (e) {
    _log.warning('app_links probe: $e');
  }
  initial ??= _scanArgvForVelocitaLink();
  if (initial == null) return const _HostTimeout();
  if (initial.scheme != 'velocita') return const _HostTimeout();
  return _HostDeepLink(initial);
}

/// Scan `Platform.executableArguments` for the first entry that
/// looks like a `velocita://…` URI and return it parsed. Returns
/// `null` when no such entry is present.
///
/// Used as a fallback for the `app_links` Windows plugin, which
/// hard-rejects any command line whose argc is not exactly 2
/// (`app_links_plugin.cpp` `if (argv == nullptr || argc != 2)`).
/// Under `flutter run` the exe is launched with the dev tooling's
/// own args in argv, so argc is almost always ≥3 and `app_links`
/// returns null silently.
Uri? _scanArgvForVelocitaLink() {
  for (final arg in Platform.executableArguments) {
    if (arg.startsWith('velocita://')) {
      return Uri.tryParse(arg);
    }
  }
  return null;
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
