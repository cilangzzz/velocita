// ignore_for_file: avoid_relative_lib_imports
// App entry — wires ProviderScope + window + tray + kernel.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/features/browser_integration/browser_integration.dart';
import 'src/features/browser_integration/data/host_bridge.dart';
import 'src/features/downloads/downloads.dart';
import 'src/kernel_bridge/kernel_bootstrap.dart';
import 'src/kernel_bridge/kernel_provider.dart';
import 'src/platform/tray.dart';

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

Future<void> main() async {
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
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Background mode: close button → hide window (don't quit). The
  // tray icon + its "Show Velocita" / "Quit" menu are the only
  // surface for actually terminating the process.
  await windowManager.setPreventClose(true);
  windowManager.addListener(_HideOnClose());
  await VelocitaTray.tryInit();

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

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const VelocitaApp(),
    ),
  );
}
