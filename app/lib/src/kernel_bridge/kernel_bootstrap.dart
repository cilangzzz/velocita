import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';
import 'package:velocita_kernel/velocita_kernel.dart';

import '../features/downloads/data/downloads_repository.dart';
import '../features/categories/data/category_icon_store.dart';
import '../persistence/database.dart';
import '../persistence/json_migration.dart';

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

    // Open the single SQLite store + run the one-time JSON → DB
    // migration. Done before aria2 spawns so the proxy / no-proxy
    // values are available on the command line, and before any
    // provider's `build()` so no race reads an empty DB.
    final db = await AppDatabase.openAtDefaultPath();
    await migrateJsonToDb(db, dataDir);
    // Custom-icon directory lives next to the DB; pre-warm the
    // cached path so the icon picker can scan it synchronously.
    await CategoryIconStore.ensureReady();
    final proxy = await _readProxyFromDb(db);
    final noProxy = await _readNoProxyFromDb(db);

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
      // Split each file into 5 ranges AND let up to 5 connections hit
      // the same server. aria2's effective per-task connection count is
      // `min(split, max-connection-per-server)`, so both must be raised
      // together or aria2 silently caps at the smaller value (default
      // `max-connection-per-server=1` would make `split=5` a no-op).
      // Also lower `min-split-size` from its 20 MiB default: aria2
      // refuses to create a range smaller than 2*min-split-size, so
      // without this 5-way splitting is silently a no-op on any file
      // smaller than ~100 MiB.
      '--split=5',
      '--max-connection-per-server=5',
      '--min-split-size=1M',
    ];

    // If the user persisted a proxy last session, inject it on the
    // command line. We support both HTTP (also pushable via RPC) and
    // SOCKS5 (which aria2 only accepts at process start).
    if (proxy != null && proxy.isNotEmpty) {
      args.add('--all-proxy=$proxy');
    }
    if (noProxy != null && noProxy.isNotEmpty) {
      args.add('--no-proxy=$noProxy');
    }

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
      proxyUrl: proxy,
      appDatabase: db,
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

/// Read the persisted proxy URL from the SQLite settings table so
/// aria2c can be started with the correct `--all-proxy` flag.
/// Returns `null` when the proxy is `off`, the host/port are
/// missing, or the row is corrupt.
///
/// aria2c only supports HTTP proxies through `--all-proxy`; any
/// persisted SOCKS5 config is silently ignored (the UI prevents
/// selecting it in the first place).
Future<String?> _readProxyFromDb(AppDatabase db) async {
  final kv = await db.downloadSettingsDao.all();
  final kind = kv['proxyKind'] ?? 'off';
  if (kind != 'http') return null;
  final host = (kv['proxyHost'] ?? '').trim();
  final port = int.tryParse(kv['proxyPort'] ?? '') ?? 0;
  if (host.isEmpty || port <= 0) return null;
  final user = (kv['proxyUsername'] ?? '').trim();
  final pass = kv['proxyPassword'] ?? '';
  final userInfo = user.isEmpty
      ? ''
      : (pass.isEmpty ? '$user@' : '$user:$pass@');
  return 'http://$userInfo$host:$port';
}

Future<String?> _readNoProxyFromDb(AppDatabase db) async {
  final kv = await db.downloadSettingsDao.all();
  final bypass = (kv['proxyBypass'] ?? '').trim();
  return bypass.isEmpty ? null : bypass;
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
    this.proxyUrl,
    required this.appDatabase,
  });

  final Aria2ProcessManager processManager;
  final Aria2RpcClient rpcClient;
  final EngineVersionInfo engineInfo;
  final String dataDir;
  final String downloadDir;
  final DownloadsRepository downloadsRepository;

  /// Persisted HTTP proxy URL (e.g. `http://user:pass@host:port`) read
  /// from the SQLite settings table at kernel bootstrap. Used by the
  /// HLS playlist fetcher so the playlist fetch honours the same
  /// proxy that aria2c was started with via `--all-proxy`. `null`
  /// when no proxy is configured.
  final String? proxyUrl;

  /// The single SQLite store. Already opened + migrated before
  /// bootstrap returned. Wired into Riverpod via
  /// [appDatabaseProvider].
  final AppDatabase appDatabase;
}

class KernelFacadeException implements Exception {
  const KernelFacadeException(this.message);
  final String message;
  @override
  String toString() => 'KernelFacadeException: $message';
}
