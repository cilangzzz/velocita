import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import 'package:velocita_kernel/velocita_kernel.dart';

/// M0 prototype: spawn aria2 → connect WS → call getVersion → print.
///
/// This file lives in `tools/feat/` and is the M0 demo mandated by
/// `docs/rule/flutter_rule/12-implementation-plan.md`.
///
/// Run:
///   dart run tools/feat/aria2_ping.dart
Future<void> main(List<String> cliArgs) async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((rec) {
    stderr.writeln('[${rec.level.name}] ${rec.loggerName}: ${rec.message}');
  });

  final binaryPath = cliArgs.isNotEmpty
      ? cliArgs.first
      : Platform.script
          .resolve('../../bin/aria2c.exe')
          .toFilePath(windows: Platform.isWindows);

  // Pick a free port by binding then closing.
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close();

  final workDir = await Directory.systemTemp.createTemp('velocita_ping_');
  stderr.writeln('workDir: ${workDir.path}');
  stderr.writeln('binary: $binaryPath  port: $port');

  final secret = _randomSecret();

  final args = <String>[
    '--enable-rpc=true',
    '--rpc-listen-port=$port',
    '--rpc-listen-all=false',
    '--rpc-secret=$secret',
    '--dir=${workDir.path}',
    '--log=${workDir.path}${Platform.pathSeparator}aria2.log',
    '--log-level=warn',
    '--no-conf=true',
  ];

  final processManager = Aria2ProcessManager(
    binaryPath: binaryPath,
    workingDirectory: workDir.path,
    arguments: args,
  );

  try {
    await processManager.start();
    stderr.writeln('aria2 spawned pid=${processManager.pid}');
  } catch (e, st) {
    stderr.writeln('SPAWN FAILED: $e');
    final cause = e is AppError ? e.cause : null;
    final context = e is AppError ? e.context : null;
    stderr.writeln('CAUSE: $cause');
    stderr.writeln('CONTEXT: $context');
    stderr.writeln('STACK:\n$st');
    await workDir.delete(recursive: true);
    exit(1);
  }

  try {
    final rpc = Aria2RpcClient(secret: secret);
    await rpc.connect('ws://127.0.0.1:$port/jsonrpc');
    stderr.writeln('connected');

    final info = await rpc.getVersion();
    stderr.writeln('aria2 version: ${info.version}');
    stderr.writeln('enabled features: ${info.enabledFeatures.join(", ")}');

    // Final JSON payload on stdout (one line) — easy for tests to consume.
    stdout.writeln(jsonEncode({
      'status': 'engine_ready',
      'version': info.version,
      'features': info.enabledFeatures,
      'pid': processManager.pid,
    }));

    await rpc.shutdown();
  } catch (e, st) {
    stderr.writeln('RPC FAILED: $e');
    stderr.writeln('STACK:\n$st');
    await processManager.stop();
    await workDir.delete(recursive: true);
    exit(1);
  }

  await processManager.stop();
  await workDir.delete(recursive: true);
  stderr.writeln('clean shutdown complete');
}

String _randomSecret() {
  final r = (DateTime.now().microsecondsSinceEpoch ^ 0xA5A5A5A5).toRadixString(16);
  return 'velocita-$r';
}
