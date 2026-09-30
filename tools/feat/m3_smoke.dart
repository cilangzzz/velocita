// M3 smoke: add URL + magnet via the same kernel layer that the app uses.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:velocita_kernel/velocita_kernel.dart';

Future<void> main(List<String> cliArgs) async {
  Logger.root.level = Level.WARNING;
  Logger.root.onRecord.listen((rec) {
    stderr.writeln('[${rec.level.name}] ${rec.loggerName}: ${rec.message}');
  });

  final binaryPath = Platform.script
      .resolve('../../bin/aria2c.exe')
      .toFilePath(windows: Platform.isWindows);

  final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = probe.port;
  await probe.close();

  final workDir = await Directory.systemTemp.createTemp('velocita_m3_');
  final secret = 'velocita-m3';
  final args = <String>[
    '--enable-rpc=true',
    '--rpc-listen-port=$port',
    '--rpc-listen-all=false',
    '--rpc-secret=$secret',
    '--dir=${workDir.path}',
    '--log=${workDir.path}/aria2.log',
    '--log-level=warn',
    '--no-conf=true',
    // BT required for magnet/torrent (DHT/PEX need a real network to fetch
    // metadata; here we only verify the call shape is accepted).
    '--enable-dht=false',
    '--enable-peer-exchange=false',
    '--bt-enable-lpd=false',
  ];

  final pm = Aria2ProcessManager(
    binaryPath: binaryPath,
    workingDirectory: workDir.path,
    arguments: args,
  );
  await pm.start();

  final rpc = Aria2RpcClient(secret: secret);
  await rpc.connect('ws://127.0.0.1:$port/jsonrpc');
  await rpc.getVersion();

  // (1) URL — already covered by download_smoke; we just verify call shape.
  final urlGid = await rpc.addUri([
    'https://speed.cloudflare.com/__down?bytes=524288'
  ]);
  stderr.writeln('addUri gid=$urlGid');

  // (2) Magnet — call shape only (no actual peer network here).
  final magnetGid = await rpc.addMagnet(
    'magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c&dn=Big+Buck+Bunny&tr=udp%3A%2F%2Ftracker.example.com%3A6969',
  );
  stderr.writeln('addMagnet gid=$magnetGid');

  // (3) Torrent — call shape (file may not exist; we just emit an empty
  // base64 to test the JSON encoding works).
  final dummyTorrent = base64Encode(List<int>.filled(64, 0));
  // The dummy base64 will fail to decode as a torrent, but the call should
  // succeed at the protocol layer.
  final torrentGid = await rpc.addTorrent(
    List<int>.from(base64Decode(dummyTorrent)),
  );
  stderr.writeln('addTorrent gid=$torrentGid');

  // (4) Verify magnet parser round-trip.
  final parsed = parseMagnet(
    'magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c&dn=Big+Buck+Bunny&tr=udp%3A%2F%2Ftracker.example.com%3A6969',
  );
  stderr.writeln('parsed dn=${parsed.displayName} hash=${parsed.btihHash}');

  stdout.writeln(jsonEncode({
    'status': 'ok',
    'url_gid': urlGid,
    'magnet_gid': magnetGid,
    'torrent_gid': torrentGid,
    'magnet_dn': parsed.displayName,
    'magnet_hash': parsed.btihHash,
  }));

  await rpc.shutdown();
  await pm.stop();
  await workDir.delete(recursive: true);
}
