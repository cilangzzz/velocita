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

    // 1. Make the OS window visible (0.2.x creates it as SW_HIDE).
    try {
      await WindowController.fromWindowId(widget.subWindowId).show();
    } catch (e) {
      debugPrint('sub-window show failed: ' + e.toString());
    }

    // 2. Pin it on top so it isn't buried behind other windows.
    // `window_manager` is registered for the sub-window's engine
    // via `DesktopMultiWindowSetWindowCreatedCallback` (see
    // windows/runner/flutter_window.cpp), so `setAlwaysOnTop`
    // targets this window.
    try {
      await windowManager.ensureInitialized();
      await windowManager.setAlwaysOnTop(true);
    } catch (e) {
      debugPrint('setAlwaysOnTop failed: ' + e.toString());
    }

    if (!mounted) return;

    // 3. Show the real dialog. AddTaskDialog's internal
    // `Navigator.pop(result)` resolves this future normally.
    final result = await showDialog<SubmitResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AddTaskDialog(
        initialUrl: widget.payload.request.url,
      ),
    );

    // 4. Restore normal z-order.
    try {
      await windowManager.setAlwaysOnTop(false);
    } catch (_) {}

    // 5. Report the result back to the main app. The timeout guards
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

    // 6. Close this sub-window.
    try {
      await WindowController.fromWindowId(widget.subWindowId).close();
    } catch (e) {
      debugPrint('close failed: ' + e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Transparent background so only the dialog is visible — the
    // OS window itself is sized by the dialog's intrinsic extent.
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.shrink(),
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
