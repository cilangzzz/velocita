// ignore_for_file: avoid_relative_lib_imports
// Cross-platform helper that opens a URL in a specific browser.
//
// Used by the "Install for {Chrome,Edge,Firefox}" flow in Settings
// to land the user on the browser's extensions page
// (chrome://extensions, edge://extensions, about:debugging#...). We
// can't just `cmd /c start <url>` because the URL uses a
// browser-specific scheme that only the matching browser handles —
// and `start` hands it to the default browser, which on most machines
// is Chrome, so opening `edge://extensions` falls off a cliff and
// Windows shows "your PC doesn't have an app to open this link".
//
// Resolution order on Windows:
//   1. `where <exe>` — honors both %PATH% and the per-machine
//      `App Paths` registry entries
//   2. Hard-coded fallback paths for the common install locations
//   3. Bare `Process.start(<exe>, [url])` — relies on %PATH% only
//
// If every lookup fails, returns `null` and the caller should surface
// a SnackBar telling the user to open the URL manually.
import 'dart:io';

import 'package:logging/logging.dart';

import '../domain/browser_integration_settings.dart';

final _log = Logger('Velocita.BrowserLauncher');

/// Returns the path of the binary used to open the URL, or `null` if
/// the browser could not be located. The browser process is spawned
/// with [url] as its only argument.
Future<String?> openInBrowser(BrowserKind kind, String url) async {
  if (!Platform.isWindows) {
    // macOS / Linux: just defer to the OS — the URL scheme lookup
    // there goes through a real registry (LSSetDefaultHandlerForURLScheme
    // / xdg-mime) that knows about `chrome://`, `edge://`, etc.
    return _openWithDefaultBrowser(url);
  }
  final exe = await _resolveExe(kind);
  if (exe == null) {
    _log.warning('could not locate ${_binaryName(kind)}');
    return null;
  }
  _log.info('launching $exe $url');
  await Process.start(exe, [url], mode: ProcessStartMode.detached);
  return exe;
}

Future<String?> _resolveExe(BrowserKind kind) async {
  final name = _binaryName(kind);
  // 1. `where` looks at %PATH% AND at the App Paths registry keys,
  //    which is the canonical Windows way to find an installed app
  //    by its short name.
  try {
    final result = await Process.run('where', [name], runInShell: true);
    if (result.exitCode == 0) {
      final first = (result.stdout as String)
          .split(RegExp(r'\r?\n'))
          .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
      if (first.isNotEmpty && File(first).existsSync()) return first;
    }
  } catch (e) {
    _log.fine('where $name failed: $e');
  }
  // 2. Common install locations — per-machine + per-user.
  for (final p in _fallbackPaths(kind)) {
    if (File(p).existsSync()) return p;
  }
  return null;
}

String _binaryName(BrowserKind kind) => switch (kind) {
      BrowserKind.chrome => 'chrome',
      BrowserKind.edge => 'msedge',
      BrowserKind.firefox => 'firefox',
    };

List<String> _fallbackPaths(BrowserKind kind) {
  final pf = Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
  final pfx86 = Platform.environment['ProgramFiles(x86)'] ??
      r'C:\Program Files (x86)';
  final local = Platform.environment['LOCALAPPDATA'] ?? '';
  switch (kind) {
    case BrowserKind.chrome:
      return [
        '$pf\\Google\\Chrome\\Application\\chrome.exe',
        '$pfx86\\Google\\Chrome\\Application\\chrome.exe',
        if (local.isNotEmpty) '$local\\Google\\Chrome\\Application\\chrome.exe',
      ];
    case BrowserKind.edge:
      return [
        '$pfx86\\Microsoft\\Edge\\Application\\msedge.exe',
        '$pf\\Microsoft\\Edge\\Application\\msedge.exe',
      ];
    case BrowserKind.firefox:
      return [
        '$pf\\Mozilla Firefox\\firefox.exe',
        '$pfx86\\Mozilla Firefox\\firefox.exe',
      ];
  }
}

Future<String?> _openWithDefaultBrowser(String url) async {
  if (Platform.isMacOS) {
    await Process.start('open', [url], mode: ProcessStartMode.detached);
  } else {
    await Process.start('xdg-open', [url], mode: ProcessStartMode.detached);
  }
  return null;
}
