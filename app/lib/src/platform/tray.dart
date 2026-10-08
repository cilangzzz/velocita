// ignore_for_file: avoid_relative_lib_imports
// System tray — keeps Velocita alive when the user closes the window.
//
// Clicking the X on the window no longer quits; it hides. The user
// re-opens via the tray icon, which shows + focuses the window. The
// tray's "Quit" menu item is the only way to actually terminate the
// process, which lets the user close the window and still receive
// browser-extension deep links in the background.
//
// The icon is loaded from the Flutter asset bundle (`assets/tray_icon.png`)
// and extracted to a temp file at init time because the
// `system_tray` plugin requires a filesystem path. If the asset is
// missing the init returns `null` and the caller logs it; the app
// still works, just without a tray icon.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:system_tray/system_tray.dart' as st;
import 'package:window_manager/window_manager.dart';

final _log = Logger('Velocita.Tray');

class VelocitaTray {
  VelocitaTray._(this._tray, this._iconPath);

  final st.SystemTray _tray;
  final String _iconPath;

  /// One-time init. Returns `null` if the asset is missing or the
  /// platform refuses to register a tray icon.
  static Future<VelocitaTray?> tryInit() async {
    String? iconPath;
    try {
      iconPath = await _extractIcon();
    } catch (e) {
      _log.warning('tray icon extract failed: $e');
      return null;
    }
    if (iconPath == null) {
      _log.warning('tray icon asset missing; tray will not be shown');
      return null;
    }
    try {
      final t = st.SystemTray();
      await t.initSystemTray(
        title: 'Velocita',
        iconPath: iconPath,
        toolTip: 'Velocita — download manager',
      );
      final menu = st.Menu()
        ..buildFrom(<st.MenuItemBase>[
          st.MenuItemLabel(label: 'Show Velocita', onClicked: (_) => _showWindow()),
          st.MenuItemLabel(label: 'Quit', onClicked: (_) => exit(0)),
        ]);
      t.setContextMenu(menu);
      final instance = VelocitaTray._(t, iconPath);
      _log.info('tray initialized (icon=$iconPath)');
      return instance;
    } catch (e) {
      _log.warning('tray init failed: $e');
      return null;
    }
  }

  static void _showWindow() {
    windowManager.show();
    windowManager.focus();
  }

  /// Tear down the tray and delete the temp icon file.
  Future<void> dispose() async {
    await _tray.destroy();
    try {
      final f = File(_iconPath);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // best-effort cleanup; OS reaps %TEMP% on reboot anyway
    }
  }

  /// Load `assets/tray_icon.png` from the asset bundle and write it
  /// to a per-process temp file. Returns the path, or `null` if
  /// the asset is missing.
  static Future<String?> _extractIcon() async {
    // Try the on-disk path first — production builds land the asset
    // next to the exe. Falls back to the asset bundle in dev mode.
    for (final candidate in _candidateOnDiskPaths()) {
      if (File(candidate).existsSync()) return candidate;
    }
    try {
      final data = await rootBundle.load('assets/tray_icon.png');
      final bytes = data.buffer.asUint8List();
      final dir = Directory.systemTemp.createTempSync('velocita_tray_');
      final f = File('${dir.path}/tray_icon.png');
      await f.writeAsBytes(bytes, flush: true);
      return f.path;
    } catch (e) {
      if (kDebugMode) {
        _log.warning('asset bundle has no assets/tray_icon.png: $e');
      }
      return null;
    }
  }

  static List<String> _candidateOnDiskPaths() {
    final exe = Platform.resolvedExecutable;
    return [
      '${File(exe).parent.path}\\assets\\tray_icon.png',
      '${File(exe).parent.path}/assets/tray_icon.png',
    ];
  }
}
