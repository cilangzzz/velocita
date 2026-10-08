// ignore_for_file: avoid_relative_lib_imports
// Windows-side helper for [host_installer.dart].
//
// Writes the three HKCU registry entries that Chrome / Edge / Firefox
// look up to find their Native Messaging host JSON. Uses
// `Process.start('reg', [...])` so we don't have to add the
// `win32_registry` dependency — `reg.exe` ships with every Windows
// install since XP and supports `add` / `delete` out of the box.
//
// All writes are under HKCU (per-user) so no admin elevation is
// required. The default value of each key is the absolute path of
// the host JSON file; Chrome / Edge / Firefox each read that file
// when the extension calls `sendNativeMessage`.
//
// Public surface is the four `register*` / `unregister*` functions.
// The arguments are all absolute paths so the caller never has to
// know about the Windows shell.
import 'dart:io';

import 'package:logging/logging.dart';

final _log = Logger('Velocita.HostInstaller.Windows');

const String _kChromeRoot =
    r'HKCU\SOFTWARE\Google\Chrome\NativeMessagingHosts';
const String _kEdgeRoot =
    r'HKCU\SOFTWARE\Microsoft\Edge\NativeMessagingHosts';
const String _kMozillaRoot =
    r'HKCU\SOFTWARE\Mozilla\NativeMessagingHosts';

/// Registers the host for the given registry root. On any failure the
/// exception is rethrown — the Settings UI surfaces it in a SnackBar.
Future<void> _registerAt(
  String registryRoot,
  String hostName,
  String jsonPath,
) async {
  // `reg add <root>\<hostName> /ve /t REG_SZ /d "<path>" /f` writes
  // the (default) value atomically. The `/f` switch suppresses the
  // "value exists, overwrite?" prompt.
  final args = [
    'add',
    '$registryRoot\\$hostName',
    '/ve',
    '/t',
    'REG_SZ',
    '/d',
    jsonPath,
    '/f',
  ];
  final result = await _runReg(args);
  if (result != 0) {
    throw StateError(
      'reg add $registryRoot\\$hostName failed with code $result',
    );
  }
  _log.info('registered $hostName at $registryRoot -> $jsonPath');
}

Future<void> _unregisterAt(String registryRoot, String hostName) async {
  // `reg delete <root>\<hostName> /f` — non-zero exit means the key
  // didn't exist, which we treat as success (idempotent).
  final args = [
    'delete',
    '$registryRoot\\$hostName',
    '/f',
  ];
  final result = await _runReg(args);
  if (result != 0) {
    // Most likely "unable to find the specified registry key" — log
    // at info, don't throw.
    _log.info(
      'reg delete $registryRoot\\$hostName returned $result (treating as no-op)',
    );
  } else {
    _log.info('unregistered $hostName at $registryRoot');
  }
}

Future<int> _runReg(List<String> args) async {
  try {
    final result = await Process.run('reg', args, runInShell: true);
    if (result.exitCode != 0) {
      _log.warning('reg ${args.first} stderr: ${result.stderr}');
    }
    return result.exitCode;
  } on ProcessException catch (e) {
    _log.severe('failed to spawn reg.exe: $e');
    return -1;
  }
}

// ── Public API ───────────────────────────────────────────────

Future<void> registerChrome(String jsonPath) =>
    _registerAt(_kChromeRoot, 'com.velocita.host', jsonPath);
Future<void> registerEdge(String jsonPath) =>
    _registerAt(_kEdgeRoot, 'com.velocita.host', jsonPath);
Future<void> registerFirefox(String jsonPath) =>
    _registerAt(_kMozillaRoot, 'com.velocita.host', jsonPath);

Future<void> unregisterChrome() =>
    _unregisterAt(_kChromeRoot, 'com.velocita.host');
Future<void> unregisterEdge() =>
    _unregisterAt(_kEdgeRoot, 'com.velocita.host');
Future<void> unregisterFirefox() =>
    _unregisterAt(_kMozillaRoot, 'com.velocita.host');
