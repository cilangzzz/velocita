// ignore_for_file: avoid_relative_lib_imports
// Windows "Run at sign-in" (autostart) integration.
//
// Writes a value under
// `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run`
// pointing at the current `velocita.exe`. The value name is
// `Velocita` so the user can recognise it in Task Manager → Startup
// and in `regedit`. Other Velocita entries (e.g. from a parallel dev
// build) are left alone — we own only the `Velocita` value.
//
// When `silent` is true, the value appends `--start-minimized`,
// which `main.dart` recognises to start the app hidden in the tray
// instead of popping the window up.
//
// HKCU writes need no elevation. We use `reg.exe` (ships with every
// Windows since XP) so we don't need to pull in a native registry
// package just for this one feature.
import 'dart:io';

import 'package:logging/logging.dart';

final _log = Logger('Velocita.AutoStart');

const String _kRunKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
const String _kValueName = 'Velocita';

/// Token `main.dart` looks for in `Platform.executableArguments` to
/// decide whether to launch hidden.
const String kSilentStartFlag = '--start-minimized';

class AutoStart {
  AutoStart._();

  /// True iff the OS will start Velocita at the next user sign-in.
  static Future<bool> isEnabled() async {
    if (!Platform.isWindows) return false;
    final r = await Process.run('reg', [
      'query',
      _kRunKey,
      '/v',
      _kValueName,
    ]);
    return r.exitCode == 0;
  }

  /// Return the persisted Run value (e.g. `"C:\...\velocita.exe" --start-minimized`),
  /// or `null` if the value is not set.
  static Future<String?> readValue() async {
    if (!Platform.isWindows) return null;
    final r = await Process.run('reg', [
      'query',
      _kRunKey,
      '/v',
      _kValueName,
    ]);
    if (r.exitCode != 0) return null;
    // `reg query /v <name>` output (en-US):
    //   HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run
    //       Velocita    REG_SZ    "C:\path\to\velocita.exe" --start-minimized
    for (final line in (r.stdout as String).split('\n')) {
      final t = line.trim();
      if (t.startsWith(_kValueName) && t.contains('REG_SZ')) {
        final i = t.indexOf('REG_SZ');
        return t.substring(i + 'REG_SZ'.length).trim();
      }
    }
    return null;
  }

  /// Add (or update) the Run value. `enable=false` removes it.
  static Future<void> setEnabled({required bool enable, required bool silent}) async {
    if (!Platform.isWindows) return;
    if (!enable) {
      await _deleteValue();
      return;
    }
    final exe = Platform.resolvedExecutable;
    final value = _buildValue(exe, silent: silent);
    final r = await Process.run('reg', [
      'add',
      _kRunKey,
      '/v',
      _kValueName,
      '/t',
      'REG_SZ',
      '/d',
      value,
      '/f',
    ]);
    if (r.exitCode != 0) {
      _log.warning('reg add failed (exit=${r.exitCode}): ${r.stderr}');
      throw const AutoStartException(
          'Failed to set Run registry value. Try running Velocita as administrator.');
    }
    _log.info('autostart enabled (silent=$silent) -> $value');
  }
}

String _buildValue(String exePath, {required bool silent}) {
  // `reg.exe` parses REG_SZ values verbatim; wrapping the path in
  // double-quotes is the safe form even when there are no spaces
  // (the OS exec layer strips a single surrounding pair).
  final path = '"$exePath"';
  return silent ? '$path $kSilentStartFlag' : path;
}

Future<void> _deleteValue() async {
  final r = await Process.run('reg', [
    'delete',
    _kRunKey,
    '/v',
    _kValueName,
    '/f',
  ]);
  if (r.exitCode == 0) {
    _log.info('autostart disabled (HKCU\\...\\Run\\Velocita removed)');
    return;
  }
  // `reg delete` exits 1 when the value didn't exist — treat as success
  // because the end state (no value) is what we wanted.
  final stderr = (r.stderr as String).toLowerCase();
  if (stderr.contains('unable to find') || stderr.contains('cannot find')) {
    return;
  }
  _log.warning('reg delete failed (exit=${r.exitCode}): ${r.stderr}');
  throw const AutoStartException('Failed to remove Run registry value.');
}

class AutoStartException implements Exception {
  const AutoStartException(this.message);
  final String message;
  @override
  String toString() => 'AutoStartException: $message';
}
