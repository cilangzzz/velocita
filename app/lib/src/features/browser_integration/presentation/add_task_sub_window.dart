// ignore_for_file: avoid_relative_lib_imports
// Sub-window entry: the main(List<String> args) invoked by the
// C++ side when DesktopMultiWindow.createWindow() is called.
//
// Each sub-window is an isolated Flutter engine in its own OS
// window. It has no Riverpod scope from the main app, so we wrap
// the tree in a small ProviderScope with a stub downloadsRepository.
// The visible UI is the SAME AddTaskDialog the main app uses,
// opened via showDialog so its internal Navigator.pop(result)
// works as designed. When the dialog returns (confirmed or
// cancelled) we IPC the result to the main app and close the
// window.
import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velocita_kernel/velocita_kernel.dart';
import 'package:window_manager/window_manager.dart';

import '../../downloads/data/downloads_repository.dart';
import '../../downloads/presentation/add_task_dialog.dart';
import '../../../localization/app_localizations.dart';
import '../data/window_bridge.dart';

void addTaskSubWindowMain(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  if (args.isEmpty || args.first != kMultiWindowChannel) {
    debugPrint('addTaskSubWindowMain: bad channel');
    return;
  }
  if (args.length < 3) {
    debugPrint('addTaskSubWindowMain: no payload');
    return;
  }
  final raw = args[2];
  final sep = raw.indexOf(' ');
  if (sep < 0) {
    debugPrint('addTaskSubWindowMain: malformed payload');
    return;
  }
  final channel = raw.substring(0, sep);
  final payload = raw.substring(sep + 1);
  if (channel != kAddTaskChannel) {
    debugPrint('addTaskSubWindowMain: unknown channel');
    return;
  }
  AddTaskPayload parsed;
  try {
    parsed = AddTaskPayload.decode(payload);
  } catch (e) {
    debugPrint('addTaskSubWindowMain: decode failed');
    return;
  }
  runApp(AddTaskSubWindowApp(
    payload: parsed,
    subWindowId: _parseWindowIdFromArgs(args),
  ));
}

int _parseWindowIdFromArgs(List<String> args) {
  if (args.length < 2) return 0;
  return int.tryParse(args[1]) ?? 0;
}

class AddTaskSubWindowApp extends StatelessWidget {
  const AddTaskSubWindowApp({
    super.key,
    required this.payload,
    required this.subWindowId,
  });
  final AddTaskPayload payload;
  final int subWindowId;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        downloadsRepositoryProvider.overrideWithValue(
          _StubDownloadsRepository(),
        ),
      ],
      child: MaterialApp(
        title: 'Velocita - Add Download',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3F51B5),
            brightness: Brightness.light,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3F51B5),
            brightness: Brightness.dark,
          ),
        ),
        home: _SubWindowHost(
          payload: payload,
          subWindowId: subWindowId,
        ),
      ),
    );
  }
}

/// Hosts the AddTaskDialog. On first frame: show the OS window,
/// pin it always-on-top, then `showDialog` the actual dialog. When
/// the dialog resolves (confirm / cancel / barrier), IPC the result
/// to the main app and close this sub-window.
class _SubWindowHost extends StatefulWidget {
  const _SubWindowHost({
    required this.payload,
    required this.subWindowId,
  });
  final AddTaskPayload payload;
  final int subWindowId;

  @override
  State<_SubWindowHost> createState() => _SubWindowHostState();
}

class _SubWindowHostState extends State<_SubWindowHost> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;

    // 0. Size the OS window from the main-window-derived spec BEFORE
    //    showing it. Without this, the sub-window appears at the
    //    platform default size, then snaps to the desired one — a
    //    visible jump that confuses users on hi-DPI / non-uniform
    //    DPI multi-monitor setups. window_manager is registered for
    //    the sub-window's engine (see windows/runner/flutter_window.cpp).
    if (widget.payload.window != null) {
      try {
        final s = widget.payload.window!;
        await windowManager.setSize(Size(s.width, s.height));
        await ipcLog(
          'sub-window: setSize '
          '${s.width.toStringAsFixed(0)}x${s.height.toStringAsFixed(0)}',
        );
      } catch (e) {
        await ipcLog('sub-window: setSize failed: $e');
        debugPrint('sub-window: setSize failed: ' + e.toString());
      }
    }

    // 1. Bind window_manager to THIS engine's sub-window HWND.
    // `ensureInitialized` resolves the native HWND via
    // `GetAncestor(view, GA_ROOT)` on the current engine, and every
    // later windowManager call (setSize/center/setAlwaysOnTop/
    // startDragging/minimize/maximize/close) targets that HWND. If
    // we skipped this and called setSize first, the native side
    // would see hwnd=0 and silently no-op. Must run before any
    // other windowManager call.
    try {
      await windowManager.ensureInitialized();
    } catch (e) {
      debugPrint('ensureInitialized failed: ' + e.toString());
    }

    // 2. Size the now-borderless sub-window to comfortably contain the
    // dialog (~528x382 intrinsic) with a small surfaceContainer margin
    // so the dialog's 8dp rounded corners are visible as a card on
    // the window's surfaceContainer background (the ColoredBox the
    // host paints — see build()). The C++ callback has already
    // stripped the OS title bar via SetWindowLong(WS_POPUP) and
    // installed a WndProc subclass that re-applies a rounded
    // SetWindowRgn region on every WM_WINDOWPOSCHANGED (resize,
    // show, maximize, restore) — so we do not need to call it from
    // here, the region is kept correct automatically.
    try {
      await windowManager.setSize(const Size(560, 440));
      await windowManager.center();
    } catch (e) {
      debugPrint('sub-window size/center failed: ' + e.toString());
    }
    // 3. Pin it on top so it isn't buried behind other windows.
    try {
      await windowManager.setAlwaysOnTop(true);
    } catch (e) {
      debugPrint('setAlwaysOnTop failed: ' + e.toString());
    }

    // 4. Reveal the window. Sized, centered, rounded, and
    // always-on-top are all in place by this point, so the user
    // sees the final state on the first frame.
    try {
      await WindowController.fromWindowId(widget.subWindowId).show();
    } catch (e) {
      debugPrint('sub-window show failed: ' + e.toString());
    }

    if (!mounted) return;

    // 5. Show the real dialog with a custom borderless title bar.
    // AddTaskDialog renders the titleBar widget as its AlertDialog
    // `title` (with titlePadding: EdgeInsets.zero), and uses a
    // tighter 8px corner radius (set on the dialog's shape). The
    // transparent barrierColor means the host's ColoredBox
    // (surfaceContainer) shows through the scrim area outside the
    // dialog — so the dialog appears as a rounded `surface` card
    // on a `surfaceContainer` background, with no opaque black gap
    // between them. Without the transparent barrier, showDialog's
    // default scrim would paint Colors.black54 over the ColoredBox
    // and make the margin look black.
    final result = await showDialog<SubmitResult>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (_) => AddTaskDialog(
        initialUrl: widget.payload.request.url,
        titleBar: _SubWindowTitleBar(
          title: AppLocalizations.of(context).addDownloadTask,
        ),
      ),
    );

    // 6. Restore normal z-order.
    try {
      await windowManager.setAlwaysOnTop(false);
    } catch (_) {}

    // 7. Report the result back to the main app. The timeout guards
    // against a future regression where invokeMethod hangs (e.g. the
    // native channel handler being overwritten) — without it the
    // sub-window would stay open forever and the task would never be
    // created. Logging the outcome helps diagnose IPC breakage.
    await ipcLog('sub-window: dialog resolved result=${result != null}');
    try {
      if (result == null) {
        await DesktopMultiWindow.invokeMethod(
          0,
          kAddTaskResultMethod,
          const AddTaskResult.cancelled().toMap(),
        ).timeout(const Duration(seconds: 3));
      } else {
        await DesktopMultiWindow.invokeMethod(
          0,
          kAddTaskResultMethod,
          AddTaskResult.confirmed(result).toMap(),
        ).timeout(const Duration(seconds: 3));
      }
      await ipcLog('sub-window: invokeMethod OK');
    } catch (e) {
      await ipcLog('sub-window: invokeMethod failed: $e');
      debugPrint('sub-window: invokeMethod failed: ' + e.toString());
    }

    // 8. Close this sub-window.
    try {
      await WindowController.fromWindowId(widget.subWindowId).close();
    } catch (e) {
      debugPrint('close failed: ' + e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    // The sub-window is WS_POPUP (borderless) and the OS's outer
    // corners are clipped by a SetWindowRgn rounded region (set
    // from the C++ side via the `velocita/window_region` platform
    // channel) so the desktop shows through them. The remaining
    // client area is filled with a `surface` ColoredBox so the
    // Flutter engine's opaque black D3D clear color doesn't show
    // anywhere inside the rounded rectangle. Painting `surface`
    // (matching the dialog's Material) makes the whole window a
    // single rounded `surface` card with the title-bar band as the
    // only visible separation — no separate "background frame".
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: const SizedBox.expand(),
    );
  }
}

/// Stub repository for the sub-window's ProviderScope. The dialog
/// only reads `defaultSaveDir` from it; the actual enqueue happens
/// on the main app after the IPC. Aria2RpcClient(secret: '') is a
/// real-but-dormant instance so the super constructor is satisfied.
class _StubDownloadsRepository extends DownloadsRepository {
  _StubDownloadsRepository() : super(Aria2RpcClient(secret: ''));
  @override
  String? get defaultSaveDir => '';
}

/// Custom borderless title bar rendered as the AddTaskDialog's `title`
/// slot. Replaces the OS title bar (stripped via SetWindowLong in the
/// C++ callback) with our own drag area + min/max/close controls.
///
/// The drag area calls `windowManager.startDragging()` which posts
/// WM_NCLBUTTONDOWN + HTCAPTION — the OS treats this as a move request
/// regardless of the WS_POPUP style. Double-click on the drag area
/// toggles maximize.
class _SubWindowTitleBar extends StatefulWidget {
  const _SubWindowTitleBar({required this.title});
  final String title;

  @override
  State<_SubWindowTitleBar> createState() => _SubWindowTitleBarState();
}

class _SubWindowTitleBarState extends State<_SubWindowTitleBar> {
  bool _maximized = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Material(
      // Subtle distinction from the dialog body so the bar reads as a
      // separate drag region.
      color: theme.colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            // Drag area — expanded to take all remaining space, holds
            // the title text on the left. onPanStart is the canonical
            // way to start a window drag on Windows; onDoubleTap
            // toggles maximize, matching native title-bar behaviour.
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => windowManager.startDragging(),
                onDoubleTap: _toggleMax,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.title,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
            _WindowButton(
              tooltip: l.windowMinimize,
              icon: Icons.remove,
              onPressed: () => windowManager.minimize(),
            ),
            _WindowButton(
              tooltip: _maximized ? l.windowRestore : l.windowMaximize,
              icon: _maximized ? Icons.filter_none : Icons.crop_square,
              onPressed: _toggleMax,
            ),
            _WindowButton(
              tooltip: l.windowClose,
              icon: Icons.close,
              onPressed: () => windowManager.close(),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleMax() async {
    // The window is borderless (WS_POPUP) with no native min/max
    // boxes, so the only path that flips the state is this button —
    // we can toggle optimistically without consulting the engine.
    if (_maximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    if (mounted) setState(() => _maximized = !_maximized);
  }
}

/// Square 36x36 icon button used in the title bar.
class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 16),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }
}
