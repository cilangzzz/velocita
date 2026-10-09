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

// ── Browser startup program (HKCU Run) ──────────────────────

const String _kRunKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

/// Distinct value name so this entry is independent of the generic
/// "Start at sign-in" toggle (`Velocita`) the Settings page manages.
/// Two entries pointing at the same exe are harmless: the second
/// instance detects the busy IPC port, forwards, and exits.
const String _kBrowserRunValue = 'VelocitaBrowserHelper';

/// Writes (or refreshes) a `HKCU\...\Run` entry pointing at the
/// current `velocita.exe`, so Windows starts Velocita at sign-in and
/// the browser helper is up **before** the user opens their browser —
/// removing the race where a download click arrives while no
/// Velocita is listening.
///
/// Idempotent: safe to call on every settings sync (self-heals a
/// stale exe path after a rebuild/reinstall).
Future<void> registerBrowserStartupProgram({String? exePath}) async {
  final exe = exePath ?? Platform.resolvedExecutable;
  final value = '"$exe"';
  final code = await _runReg([
    'add',
    _kRunKey,
    '/v',
    _kBrowserRunValue,
    '/t',
    'REG_SZ',
    '/d',
    value,
    '/f',
  ]);
  if (code != 0) {
    throw StateError(
      'reg add Run\\$_kBrowserRunValue failed with code $code',
    );
  }
  _log.info('browser startup program registered -> $value');
}

/// Removes the `VelocitaBrowserHelper` Run entry. Idempotent — a
/// non-zero exit (value absent) is treated as success.
Future<void> unregisterBrowserStartupProgram() async {
  final code = await _runReg([
    'delete',
    _kRunKey,
    '/v',
    _kBrowserRunValue,
    '/f',
  ]);
  if (code != 0) {
    _log.info('reg delete Run\\$_kBrowserRunValue returned $code '
        '(treating as no-op)');
  } else {
    _log.info('browser startup program unregistered');
  }
}
