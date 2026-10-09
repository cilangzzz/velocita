import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../platform/auto_start.dart';
import '../../downloads/data/downloads_repository.dart';
import '../domain/download_settings.dart';

/// AsyncNotifier owning the persisted [DownloadSettings].
///
/// Pattern mirrors `categories_provider.dart`:
///   - JSON file under `<appSupport>/velocita/settings.json`
///   - load on `build()`, fall back to defaults on a corrupt file
///   - in-memory snapshot is the source of truth at runtime; aria2 is
///     kept in sync via `changeGlobalOption` after every write.
///
/// aria2 is the runtime source of truth for the live engine, but the
/// user-facing settings live in this JSON file so the choices survive
/// even when aria2 has been restarted.
final downloadSettingsProvider =
    AsyncNotifierProvider<DownloadSettingsNotifier, DownloadSettings>(
  DownloadSettingsNotifier.new,
);

class DownloadSettingsNotifier extends AsyncNotifier<DownloadSettings> {
  late File _file;

  @override
  Future<DownloadSettings> build() async {
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}/velocita/settings.json');
    await _file.parent.create(recursive: true);
    final loaded = await _load();
    // The aria2 process is fresh per app launch (`--no-conf=true`); the
    // settings we persisted last session are not yet on the engine.
    // Push them now so a user who restarts the app keeps their proxy
    // and speed limits without having to re-toggle them.
    await _hydrateEngine(loaded);
    return loaded;
  }

  /// Push every persisted field to aria2. Best-effort: any RPC error is
  /// logged and swallowed (the user can still see / fix the value from
  /// the Settings page).
  ///
  /// SOCKS5 proxies are NOT pushable through `changeGlobalOption` —
  /// aria2c rejects them at runtime. They must be set on the command
  /// line at process start; we silently skip them here and the kernel
  /// bootstrap handles them via `--all-proxy` instead.
  Future<void> _hydrateEngine(DownloadSettings s) async {
    final options = <String, Object?>{
      'dir': s.saveDir,
      // Strings, not ints — aria2's changeGlobalOption silently drops
      // integer values for numeric options (verified 1.37.0).
      'max-concurrent-downloads': '${s.maxConcurrentDownloads}',
      'max-overall-download-limit': '${s.maxOverallDownloadLimitBytesPerSec}',
      'split': '${s.split}',
      'max-connection-per-server': '${s.maxConnectionPerServer}',
      'no-proxy': s.proxyBypass,
    };
    if (s.proxyKind == ProxyKind.http) {
      options['all-proxy'] = s.buildAllProxy();
    }
    // SOCKS5 is intentionally not pushed here.
    try {
      await ref.read(downloadsRepositoryProvider).changeGlobalOption(options);
    } catch (_) {
      // Engine not ready yet, or the value is invalid for this build of
      // aria2 — either way, the in-memory snapshot is the UI source of
      // truth and the user can re-apply from the page.
    }
  }

  Future<DownloadSettings> _load() async {
    if (!await _file.exists()) {
      return _seedDefaults();
    }
    try {
      final raw =
          jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      return DownloadSettings.fromJson(raw);
    } catch (_) {
      // Corrupt file — fall back to defaults rather than crash.
      return _seedDefaults();
    }
  }

  Future<DownloadSettings> _seedDefaults() async {
    final dir = await getApplicationSupportDirectory();
    final downloads = await getDownloadsDirectory() ??
        Directory('${dir.path}/velocita/downloads');
    return DownloadSettings(
      saveDir: downloads.path,
      maxConcurrentDownloads: DownloadSettings.defaultMaxConcurrent,
      maxOverallDownloadLimitBytesPerSec: 0,
      split: DownloadSettings.defaultSplit,
      maxConnectionPerServer: DownloadSettings.defaultMaxConnPerServer,
    );
  }

  Future<void> _persist(DownloadSettings s) async {
    await _file.writeAsString(jsonEncode(s.toJson()));
  }

  /// Patch fields. The aria2 engine is updated in the same call so the
  /// UI's "save" action never leaves a stale engine config behind.
  ///
  /// Named `apply` to avoid shadowing [AsyncNotifier.update], which
  /// takes a closure to re-build the state.
  ///
  /// Proxy fields are special-cased: a single user gesture (e.g.
  /// "switch to SOCKS5") changes [proxyKind] *and* [proxyHost] in the
  /// same call, so we always rebuild the full `all-proxy` URL from the
  /// result and only push it if the URL or the bypass list actually
  /// changed. Empty host + non-`off` kind is silently dropped (it would
  /// just produce an invalid `://` URL).
  Future<void> apply({
    String? saveDir,
    int? maxConcurrentDownloads,
    int? maxOverallDownloadLimitBytesPerSec,
    ProxyKind? proxyKind,
    String? proxyHost,
    int? proxyPort,
    String? proxyUsername,
    String? proxyPassword,
    String? proxyBypass,
    int? split,
    int? maxConnectionPerServer,
    bool? autoStart,
    bool? silentStart,
    bool? startHiddenToTray,
  }) async {
    final current = state.value;
    if (current == null) return; // not loaded yet
    final next = current.copyWith(
      saveDir: saveDir,
      maxConcurrentDownloads: maxConcurrentDownloads,
      maxOverallDownloadLimitBytesPerSec:
          maxOverallDownloadLimitBytesPerSec,
      proxyKind: proxyKind,
      proxyHost: proxyHost,
      proxyPort: proxyPort,
      proxyUsername: proxyUsername,
      proxyPassword: proxyPassword,
      proxyBypass: proxyBypass,
      split: split,
      maxConnectionPerServer: maxConnectionPerServer,
      autoStart: autoStart,
      silentStart: silentStart,
      startHiddenToTray: startHiddenToTray,
    );
    final options = buildGlobalOptionPatches(current, next);
    if (options.isNotEmpty) {
      await ref.read(downloadsRepositoryProvider).changeGlobalOption(options);
    }
    // Sync OS-level autostart after the in-memory + persisted state is
    // settled. We always write the **effective** value (autoStart with
    // silentStart in the same toggle), so toggling silentStart alone
    // while autoStart is true updates the Run value too. If the user
    // turns silentStart on while autoStart is off, the silent flag is
    // persisted in settings.json for the next time they enable
    // autostart — we don't proactively register the Run entry just for
    // a silent-only change.
    if (autoStart != null || (current.autoStart && silentStart != null)) {
      try {
        await AutoStart.setEnabled(
          enable: next.autoStart,
          silent: next.silentStart,
        );
      } catch (e) {
        // Don't fail the whole apply() — the in-memory + persisted
        // state is correct; the user can retry from the toggle.
      }
    }
    state = AsyncData(next);
    await _persist(next);
  }
}

/// Compute the aria2 `changeGlobalOption` patch that turns [from] into
/// [to]. Pure function so the coercion rules are unit-testable.
///
/// IMPORTANT (verified on aria2 1.37.0): `changeGlobalOption` silently
/// IGNORES integer values for numeric options — `int 1024` reads back
/// as `0`, while `"1024"` reads back as `1024`. Numerics are therefore
/// always sent as strings.
Map<String, Object?> buildGlobalOptionPatches(
    DownloadSettings from, DownloadSettings to) {
  final options = <String, Object?>{};
  if (to.saveDir != from.saveDir) {
    options['dir'] = to.saveDir;
  }
  if (to.maxConcurrentDownloads != from.maxConcurrentDownloads) {
    options['max-concurrent-downloads'] = '${to.maxConcurrentDownloads}';
  }
  if (to.maxOverallDownloadLimitBytesPerSec !=
      from.maxOverallDownloadLimitBytesPerSec) {
    options['max-overall-download-limit'] =
        '${to.maxOverallDownloadLimitBytesPerSec}';
  }
  if (to.split != from.split) {
    options['split'] = '${to.split}';
  }
  if (to.maxConnectionPerServer != from.maxConnectionPerServer) {
    options['max-connection-per-server'] = '${to.maxConnectionPerServer}';
  }
  // `buildAllProxy` returns '' for off / socks5 / incomplete, which
  // doubles as "clear the proxy".
  if (to.buildAllProxy() != from.buildAllProxy()) {
    options['all-proxy'] = to.buildAllProxy();
  }
  if (to.proxyBypass != from.proxyBypass) {
    options['no-proxy'] = to.proxyBypass;
  }
  return options;
}
