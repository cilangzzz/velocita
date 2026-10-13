// ignore_for_file: avoid_relative_lib_imports
// AsyncNotifier owning the persisted [BrowserIntegrationSettings].
//
// Backed by a single key-value row in the `browser_integration_settings`
// table of the shared `velocita.db` (replaces the previous
// browser-integration.json file). The in-memory snapshot is the UI
// source of truth; the DB row is rebuilt on `build()` and patched
// on every `apply()` / `markInstalled()` / `markUninstalled()`.
//
// Unlike download settings, these are NOT pushed to the engine — the
// browser-integration knobs only drive the app shell's behavior.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../kernel_bridge/kernel_provider.dart';
import '../../../persistence/database.dart' show BrowserIntegrationDao;
import '../../../persistence/defaults.dart';
import '../domain/browser_integration_settings.dart';

final browserIntegrationSettingsProvider =
    AsyncNotifierProvider<BrowserIntegrationSettingsNotifier,
        BrowserIntegrationSettings>(
  BrowserIntegrationSettingsNotifier.new,
);

class BrowserIntegrationSettingsNotifier
    extends AsyncNotifier<BrowserIntegrationSettings> {
  late final BrowserIntegrationDao _dao;

  @override
  Future<BrowserIntegrationSettings> build() async {
    _dao = ref.read(appDatabaseProvider).browserIntegrationDao;
    final kv = await _dao.all();
    if (kv.isEmpty) {
      // First run: persist the defaults so the row exists, then
      // return them. This makes subsequent reads cheap and gives
      // the user something to "edit from" instead of an empty
      // state.
      const defaults = BrowserIntegrationSettings();
      await _dao.putAll(browserIntegrationKeyValue(defaults));
      return defaults;
    }
    return browserIntegrationFromMap(kv);
  }

  /// Patch fields. Persists on success; UI sees the new state on the
  /// next `ref.watch`.
  Future<void> apply({
    bool? enabled,
    bool? showConfirmationPopup,
    int? port,
    Set<BrowserKind>? installedBrowsers,
  }) async {
    final current = state.value;
    if (current == null) return;
    final next = current.copyWith(
      enabled: enabled,
      showConfirmationPopup: showConfirmationPopup,
      port: port,
      installedBrowsers: installedBrowsers,
    );
    state = AsyncData(next);
    await _dao.putAll(browserIntegrationKeyValue(next));
  }

  /// Add a browser to the [installedBrowsers] set. Idempotent.
  Future<void> markInstalled(BrowserKind kind) async {
    final current = state.value;
    if (current == null) return;
    if (current.installedBrowsers.contains(kind)) return;
    final next = current.copyWith(
      installedBrowsers: {...current.installedBrowsers, kind},
    );
    state = AsyncData(next);
    await _dao.putAll(browserIntegrationKeyValue(next));
  }

  /// Drop a browser from the [installedBrowsers] set. Idempotent.
  Future<void> markUninstalled(BrowserKind kind) async {
    final current = state.value;
    if (current == null) return;
    if (!current.installedBrowsers.contains(kind)) return;
    final next = current.copyWith(
      installedBrowsers: {
        for (final b in current.installedBrowsers)
          if (b != kind) b,
      },
    );
    state = AsyncData(next);
    await _dao.putAll(browserIntegrationKeyValue(next));
  }
}
