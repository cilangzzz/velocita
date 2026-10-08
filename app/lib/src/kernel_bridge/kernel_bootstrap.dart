import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';
import 'package:velocita_kernel/velocita_kernel.dart';

import '../features/downloads/data/downloads_repository.dart';

/// Bootstrap the kernel singleton.
///
/// Steps (M1 surface only):
///   1. Resolve data + downloads dirs (path_provider)
///   2. Bind a free port
///   3. Spawn aria2c with `--rpc-listen-port=<port>`, `--rpc-secret=<random>`
///   4. Open the RPC client
///   5. Return a small `Kernel` facade exposing the supervisor + rpc client
///
/// M2 will replace the inline wiring with the full `Kernel.initialize(...)`
/// from `kernel.dart` (drift schema + plugins + bridge).
final _bootstrapLock = Lock();

Future<KernelFacade> bootstrapKernel() async {
  return _bootstrapLock.synchronized(() async {
    // Idempotent: if we already bootstrapped, return the cached instance.
    if (_instance != null) return _instance!;

    final appSupport = await getApplicationSupportDirectory();
    final downloads = await getDownloadsDirectory();
    final dataDir = Directory('${appSupport.path}/velocita')
      ..createSync(recursive: true);
    final downloadDir = downloads ?? Directory('${dataDir.path}/downloads')
      ..createSync(recursive: true);

    // Bind a free port then close (we just need the number).
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();

    final secret = _randomSecret();
    final aria2cPath = _resolveAria2cPath();

    Logger('Velocita.Bootstrap').info(
      'spawning aria2c binary=$aria2cPath port=$port dir=${dataDir.path}',
    );

    final args = <String>[
      '--enable-rpc=true',
      '--rpc-listen-port=$port',
      '--rpc-listen-all=false',
      '--rpc-secret=$secret',
      '--dir=${downloadDir.path}',
      '--log=${dataDir.path}/aria2.log',
      '--log-level=warn',
      '--no-conf=true',
    ];

    final pm = Aria2ProcessManager(
      binaryPath: aria2cPath,
      workingDirectory: dataDir.path,
      arguments: args,
    );
    await pm.start();

    final rpc = Aria2RpcClient(secret: secret);
    await rpc.connect('ws://127.0.0.1:$port/jsonrpc');

    final info = await rpc.getVersion();
    Logger('Velocita.Bootstrap').info(
      'engine ready: ${info.version}',
    );

    final facade = KernelFacade(
      processManager: pm,
      rpcClient: rpc,
      engineInfo: info,
      dataDir: dataDir.path,
      downloadDir: downloadDir.path,
      downloadsRepository: DownloadsRepository(
        rpc,
        defaultSaveDir: downloadDir.path,
      ),
    );
    _instance = facade;
    return facade;
  });
}

KernelFacade? _instance;

String _resolveAria2cPath() {
  // Look for the binary next to the executable (production layout) or in
  // `velocita/bin/` (development layout).
  final exe = Platform.resolvedExecutable;
  final nextToExe = File('${File(exe).parent.path}/aria2c.exe');
  if (nextToExe.existsSync()) return nextToExe.path;

  // dev: assume cwd is velocita/ (flutter run cwd is app/, so walk up).
  for (final candidate in ['../../bin/aria2c.exe', '../bin/aria2c.exe', 'bin/aria2c.exe']) {
    final f = File(Platform.script.resolve(candidate).toFilePath(windows: Platform.isWindows));
    if (f.existsSync()) return f.path;
  }
  throw const KernelFacadeException(
    'aria2c binary not found next to executable or in velocita/bin/',
  );
}

String _randomSecret() {
  final r = (DateTime.now().microsecondsSinceEpoch ^ 0xA5A5A5A5).toRadixString(16);
  return 'velocita-$r';
}

/// Thin facade over the kernel objects the UI actually consumes in M2.
///
/// M2 also exposes a pre-built `DownloadsRepository` so the UI never
/// touches the raw RPC client (per the layer rule in
/// `docs/rule/flutter_rule/01-architecture.md`).
class KernelFacade {
  KernelFacade({
    required this.processManager,
    required this.rpcClient,
    required this.engineInfo,
    required this.dataDir,
    required this.downloadDir,
    required this.downloadsRepository,
  });

  final Aria2ProcessManager processManager;
  final Aria2RpcClient rpcClient;
  final EngineVersionInfo engineInfo;
  final String dataDir;
  final String downloadDir;
  final DownloadsRepository downloadsRepository;
}

class KernelFacadeException implements Exception {
  const KernelFacadeException(this.message);
  final String message;
  @override
  String toString() => 'KernelFacadeException: $message';
}
