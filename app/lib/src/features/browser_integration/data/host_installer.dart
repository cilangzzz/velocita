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

  // The velocita:// URL scheme must be registered too — without it,
  // browser navigation to `velocita://add?url=…` falls off into a
  // blank page or a search box. Re-registering is idempotent.
  await win.registerVelocitaUrlScheme();
  // Belt-and-suspenders: also write a hand-crafted .reg file the
  // user can double-click to import if the live `reg add` path
  // failed (anti-virus blocking, shell-quoting weirdness, etc.).
  _lastRegFile = await writeRegFile(hostJsonPath: file.path);

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

/// Removes every browser registration, the `velocita://` URL scheme,
/// and the host JSON.
Future<void> uninstallAll() async {
  for (final k in BrowserKind.values) {
    try {
      await uninstallFor(k);
    } catch (e) {
      _log.warning('unregister $k failed: $e');
    }
  }
  try {
    await win.unregisterVelocitaUrlScheme();
  } catch (e) {
    _log.warning('unregister velocita:// scheme failed: $e');
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

/// Adds a browser-extension origin to the host JSON's `allowed_origins`.
///
/// An unpacked extension's `chrome.runtime.id` is derived from its on-disk
/// path and is not knowable when the host JSON is first written — hence the
/// `__REPLACE_WITH_LOADED_ID__` placeholder in [buildHostJson]. The browser
/// refuses to deliver Native-Messaging messages to an origin that isn't
/// listed, so the extension tells us its real ID over loopback HTTP
/// (`POST /api/register-extension`) and we rewrite the JSON here.
///
/// Merging (not replacing): keeps any previously-registered origins so a
/// second extension instance (e.g. one loaded unpacked and one from the
/// store) doesn't knock the first one out. `allowed_extensions` (Firefox)
/// is left untouched. No registry change needed — Chrome reads the JSON
/// fresh on every `sendNativeMessage` call.
Future<void> registerExtensionId(String extensionId) async {
  final id = extensionId.trim();
  if (id.isEmpty) return;
  final origin = id.startsWith('chrome-extension://')
      ? id
      : 'chrome-extension://$id/';
  final file = await _hostJsonFile();
  Map<String, Object?> json;
  try {
    json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
  } catch (_) {
    json = buildHostJson();
  }
  final origins = (json['allowed_origins'] as List?)
          ?.whereType<String>()
          .toList(growable: true) ??
      <String>[];
  if (!origins.contains(origin)) {
    origins.add(origin);
    json['allowed_origins'] = origins;
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );
    _log.info('registered extension origin: $origin');
  }
}

/// Self-heals the `velocita://` URL scheme registration. Cheap; safe
/// to call on every app start. Re-writes the four registry entries
/// when the launcher's path differs from the current
/// `Platform.resolvedExecutable` (e.g. after a `flutter run` rebuild
/// moved the exe, or the user installed Velocita to a new location).
Future<void> selfHealUrlScheme() async {
  try {
    await win.registerVelocitaUrlScheme();
  } catch (e) {
    _log.warning('url-scheme self-heal failed: $e');
  }
}

/// Ensures the `HKCU\…\Run\VelocitaBrowserHelper` entry exists,
/// pointing at the current `velocita.exe`. Idempotent; safe to call
/// on every settings sync. The browser helper is then up at sign-in,
/// removing the race where a download click arrives while no
/// Velocita is listening.
Future<void> ensureBrowserStartupProgram() => win.registerBrowserStartupProgram();

/// Removes the `VelocitaBrowserHelper` Run entry. Idempotent.
Future<void> removeBrowserStartupProgram() => win.unregisterBrowserStartupProgram();

/// Writes a hand-crafted `.reg` file containing every registry entry
/// the feature needs (Native Messaging host JSONs + the
/// `velocita://` URL scheme handler). The user can double-click the
/// file in Explorer to import it — useful when the live
/// `Process.run('reg', ...)` path is being blocked by antivirus, the
/// shell is mangling the value, or the install ran before the
/// per-user permission was granted.
///
/// Returns the absolute path of the generated file.
Future<File> writeRegFile({String? exePath, String? hostJsonPath}) async {
  final exe = exePath ?? Platform.resolvedExecutable;
  final json = hostJsonPath ?? (await _hostJsonFile()).path;
  final escapedExe = _escapeReg(exe);
  final escapedJson = _escapeReg(json);
  // In a .reg file:
  //   * Backslashes in the *value* must be doubled (otherwise regedit
  //     interprets them as escape sequences).
  //   * Embedded double-quotes in the value are escaped as `\"`.
  final content = StringBuffer()
    ..writeln('Windows Registry Editor Version 5.00')
    ..writeln()
    ..writeln(r'[HKEY_CURRENT_USER\Software\Google\Chrome\NativeMessagingHosts\com.velocita.host]')
    ..writeln('@="$escapedJson"')
    ..writeln()
    ..writeln(r'[HKEY_CURRENT_USER\Software\Microsoft\Edge\NativeMessagingHosts\com.velocita.host]')
    ..writeln('@="$escapedJson"')
    ..writeln()
    ..writeln(r'[HKEY_CURRENT_USER\Software\Mozilla\NativeMessagingHosts\com.velocita.host]')
    ..writeln('@="$escapedJson"')
    ..writeln()
    ..writeln(r'[HKEY_CURRENT_USER\Software\Classes\velocita]')
    ..writeln('@="URL:Velocita Protocol"')
    ..writeln('"URL Protocol"=""')
    ..writeln()
    ..writeln(r'[HKEY_CURRENT_USER\Software\Classes\velocita\DefaultIcon]')
    ..writeln('@="\\"$escapedExe\\",1"')
    ..writeln()
    ..writeln(r'[HKEY_CURRENT_USER\Software\Classes\velocita\shell\open\command]')
    ..writeln('@="\\"$escapedExe\\" \\"%1\\""')
    ..writeln();
  final dir = await _hostJsonDir();
  final out = File('${dir.path}/velocita-install.reg');
  await out.writeAsString(content.toString());
  _log.info('wrote .reg file: ${out.path}');
  return out;
}

String _escapeReg(String s) =>
    s.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

/// Path of the `.reg` file the most recent [writeRegFile] call
/// produced. `null` if the file has not been written yet in this
/// process. The Settings UI exposes a "Generate registry file"
/// button that writes + reveals this file in Explorer.
File? _lastRegFile;
File? get lastRegFilePath => _lastRegFile;

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
