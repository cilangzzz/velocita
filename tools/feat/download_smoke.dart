// M2 download smoke: spawn aria2, addUri(http), poll until complete.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:velocita_kernel/velocita_kernel.dart';

Future<void> main(List<String> cliArgs) async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((rec) {
    stderr.writeln('[${rec.level.name}] ${rec.loggerName}: ${rec.message}');
  });

  final url = cliArgs.isNotEmpty
      ? cliArgs.first
      : 'https://speed.cloudflare.com/__down?bytes=1048576'; // 1 MiB
  final binaryPath = Platform.script
      .resolve('../../bin/aria2c.exe')
      .toFilePath(windows: Platform.isWindows);

  final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = probe.port;
  await probe.close();

  final workDir = await Directory.systemTemp.createTemp('velocita_dl_');
  stderr.writeln('workDir: ${workDir.path}');
  stderr.writeln('url: $url');

  final secret = 'velocita-smoke';
  final args = <String>[
    '--enable-rpc=true',
    '--rpc-listen-port=$port',
    '--rpc-listen-all=false',
    '--rpc-secret=$secret',
    '--dir=${workDir.path}',
    '--log=${workDir.path}/aria2.log',
    '--log-level=warn',
    '--no-conf=true',
    '--split=4',
    '--max-connection-per-server=4',
  ];

  final pm = Aria2ProcessManager(
    binaryPath: binaryPath,
    workingDirectory: workDir.path,
    arguments: args,
  );
  await pm.start();

  final rpc = Aria2RpcClient(secret: secret);
  await rpc.connect('ws://127.0.0.1:$port/jsonrpc');
  final info = await rpc.getVersion();
  stderr.writeln('engine ready: ${info.version}');

  // Add the download.
  final gid = await rpc.addUri([url]);
  stderr.writeln('added gid=$gid');

  // Poll for completion (max 30s).
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < const Duration(seconds: 30)) {
    final s = await rpc.tellStatus(gid);
    final status = s['status']?.toString() ?? '';
    final completed = int.tryParse(s['completedLength']?.toString() ?? '0') ?? 0;
    final total = int.tryParse(s['totalLength']?.toString() ?? '0') ?? 0;
    final speed = int.tryParse(s['downloadSpeed']?.toString() ?? '0') ?? 0;
    stderr.writeln(
        '  [$status] $completed / $total bytes  speed=${speed ~/ 1024} KB/s  elapsed=${stopwatch.elapsed.inSeconds}s');
    if (status == 'complete') break;
    if (status == 'error' || status == 'removed') {
      stderr.writeln('FAILED: $s');
      exit(1);
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  final finalStatus = (await rpc.tellStatus(gid))['status']?.toString();
  stderr.writeln('final: $finalStatus');

  // List downloaded file.
  final dir = Directory(workDir.path);
  final files = await dir
      .list()
      .where((e) => e is File && e.statSync().size > 0)
      .toList();
  for (final f in files) {
    final s = f.statSync();
    stderr.writeln('  file: ${f.uri.pathSegments.last}  size=${s.size}B');
  }

  stdout.writeln(jsonEncode({
    'status': finalStatus,
    'gid': gid,
    'file_count': files.length,
  }));

  await rpc.shutdown();
  await pm.stop();
  await workDir.delete(recursive: true);
}
