// ignore_for_file: avoid_relative_lib_imports
// Windows-side helper for [host_installer.dart].
//
// Writes the three HKCU registry entries that Chrome / Edge / Firefox
// look up to find their Native Messaging host JSON, plus the
// `velocita://` URL-scheme handler that wakes the app up when a
// browser navigates to a `velocita://add?url=…` link.
//
// Uses `Process.start('reg', [...])` so we don't have to add the
// `win32_registry` dependency — `reg.exe` ships with every Windows
// install since XP and supports `add` / `delete` out of the box.
//
// All writes are under HKCU (per-user) so no admin elevation is
// required.
//
// Public surface is the four `register*` / `unregister*` functions
// for Native Messaging plus `registerVelocitaUrlScheme` /
// `unregisterVelocitaUrlScheme` for the `velocita://` deep link.
import 'dart:io';

import 'package:logging/logging.dart';

final _log = Logger('Velocita.HostInstaller.Windows');

const String _kChromeRoot =
    r'HKCU\SOFTWARE\Google\Chrome\NativeMessagingHosts';
const String _kEdgeRoot =
    r'HKCU\SOFTWARE\Microsoft\Edge\NativeMessagingHosts';
const String _kMozillaRoot =
    r'HKCU\SOFTWARE\Mozilla\NativeMessagingHosts';

const String _kUrlSchemeRoot = r'HKCU\Software\Classes\velocita';
const String _kUrlSchemeCommand =
    r'HKCU\Software\Classes\velocita\shell\open\command';
const String _kUrlSchemeIcon = r'HKCU\Software\Classes\velocita\DefaultIcon';

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
    // IMPORTANT: do NOT pass `runInShell: true`. The Windows shell
    // mangles embedded quotes in the `/d` value (the URL-scheme
    // command we write is `"<exe>" "%1"`, which has both). Without
    // the shell in the loop, Dart's CreateProcess quoting hands the
    // value to `reg.exe` intact, and reg writes the literal string
    // including the surrounding quotes.
    final result = await Process.run('reg', args);
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

// ── velocita:// URL scheme ───────────────────────────────────

/// Registers the `velocita://` URL scheme under HKCU so that
/// navigating to `velocita://add?url=…` in any browser wakes this
/// app up instead of falling off into a blank page / search box.
///
/// Layout (per the Windows shell's URL protocol contract):
///
///     HKCU\Software\Classes\velocita
///       (Default)        = "URL:Velocita Protocol"   (description)
///       URL Protocol     = ""                        (empty, MANDATORY)
///     HKCU\Software\Classes\velocita\DefaultIcon
///       (Default)        = `<exe>,1`                 (icon ref)
///     HKCU\Software\Classes\velocita\shell\open\command
///       (Default)        = `"<exe>" "%1"`            (launcher)
Future<void> registerVelocitaUrlScheme({String? exePath}) async {
  final exe = exePath ?? Platform.resolvedExecutable;
  // Build the four registry entries, in this order:
  //   1. The (Default) description on the scheme key.
  //   2. The mandatory empty "URL Protocol" value.
  //   3. The DefaultIcon (Default) value.
  //   4. The shell\open\command (Default) value.
  // Each call uses /f to overwrite any stale value.
  final results = await Future.wait([
    _runReg([
      'add',
      _kUrlSchemeRoot,
      '/ve',
      '/t',
      'REG_SZ',
      '/d',
      'URL:Velocita Protocol',
      '/f',
    ]),
    _runReg([
      'add',
      _kUrlSchemeRoot,
      '/v',
      'URL Protocol',
      '/t',
      'REG_SZ',
      '/d',
      '',
      '/f',
    ]),
    _runReg([
      'add',
      _kUrlSchemeIcon,
      '/ve',
      '/t',
      'REG_SZ',
      '/d',
      '"$exe",1',
      '/f',
    ]),
    _runReg([
      'add',
      _kUrlSchemeCommand,
      '/ve',
      '/t',
      'REG_SZ',
      '/d',
      '"$exe" "%1"',
      '/f',
    ]),
  ]);
  for (final code in results) {
    if (code != 0) {
      throw StateError('reg add for velocita:// scheme failed ($code)');
    }
  }
  _log.info('registered velocita:// URL scheme -> $exe');
}

Future<void> unregisterVelocitaUrlScheme() async {
  // /f force-removes the whole tree, parent included. Non-zero
  // exit (key didn't exist) is treated as success.
  final code = await _runReg(['delete', _kUrlSchemeRoot, '/f']);
  if (code != 0) {
    _log.info('reg delete velocita:// scheme returned $code (treating as no-op)');
  } else {
    _log.info('unregistered velocita:// URL scheme');
  }
}
