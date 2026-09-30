import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

import '../errors.dart';

/// JSON-RPC 2.0 protocol (aria2 wire format).
///
/// aria2 uses a JSON-RPC 2.0 dialect over WebSocket. The protocol layer is
/// decoupled from the transport so it can be unit-tested with a fake
/// transport.
class JsonRpcProtocol {
  JsonRpcProtocol({
    required this.send,
    Duration timeout = const Duration(seconds: 30),
  }) : _timeout = timeout;

  final void Function(String) send;
  final Duration _timeout;

  final Map<String, _Pending> _pending = {};
  int _id = 0;
  final Logger _log = Logger('JsonRpcProtocol');

  Future<Object?> call(
    String method,
    List<Object?> params,
  ) async {
    final id = '${++_id}';
    final completer = Completer<Object?>();
    final timer = Timer(_timeout, () {
      _pending.remove(id);
      if (!completer.isCompleted) {
        completer.completeError(
          RpcProtocolError('JSON-RPC timeout after ${_timeout.inSeconds}s',
              context: {'method': method, 'id': id}),
        );
      }
    });

    _pending[id] = _Pending(completer, timer, method);

    final envelope = <String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    };
    send(jsonEncode(envelope));
    _log.fine('→ ${jsonEncode(envelope)}');
    return completer.future;
  }

  /// Called by the transport for every received text frame.
  void handleMessage(String data) {
    _log.fine('← $data');
    Object? decoded;
    try {
      decoded = jsonDecode(data);
    } catch (e) {
      _log.warning('Non-JSON message: ${data.substring(0, data.length.clamp(0, 200))}');
      return;
    }
    if (decoded is! Map) return;
    final map = decoded.cast<String, Object?>();
    if (map.containsKey('method')) {
      // Notification. Fan-out is the responsibility of Aria2RpcClient,
      // which subscribes to the transport's message stream directly.
      return;
    }
    final id = map['id']?.toString();
    final pending = id != null ? _pending.remove(id) : null;
    if (pending == null) return;
    pending.timer.cancel();
    if (map.containsKey('error')) {
      final err = map['error'];
      final msg = err is Map ? err['message']?.toString() ?? 'unknown' : 'unknown';
      pending.completer.completeError(RpcProtocolError(msg));
    } else {
      pending.completer.complete(map['result']);
    }
  }

  void close() {
    for (final p in _pending.values) {
      p.timer.cancel();
      if (!p.completer.isCompleted) {
        p.completer.completeError(
          RpcProtocolError('protocol closed'),
        );
      }
    }
    _pending.clear();
  }
}

class _Pending {
  _Pending(this.completer, this.timer, this.method);
  final Completer<Object?> completer;
  final Timer timer;
  final String method;
}
