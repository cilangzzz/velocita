// ignore_for_file: avoid_relative_lib_imports
// App entry — multi-window dispatcher.
//
// Velocita uses `desktop_multi_window` to host the Add-Task dialog
// in its own OS window (independent Flutter engine). The C++ side
// (`windows/runner/multi_window.cpp`) handles the OS-level spawn
// and calls `main(args)` for each new window with the argv:
//
//   * Main window: `[]` (no extra args) — handled by the rest of this
//     file (the existing Velocita flow).
//   * Sub-window: `['multi_window', '<windowId>', '<arguments>']` —
//     dispatched to `addTaskSubWindowMain(args)` for the Add-Task
//     dialog (in `features/browser_integration/presentation/`).
//
// The same `main()` runs for both, so we have to dispatch on argv[0].
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/features/browser_integration/browser_integration.dart';
import 'src/features/browser_integration/data/host_bridge.dart';
import 'src/features/browser_integration/presentation/add_task_sub_window.dart';
import 'src/features/downloads/downloads.dart';
import 'src/kernel_bridge/kernel_bootstrap.dart';
import 'src/kernel_bridge/kernel_provider.dart';
import 'src/platform/auto_start.dart';
import 'src/platform/tray.dart';

/// Cheap read of just the `startHiddenToTray` field. We avoid the
/// `downloadSettingsProvider` here because reading it triggers
/// `bootstrapKernel` (aria2 process spawn + RPC handshake), which is
/// overkill for a single bool used to decide window visibility. The
/// JSON file is the single source of truth for the rest of the app.
Future<bool?> _readStartHiddenToTray() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/velocita/settings.json');
    if (!await file.exists()) return null;
    final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return (raw['startHiddenToTray'] as bool?) ?? true;
  } catch (_) {
    return null;
  }
}

/// The argv token the C++ side passes as `args[0]` to identify a
/// sub-window. The Add-Task sub-window reads this in
/// `addTaskSubWindowMain` and dispatches accordingly.
const String kMultiWindowChannel = 'multi_window';

/// Window-close listener: hides the window instead of letting it
/// quit. The app stays alive in the tray, ready to receive browser
/// deep links. Re-shown by clicking the tray icon or by the
/// `PendingAddRequestListener` calling `windowManager.show()` when a
/// download dialog is about to open.
class _HideOnClose extends WindowListener {
  @override
  void onWindowClose() {
    windowManager.hide();
  }
}

Future<void> main(List<String> args) async {
  // Multi-window dispatch: if argv[0] == 'multi_window' this engine
  // was spawned by `DesktopMultiWindow.createWindow` — hand off to
  // the sub-window entry. The sub-window runs an isolated Flutter
  // engine with its own widget tree; it has no Riverpod scope, no
  // main-app routes.
  if (args.isNotEmpty && args.first == kMultiWindowChannel) {
    addTaskSubWindowMain(args);
    return;
  }

  // Main window bootstrap. Everything below is unchanged from
  // before the multi-window migration.
  // Must be first so plugin registration and bindings are initialized
  // before anything in the app touches the engine.
  WidgetsFlutterBinding.ensureInitialized();

  // Configure logging: stderr, INFO+ for app, FINE for kernel.
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((rec) {
    // ignore: avoid_print
    stderr.writeln('[${rec.level.name.padRight(7)}] ${rec.loggerName}: ${rec.message}');
  });

  // Diagnostic: log the OS-spawned argv. Critical for debugging
  // `velocita://…` deep links (the `app_links` Windows plugin has
  // a hard `argc != 2` check that fails under `flutter run`; we
  // fall back to scanning this argv directly).
  Logger('Velocita.Main').info(
    'argv: ${Platform.executableArguments}',
  );

  // Window manager — must be initialised before setPreventClose,
  // the close-listener, or the tray.
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1080, 680),
    minimumSize: Size(800, 520),
    title: 'Velocita',
    center: true,
    backgroundColor: Color(0xFF000000),
  );
  // `waitUntilReadyToShow` returns once the HWND exists. We always
  // start hidden — the user invokes the main window via the tray
  // icon, a browser-extension deep link, or the `--start-minimized`
  // auto-launch case. Showing on launch is opt-in (the Settings page
  // exposes a "Start hidden to tray" toggle; default ON).
  final startHidden = (await _readStartHiddenToTray()) ?? true;
  final silentAuto = Platform.executableArguments.contains(kSilentStartFlag);
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (startHidden || silentAuto) {
      // Stay hidden in the tray. Window is created but never revealed.
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  });

  // Background mode: close button → hide window (don't quit). The
  // tray icon + its "Show Velocita" / "Quit" menu are the only
  // surface for actually terminating the process.
  await windowManager.setPreventClose(true);
  windowManager.addListener(_HideOnClose());
  // The tray needs its labels at init time (system_tray builds
  // the context menu before any widget tree exists). We hardcode
  // English for v1; a future pass can read the AppLocalizations
  // when the MaterialApp is up. The download dir is passed through to
  // the "Open downloads" item; null = item hidden.
  await VelocitaTray.tryInit(VelocitaTrayConfig(
    showLabel: 'Show Velocita',
    openDownloadsLabel: 'Open downloads folder',
    quitLabel: 'Quit Velocita',
    openDownloadsDir: null,
  ));

  // M6: try to bind the browser-integration port. If the bind fails
  // (port already in use), we're a second instance — either a Native
  // Messaging host invocation or a `velocita://…` deep-link wake-up.
  // The bridge handles both, POSTs the payload into the running
  // primary, and returns control for us to exit.
  final browserService =
      await BrowserIntegrationService.tryStart(port: 16800);
  if (browserService == null) {
    final forwarded = await runAsSecondInstance();
    if (forwarded != null) {
      Logger('Velocita.Main').info(
        'second instance forwarded to primary (source=${forwarded.source})',
      );
    }
    // Whether or not we forwarded something, the primary is running
    // and the user wants to use IT, not us. Exit cleanly.
    exit(0);
  }

  // M6: self-heal the Native Messaging host JSON. Cheap, idempotent;
  // rewrites only when the existing path differs from the current
  // `Platform.resolvedExecutable`. Keeps the registry-pointed JSON
  // in sync with the binary even when `flutter run` moves the exe
  // between builds.
  await selfHeal();
  // M6: also self-heal the `velocita://` URL-scheme registration in
  // HKCU. Without this, navigating to a `velocita://add?url=…` link
  // in a browser falls off into a blank page or a search box
  // because the OS doesn't know which exe to launch.
  await selfHealUrlScheme();

  // Bootstrap the kernel (spawn aria2 → connect WS → emit EngineReady).
  // This returns once the engine is connected; a single instance is shared
  // for the app lifetime via the Riverpod provider.
  final kernel = await bootstrapKernel();
  final container = ProviderContainer(overrides: [
    kernelProvider.overrideWithValue(kernel),
    downloadsRepositoryProvider.overrideWithValue(kernel.downloadsRepository),
    // The controller takes ownership of this service. It will keep
    // it running if the user's `enabled` setting is true, or stop
    // it immediately if they toggled the feature off last session.
    initialBrowserIntegrationServiceProvider
        .overrideWithValue(browserService),
  ]);

  // M9: route IPC results from spawned sub-windows back into the
  // existing `PendingAddRequestListener` (via the global
  // `onSubWindowAddTaskResult` stream exposed by `window_bridge.dart`).
  // Setting it here (rather than in the listener's initState) keeps
  // the listener widget dumb about the sub-window machinery.
  DesktopMultiWindow.setMethodHandler(addTaskResultHandler);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const VelocitaApp(),
    ),
  );
}
