// Unit tests for the JSON-RPC protocol layer.
import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:velocita_kernel/velocita_kernel.dart';

void main() {
  group('JsonRpcProtocol', () {
    test('serializes a call envelope with id', () async {
      final captured = <String>[];
      final protocol = JsonRpcProtocol(send: captured.add);
      final pending = protocol.call('system.listMethods', []);
      protocol.handleMessage(jsonEncode({
        'jsonrpc': '2.0',
        'id': '1',
        'result': ['foo', 'bar'],
      }));
      expect(await pending, ['foo', 'bar']);
      expect(captured, hasLength(1));
      final envelope = jsonDecode(captured.first) as Map;
      expect(envelope['method'], 'system.listMethods');
      expect(envelope['id'], '1');
    });

    test('timeout produces an error', () async {
      final protocol = JsonRpcProtocol(
        send: (_) {},
        timeout: const Duration(milliseconds: 10),
      );
      expect(
        () => protocol.call('aria2.getVersion', const []),
        throwsA(isA<RpcProtocolError>()),
      );
    });

    test('error response rejects with code+message', () async {
      final protocol = JsonRpcProtocol(send: (_) {});
      final pending = protocol.call('aria2.getVersion', const []);
      // Fake a server-side error.
      protocol.handleMessage(jsonEncode({
        'jsonrpc': '2.0',
        'id': '1',
        'error': {'code': 1, 'message': 'Unauthorized'},
      }));
      try {
        await pending;
        fail('should have thrown');
      } on RpcProtocolError catch (e) {
        expect(e.message, contains('Unauthorized'));
      }
    });
  });
}
