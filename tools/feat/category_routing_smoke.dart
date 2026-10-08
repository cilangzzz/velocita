// Verify category routing: download and verify it lands in the chosen category subdir.
// Usage: dart run category_routing_smoke.dart [categoryName] [url]
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:velocita_kernel/velocita_kernel.dart';

Future<void> main(List<String> cliArgs) async {
  Logger.root.level = Level.WARNING;

  final categoryName = cliArgs.isNotEmpty ? cliArgs[0] : 'Videos';
  final url = cliArgs.length >= 2
      ? cliArgs[1]
      : 'https://speed.cloudflare.com/__down?bytes=1048576';

  final binaryPath = Platform.script
      .resolve('../../bin/aria2c.exe')
      .toFilePath(windows: Platform.isWindows);

  final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = probe.port;
  await probe.close();

  final baseDir = await Directory.systemTemp.createTemp('velocita_cat_');
  final categoryDir = Directory('${baseDir.path}\\$categoryName')..createSync();
  stderr.writeln('baseDir: ${baseDir.path}');
  stderr.writeln('categoryDir: ${categoryDir.path}');
  stderr.writeln('url: $url');

  final secret = 'velocita-cat-test';
  final args = <String>[
    '--enable-rpc=true',
    '--rpc-listen-port=$port',
    '--rpc-listen-all=false',
    '--rpc-secret=$secret',
    '--dir=${baseDir.path}',
    '--log=${baseDir.path}/aria2.log',
    '--log-level=warn',
    '--no-conf=true',
  ];

  final pm = Aria2ProcessManager(
    binaryPath: binaryPath,
    workingDirectory: baseDir.path,
    arguments: args,
  );
  await pm.start();

  final rpc = Aria2RpcClient(secret: secret);
  await rpc.connect('ws://127.0.0.1:$port/jsonrpc');
  stderr.writeln('engine ready: ${(await rpc.getVersion()).version}');

  final gid = await rpc.addUri([url], options: {'dir': categoryDir.path});
  stderr.writeln('added gid=$gid → $categoryDir');

  final sw = Stopwatch()..start();
  while (sw.elapsed < const Duration(seconds: 30)) {
    final s = await rpc.tellStatus(gid);
    final status = s['status']?.toString();
    final completed = int.tryParse(s['completedLength']?.toString() ?? '0') ?? 0;
    final total = int.tryParse(s['totalLength']?.toString() ?? '0') ?? 0;
    stderr.writeln('  [$status] $completed / $total bytes');
    if (status == 'complete') break;
    if (status == 'error') {
      stderr.writeln('FAIL: $s');
      exit(1);
    }
    await Future.delayed(const Duration(milliseconds: 300));
  }

  final baseFiles = baseDir
      .listSync()
      .whereType<File>()
      .where((f) => !f.path.endsWith('aria2.log'))
      .toList();
  final categoryFiles = categoryDir.listSync().whereType<File>().toList();

  stderr.writeln('\n=== verification ===');
  stderr.writeln('baseDir (should be empty):');
  for (final f in baseFiles) {
    stderr.writeln('  ${f.path} (${f.lengthSync()} bytes)');
  }
  stderr.writeln('categoryDir (should contain the file):');
  for (final f in categoryFiles) {
    stderr.writeln('  ${f.path} (${f.lengthSync()} bytes)');
  }

  final pass = categoryFiles.length == 1 && categoryFiles.first.lengthSync() > 0;
  stdout.writeln(jsonEncode({
    'category_routing': pass ? 'OK' : 'FAIL',
    'category': categoryName,
    'count': categoryFiles.length,
    'bytes': categoryFiles.isNotEmpty ? categoryFiles.first.lengthSync() : 0,
  }));

  await rpc.shutdown();
  await pm.stop();
  exit(pass ? 0 : 1);
}
