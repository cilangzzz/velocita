import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

import '../domain/engine_adapter.dart';
import '../errors.dart';
import '../rpc/json_rpc_protocol.dart';
import '../rpc/web_socket_transport.dart';

/// Aria2 RPC client.
///
/// Wraps the JSON-RPC protocol with aria2-specific concerns:
/// - secret injection on every method except `system.*`
/// - notification subscription (`aria2.onDownloadStart`, etc.)
class Aria2RpcClient implements EngineAdapter {
  Aria2RpcClient({required this.secret});

  final String secret;
  final Logger _log = Logger('Aria2RpcClient');

  WebSocketTransport? _transport;
  JsonRpcProtocol? _protocol;
  StreamSubscription<String>? _msgSub;
  StreamSubscription<TransportError>? _errSub;
  final StreamController<Map<String, Object?>> _notifications =
      StreamController<Map<String, Object?>>.broadcast();

  Stream<Map<String, Object?>> get notifications => _notifications.stream;
  bool get isConnected => _transport?.isConnected ?? false;

  Future<void> connect(String url, {Duration timeout = const Duration(seconds: 5)}) async {
    final transport = WebSocketTransport();
    await transport.connect(url).timeout(timeout);

    final protocol = JsonRpcProtocol(
      send: transport.send,
      timeout: const Duration(seconds: 30),
    );

    _msgSub = transport.messages.listen(protocol.handleMessage);
    _errSub = transport.errors.listen((e) => _log.warning('transport error: $e'));

    _transport = transport;
    _protocol = protocol;
  }

  @override
  Future<EngineVersionInfo> getVersion() async {
    final proto = _requireProtocol();
    final params = <Object?>[];
    _withSecretInPlace(params);
    final result = await proto.call('aria2.getVersion', params);
    final map = (result as Map).cast<String, Object?>();
    final version = map['version']?.toString() ?? 'unknown';
    final features = (map['enabledFeatures'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    return EngineVersionInfo(version: version, enabledFeatures: features);
  }

  @override
  Future<String> addUri(List<String> uris, {Map<String, Object?>? options}) async {
    final proto = _requireProtocol();
    // aria2.addUri signature: [secret, uris, options?, position?]
    final params = <Object?>[uris];
    _withSecretInPlace(params);
    if (options != null) params.add(options);
    _log.info('addUri params=$params');
    final gid = await proto.call('aria2.addUri', params);
    return gid as String;
  }

  /// Add a magnet URI. aria2 fetches the metadata and starts the download.
  Future<String> addMagnet(String magnet, {Map<String, Object?>? options}) async {
    final proto = _requireProtocol();
    // aria2.addUri treats `magnet:?` URIs as a metadata-fetch + download.
    // We can use the same channel as addUri.
    final params = <Object?>[[magnet]];
    _withSecretInPlace(params);
    if (options != null) params.add(options);
    _log.info('addMagnet params=$params');
    final gid = await proto.call('aria2.addUri', params);
    return gid as String;
  }

  /// Add a torrent file (already read into bytes). aria2 decodes the
  /// bencode and starts the download.
  Future<String> addTorrent(List<int> bytes, {Map<String, Object?>? options}) async {
    final proto = _requireProtocol();
    // aria2.addTorrent signature: [secret, torrentBase64, uris?, options?]
    final b64 = base64Encode(bytes);
    final params = <Object?>[b64];
    _withSecretInPlace(params);
    if (options != null) params.add(options);
    _log.info('addTorrent params len=${params.length}');
    final gid = await proto.call('aria2.addTorrent', params);
    return gid as String;
  }

  @override
  Future<void> pause(String gid) async {
    final proto = _requireProtocol();
    final params = <Object?>[gid];
    _withSecretInPlace(params);
    await proto.call('aria2.pause', params);
  }

  @override
  Future<void> unpause(String gid) async {
    final proto = _requireProtocol();
    final params = <Object?>[gid];
    _withSecretInPlace(params);
    await proto.call('aria2.unpause', params);
  }

  @override
  Future<void> remove(String gid, {bool force = false}) async {
    final proto = _requireProtocol();
    final method = force ? 'aria2.forceRemove' : 'aria2.remove';
    final params = <Object?>[gid];
    _withSecretInPlace(params);
    await proto.call(method, params);
  }

  @override
  Future<Map<String, Object?>> tellStatus(String gid) async {
    final proto = _requireProtocol();
    final params = <Object?>[gid];
    _withSecretInPlace(params);
    final result = await proto.call('aria2.tellStatus', params);
    return (result as Map).cast<String, Object?>();
  }

  @override
  Future<List<Map<String, Object?>>> tellActive() async {
    final proto = _requireProtocol();
    final params = <Object?>[];
    _withSecretInPlace(params);
    final result = await proto.call('aria2.tellActive', params);
    return (result as List)
        .map((e) => (e as Map).cast<String, Object?>())
        .toList(growable: false);
  }

  /// Prepends the secret at index 0 in-place so aria2 sees `token:<secret>`
  /// as the first positional argument of every call.
  void _withSecretInPlace(List<Object?> params) {
    if (secret.isEmpty) return;
    params.insert(0, 'token:$secret');
  }

  List<Object?> _withSecret(List<Object?> params) =>
      secret.isEmpty ? params : <Object?>['token:$secret', ...params];

  JsonRpcProtocol _requireProtocol() {
    final p = _protocol;
    if (p == null || !(_transport?.isConnected ?? false)) {
      throw const EngineFailure('not connected');
    }
    return p;
  }

  @override
  Future<void> shutdown() async {
    _protocol?.close();
    await _msgSub?.cancel();
    await _errSub?.cancel();
    await _transport?.disconnect();
    await _notifications.close();
    _protocol = null;
    _transport = null;
  }
}
