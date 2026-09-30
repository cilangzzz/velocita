// ignore_for_file: avoid_relative_lib_imports
// System tray — M1 surface.
//
// Hooks the app to a small icon in the OS notification area. M2 will add
// icon assets and richer menu.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:system_tray/system_tray.dart' as st;
import 'package:window_manager/window_manager.dart';

class VelocitaTray {
  VelocitaTray._(this._tray);

  final st.SystemTray _tray;

  static Future<VelocitaTray?> tryInit() async {
    try {
      final t = st.SystemTray();
      await t.initSystemTray(
        title: 'Velocita',
        iconPath: _resolveIcon(),
        toolTip: 'Velocita — download manager',
      );
      final menu = st.Menu()
        ..buildFrom(<st.MenuItemBase>[
          st.MenuItemLabel(label: 'Show Velocita', onClicked: (_) => _showWindow()),
          st.MenuItemLabel(label: 'Quit', onClicked: (_) => exit(0)),
        ]);
      t.setContextMenu(menu);
      final instance = VelocitaTray._(t);
      debugPrint('Velocita tray initialized');
      return instance;
    } catch (e) {
      Logger('Velocita.Tray').warning('tray init failed: $e');
      return null;
    }
  }

  static void _showWindow() {
    windowManager.show();
    windowManager.focus();
  }

  Future<void> dispose() => _tray.destroy();
}

String _resolveIcon() {
  final exe = Platform.resolvedExecutable;
  for (final p in [
    '${File(exe).parent.path}/assets/tray_icon.png',
    'assets/tray_icon.png',
  ]) {
    if (File(p).existsSync()) return p;
  }
  return '';
}
