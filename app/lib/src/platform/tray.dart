// ignore_for_file: avoid_relative_lib_imports
// System tray — keeps Velocita alive when the user closes the window.
//
// Right-click menu:
//   * **Show Velocita**   — unhide + focus the main window (no-op if visible).
//   * **Open downloads**   — open the configured save directory in
//                            File Explorer (the same path aria2 writes to).
//   * **Quit Velocita**    — exit(0) after destroying the tray icon.
//
// Lifecycle:
//   1. main.dart calls `VelocitaTray.tryInit(...)` after the window is
//      ready. The icon is extracted from `assets/tray_icon.png` (via
//      the asset bundle) to a per-process temp file because
//      `system_tray` requires a filesystem path.
//   2. If init fails (missing asset, AV block, etc.) the caller logs
//      it; the app still works, just without a tray icon.
//   3. The main window's `setPreventClose(true)` +
//      `_HideOnClose.onWindowClose` route the X button to
//      `windowManager.hide()` so closing the window retreats here
//      rather than quitting the process.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:system_tray/system_tray.dart' as st;
import 'package:window_manager/window_manager.dart';

final _log = Logger('Velocita.Tray');

/// Localized labels + callbacks the tray needs at init time. We pass
/// them in (rather than reading from a context) because
/// `system_tray` constructs the menu before any widget tree exists.
/// 32x32 ARGB PNG, used as a hardcoded fallback when the asset
/// bundle's `assets/tray_icon.png` is missing or fails to load.
/// Decoded from a base64 string at runtime so the tray always has
/// a valid icon, even on a mis-pubbed build.
const String _kFallbackPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAJ0lEQVR42mNgGAWjYBSMglEwCkbBKBgFo2AUjAJWsAEAAcQAActqxKEAAAAASUVORK5CYII=';

class VelocitaTrayConfig {
  const VelocitaTrayConfig({
    required this.showLabel,
    required this.openDownloadsLabel,
    required this.quitLabel,
    required this.openDownloadsDir,
  });

  final String showLabel;
  final String openDownloadsLabel;
  final String quitLabel;
  final String? openDownloadsDir;
}

class VelocitaTray {
  VelocitaTray._(this._tray, this._iconPath);

  final st.SystemTray _tray;
  final String _iconPath;

  /// One-time init. Returns `null` if the asset is missing or the
  /// platform refuses to register a tray icon.
  static Future<VelocitaTray?> tryInit(VelocitaTrayConfig config) async {
    _log.info('VelocitaTray.tryInit: starting');

    // 1. Resolve the icon path. Try the asset bundle first, then
    // the on-disk production layout, then the hardcoded fallback.
    String? iconPath = await _extractIcon();
    if (iconPath == null) {
      _log.warning(
        'VelocitaTray: assets/tray_icon.png load failed, '
        'falling back to hardcoded PNG',
      );
      iconPath = await _extractFallback();
    }
    if (iconPath == null) {
      _log.severe('VelocitaTray: no icon available; tray will not be shown');
      return null;
    }
    _log.info('VelocitaTray: icon ready at ' + iconPath);

    st.SystemTray? t;
    try {
      t = st.SystemTray();
      await t.initSystemTray(
        title: 'Velocita',
        iconPath: iconPath,
        toolTip: 'Velocita — download manager',
      );
      _log.info('VelocitaTray: initSystemTray OK');
    } catch (e, st) {
      _log.severe('VelocitaTray: initSystemTray failed', e, st);
      try {
        final f = File(iconPath);
        if (await f.exists() && iconPath.contains('velocita_tray_')) {
          await f.delete();
        }
      } catch (_) {}
      return null;
    }

    final instance = VelocitaTray._(t, iconPath);
    try {
      await instance._installMenu(config);
    } catch (e, st) {
      _log.severe('VelocitaTray: menu install failed', e, st);
      try {
        await t.destroy();
      } catch (_) {}
      return null;
    }
    _log.info('VelocitaTray: initialized successfully');
    return instance;
  }

  Future<void> _installMenu(VelocitaTrayConfig config) async {
    final menu = st.Menu();
    // Await buildFrom BEFORE setContextMenu: buildFrom registers the
    // menu with the native MenuManager (and assigns menu.menuId). If
    // setContextMenu's SetContextMenuId runs first, the native side
    // stores a menu id that has no registered menu and right-click
    // shows nothing.
    await menu.buildFrom(<st.MenuItemBase>[
      st.MenuItemLabel(
        label: config.showLabel,
        onClicked: (_) => _showWindow(),
      ),
      if (config.openDownloadsDir != null &&
          config.openDownloadsDir!.isNotEmpty)
        st.MenuItemLabel(
          label: config.openDownloadsLabel,
          onClicked: (_) => _openDownloadsDir_(config.openDownloadsDir!),
        ),
      st.MenuSeparator(),
      st.MenuItemLabel(
        label: config.quitLabel,
        onClicked: (_) => _quit(),
      ),
    ]);
    await _tray.setContextMenu(menu);

    // system_tray 2.0.x on Windows does NOT auto-pop the context menu
    // on right-click — the native side (tray.cpp OnTrayIconCallback)
    // only fires this Dart event on WM_RBUTTONUP. We have to pop the
    // menu ourselves, otherwise the tray shows an icon with no menu.
    _tray.registerSystemTrayEventHandler((event) {
      if (event == st.kSystemTrayEventRightClick) {
        // Fire-and-forget: popUpContextMenu is async.
        _tray.popUpContextMenu();
      }
    });
  }

  static void _showWindow() {
    windowManager.show();
    windowManager.focus();
  }

  static void _openDownloadsDir_(String path) {
    // `explorer /select,<path>` highlights the directory itself
    // rather than opening its parent. The flag and the path are a
    // single argv entry so we concat.
    try {
      Process.start('explorer.exe', ['/select,$path']);
    } catch (e) {
      _log.warning('open downloads dir failed: $e');
    }
  }

  Future<void> _quit() async {
    // Destroy the icon first so the OS doesn't leave a phantom
    // tray entry during the brief moment between exit(0) and the
    // process actually tearing down.
    try {
      await _tray.destroy();
    } catch (_) {}
    try {
      final f = File(_iconPath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    exit(0);
  }

  /// Tear down the tray and delete the temp icon file.
  Future<void> dispose() async {
    await _tray.destroy();
    try {
      final f = File(_iconPath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Load `assets/tray_icon.png` from the asset bundle and write it
  /// to a per-process temp file. Returns the path, or `null` if
  /// the asset is missing.
  static Future<String?> _extractIcon() async {
    for (final candidate in _candidateOnDiskPaths()) {
      if (File(candidate).existsSync()) return candidate;
    }
    try {
      final data = await rootBundle.load('assets/tray_icon.ico');
      final bytes = data.buffer.asUint8List();
      return await _writeTempIcon(bytes);
    } catch (e) {
      _log.warning('VelocitaTray: asset bundle load failed: ' + e.toString());
      return null;
    }
  }

  /// Last-resort fallback: decode a small embedded PNG so the
  /// tray still has a valid icon even if the asset bundle is
  /// missing entirely (e.g. mis-pubbed assets list, AV blocked the
  /// asset read, etc).
  static Future<String?> _extractFallback() async {
    try {
      final bytes = base64.decode(_kFallbackPngBase64);
      return await _writeTempIcon(bytes);
    } catch (e) {
      _log.warning('VelocitaTray: fallback decode failed: ' + e.toString());
      return null;
    }
  }

  static Future<String> _writeTempIcon(Uint8List bytes) async {
    final dir = Directory.systemTemp.createTempSync('velocita_tray_');
    final f = File('' + dir.path + Platform.pathSeparator + 'tray_icon.png');
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  static List<String> _candidateOnDiskPaths() {
    final exe = Platform.resolvedExecutable;
    return [
      r'${File(exe).parent.path}\assets\tray_icon.png',
      '${File(exe).parent.path}/assets/tray_icon.png',
    ];
  }
}
