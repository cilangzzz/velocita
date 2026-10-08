// ignore_for_file: avoid_relative_lib_imports
// AsyncNotifier owning the persisted [BrowserIntegrationSettings].
//
// Mirrors the pattern in
// `features/settings/data/download_settings_provider.dart`:
//   * JSON file under `<appSupport>/velocita/browser-integration.json`
//   * load on `build()`, fall back to defaults on a corrupt file
//   * in-memory snapshot is the UI source of truth at runtime
//
// Unlike download settings, these are NOT pushed to the engine — the
// browser-integration knobs only drive the app shell's behavior.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/browser_integration_settings.dart';

final browserIntegrationSettingsProvider =
    AsyncNotifierProvider<BrowserIntegrationSettingsNotifier,
        BrowserIntegrationSettings>(
  BrowserIntegrationSettingsNotifier.new,
);

class BrowserIntegrationSettingsNotifier
    extends AsyncNotifier<BrowserIntegrationSettings> {
  late File _file;

  @override
  Future<BrowserIntegrationSettings> build() async {
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}/velocita/browser-integration.json');
    await _file.parent.create(recursive: true);
    return _load();
  }

  Future<BrowserIntegrationSettings> _load() async {
    if (!await _file.exists()) return const BrowserIntegrationSettings();
    try {
      final raw =
          jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      return BrowserIntegrationSettings.fromJson(raw);
    } catch (_) {
      return const BrowserIntegrationSettings();
    }
  }

  Future<void> _persist(BrowserIntegrationSettings s) async {
    await _file.writeAsString(jsonEncode(s.toJson()));
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
    await _persist(next);
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
    await _persist(next);
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
    await _persist(next);
  }
}
