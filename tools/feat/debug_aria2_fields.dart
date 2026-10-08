// Debug: print raw aria2 tellStatus fields
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:velocita_kernel/velocita_kernel.dart';

Future<void> main() async {
  Logger.root.level = Level.WARNING;

  final binaryPath = Platform.script
      .resolve('../../bin/aria2c.exe')
      .toFilePath(windows: Platform.isWindows);

  final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = probe.port;
  await probe.close();

  final workDir = await Directory.systemTemp.createTemp('velocita_debug_');
  final args = <String>[
    '--enable-rpc=true',
    '--rpc-listen-port=$port',
    '--rpc-secret=test',
    '--dir=${workDir.path}',
    '--no-conf=true',
  ];

  final pm = Aria2ProcessManager(
    binaryPath: binaryPath,
    workingDirectory: workDir.path,
    arguments: args,
  );
  await pm.start();
  final rpc = Aria2RpcClient(secret: 'test');
  await rpc.connect('ws://127.0.0.1:$port/jsonrpc');

  // Add a download
  final gid = await rpc.addUri([
    'https://pic.nximg.cn/file/20201013/28754952_125226873039_2.jpg'
  ], options: {'dir': '${workDir.path}\\Images'});
  stderr.writeln('added gid=$gid');

  // Wait a moment for it to register
  await Future.delayed(const Duration(seconds: 2));

  // Print full tellStatus
  final status = await rpc.tellStatus(gid);
  stderr.writeln('\n=== tellStatus raw keys ===');
  for (final entry in status.entries) {
    stderr.writeln('  ${entry.key} = ${entry.value}');
  }

  // Try with explicit keys
  final statusWithKeys = await rpc.tellStatusWithKeys(gid, [
    'gid', 'status', 'addedAt', 'completedAt', 'totalLength'
  ]);
  stderr.writeln('\n=== tellStatus with explicit keys ===');
  for (final entry in statusWithKeys.entries) {
    stderr.writeln('  ${entry.key} = ${entry.value}');
  }

  stderr.writeln('\n=== addedAt field specifically ===');
  stderr.writeln('addedAt: ${status['addedAt']}');
  stderr.writeln('completedAt: ${status['completedAt']}');

  await Future.delayed(const Duration(seconds: 5));
  final status2 = await rpc.tellStatus(gid);
  stderr.writeln('\n=== after 5s ===');
  stderr.writeln('status: ${status2['status']}');
  stderr.writeln('addedAt: ${status2['addedAt']}');
  stderr.writeln('completedAt: ${status2['completedAt']}');

  await rpc.shutdown();
  await pm.stop();
}
