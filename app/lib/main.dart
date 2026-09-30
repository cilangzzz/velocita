// ignore_for_file: avoid_relative_lib_imports
// M1: Flutter app entry — wires ProviderScope + window + tray + kernel.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/features/downloads/downloads.dart';
import 'src/kernel_bridge/kernel_bootstrap.dart';
import 'src/kernel_bridge/kernel_provider.dart';

Future<void> main() async {
  // Must be first so plugin registration and bindings are initialized before
  // anything in the app touches the engine.
  WidgetsFlutterBinding.ensureInitialized();

  // Configure logging: stderr, INFO+ for app, FINE for kernel.
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((rec) {
    // ignore: avoid_print
    stderr.writeln('[${rec.level.name.padRight(7)}] ${rec.loggerName}: ${rec.message}');
  });

  // Window manager — AppFlowy-style: do this BEFORE runApp so the first frame
  // already shows the correct size/title.
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(960, 600),
    title: 'Velocita',
    center: true,
    backgroundColor: Color(0xFF000000),
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Bootstrap the kernel (spawn aria2 → connect WS → emit EngineReady).
  // This returns once the engine is connected; a single instance is shared
  // for the app lifetime via the Riverpod provider.
  final kernel = await bootstrapKernel();
  final container = ProviderContainer(overrides: [
    kernelProvider.overrideWithValue(kernel),
    downloadsRepositoryProvider.overrideWithValue(kernel.downloadsRepository),
  ]);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const VelocitaApp(),
    ),
  );
}
