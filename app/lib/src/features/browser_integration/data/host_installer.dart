// ignore_for_file: avoid_relative_lib_imports
// Native-Messaging host installer.
//
// Writes `com.velocita.host.json` under
// `<appSupport>/velocita/native-messaging/` and (via
// [host_installer_windows.dart]) the three Windows registry keys
// pointing Chrome / Edge / Firefox at that JSON file. The file's `path`
// field is rewritten on every install (and on every app start, by
// `main.dart`) so that an exe move / rebuild self-heals without user
// action.
//
// Designed to be cross-platform in shape but currently Windows-only on
// the registry side. The JSON write itself works everywhere; on
// Linux/macOS the per-browser manifest locations are filesystem paths
// instead of registry keys — that's tracked in
// `docs/browser_integration.md` and not implemented in v1.
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import 'host_installer_windows.dart' as win;
import '../domain/browser_integration_settings.dart';

final _log = Logger('Velocita.HostInstaller');

/// The Native Messaging host name registered in every browser's lookup
/// table. MUST match the `name` the extension uses in
/// `chrome.runtime.sendNativeMessage(...)`.
const String kHostName = 'com.velocita.host';

/// The extension IDs that the host will accept messages from. Matches
/// `browser_specific_settings.gecko.id` in `manifest.firefox.json` and
/// the `id` Chrome assigns to the unpacked extension (which is
/// deterministic only if the extension ships a fixed key — for v1 we
/// accept "*" via the per-browser manifest, but the JSON here is the
/// belt-and-suspenders whitelist).
const String kExtensionIdChrome =
    'chrome-extension://__REPLACE_WITH_LOADED_ID__/';
const String kExtensionIdFirefox = 'velocita@velocita.app';

/// Directory the host JSON lives in. Created on first install.
Future<Directory> _hostJsonDir() async {
  final dir = await getApplicationSupportDirectory();
  final d = Directory('${dir.path}/velocita/native-messaging');
  await d.create(recursive: true);
  return d;
}

/// The absolute path of the host JSON file. Used as the default value
/// of every Windows registry key we create.
Future<File> _hostJsonFile() async {
  final dir = await _hostJsonDir();
  return File('${dir.path}/$kHostName.json');
}

/// Builds the host JSON content. [exePath] defaults to
/// `Platform.resolvedExecutable` if not supplied — i.e. the running
/// velocita.exe.
Map<String, Object?> buildHostJson({String? exePath}) {
  final path = exePath ?? Platform.resolvedExecutable;
  return {
    'name': kHostName,
    'description': 'Velocita download manager — Native Messaging host.',
    'path': path,
    'type': 'stdio',
    // Chrome / Edge use `allowed_origins`; Firefox uses
    // `allowed_extensions`. We write both so a single JSON works
    // for all three browsers (Chrome and Firefox will each only read
    // their own key).
    'allowed_origins': [kExtensionIdChrome],
    'allowed_extensions': [kExtensionIdFirefox],
  };
}

/// Installs the host for a single browser. Returns the absolute path
/// of the host JSON (handy for the UI to display).
Future<String> installFor(BrowserKind kind) async {
  final file = await _hostJsonFile();
  final json = buildHostJson();
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(json),
  );
  _log.info('wrote host manifest: ${file.path}');

  switch (kind) {
    case BrowserKind.chrome:
      await win.registerChrome(file.path);
    case BrowserKind.edge:
      await win.registerEdge(file.path);
    case BrowserKind.firefox:
      await win.registerFirefox(file.path);
  }
  return file.path;
}

/// Removes the host for a single browser — registry key only, leaves
/// the host JSON file in place (the user may want to inspect it).
Future<void> uninstallFor(BrowserKind kind) async {
  switch (kind) {
    case BrowserKind.chrome:
      await win.unregisterChrome();
    case BrowserKind.edge:
      await win.unregisterEdge();
    case BrowserKind.firefox:
      await win.unregisterFirefox();
  }
}

/// Removes every browser registration + the host JSON.
Future<void> uninstallAll() async {
  for (final k in BrowserKind.values) {
    try {
      await uninstallFor(k);
    } catch (e) {
      _log.warning('unregister $k failed: $e');
    }
  }
  final file = await _hostJsonFile();
  if (await file.exists()) await file.delete();
}

/// Re-writes the host JSON unconditionally. Cheap; safe to call on
/// every app start. Skips when the file already has the current
/// `Platform.resolvedExecutable` so we don't dirty the file mtime on
/// every launch.
Future<void> selfHeal() async {
  try {
    final file = await _hostJsonFile();
    final desired = buildHostJson();
    if (await file.exists()) {
      try {
        final existing =
            jsonDecode(await file.readAsString()) as Map<String, Object?>;
        if (existing['path'] == desired['path']) return;
      } catch (_) {
        // Corrupt or unreadable; fall through and rewrite.
      }
    }
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(desired),
    );
    _log.info('self-healed host manifest: ${file.path}');
  } catch (e) {
    _log.warning('self-heal failed: $e');
  }
}

/// Returns the per-browser "extensions page" URL — used by the
/// Settings UI to open the right place after install.
String extensionsPageUrl(BrowserKind kind) {
  switch (kind) {
    case BrowserKind.chrome:
      return 'chrome://extensions';
    case BrowserKind.edge:
      return 'edge://extensions';
    case BrowserKind.firefox:
      return 'about:debugging#/runtime/this-firefox';
  }
}
