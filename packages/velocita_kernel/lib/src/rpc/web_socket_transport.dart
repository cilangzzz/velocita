import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../errors.dart';

/// WebSocket transport for the JSON-RPC client.
///
/// The transport is intentionally tiny: it owns the WebSocketChannel and
/// pumps text frames into a single sink. The protocol layer handles
/// framing/parsing.
class WebSocketTransport {
  WebSocketChannel? _channel;
  final StreamController<String> _messages = StreamController<String>.broadcast();
  final StreamController<TransportError> _errors =
      StreamController<TransportError>.broadcast();
  String? _url;
  bool _connected = false;

  Stream<String> get messages => _messages.stream;
  Stream<TransportError> get errors => _errors.stream;
  bool get isConnected => _connected;

  Future<void> connect(String url) async {
    if (_connected) {
      throw TransportError('already connected', context: {'url': _url});
    }
    _url = url;
    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      // Drain readiness so the caller can rely on a stable "connected" state.
      await channel.ready.timeout(const Duration(seconds: 5));
      _channel = channel;
      _connected = true;
      channel.stream.listen(
        (data) {
          if (data is String) {
            _messages.add(data);
          }
        },
        onError: (Object e, StackTrace _) {
          _errors.add(TransportError(e.toString()));
        },
        onDone: () {
          _connected = false;
        },
        cancelOnError: true,
      );
    } catch (e) {
      _connected = false;
      throw TransportError('connect failed', cause: e, context: {'url': url});
    }
  }

  void send(String data) {
    final channel = _channel;
    if (channel == null || !_connected) {
      throw TransportError('not connected', context: {'url': _url});
    }
    channel.sink.add(data);
  }

  Future<void> disconnect() async {
    _connected = false;
    await _channel?.sink.close(ws_status.normalClosure);
    _channel = null;
  }
}
