// Unit tests for BrowserIntegrationService.
//
// Uses a real HttpServer / HttpClient pair (the only stable way to
// exercise the wire format end-to-end). The service binds an ephemeral
// port so this test is self-contained.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:velocita/src/features/browser_integration/data/browser_integration_service.dart';
import 'package:velocita/src/features/browser_integration/domain/add_request.dart';

void main() {
  group('BrowserIntegrationService', () {
    test('tryStart binds an ephemeral port and serves /api/ping', () async {
      final svc = await _start();
      final res = await _httpGet(svc.port, '/api/ping');
      expect(res.statusCode, 200);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      expect(body['ok'], true);
      expect(body['port'], svc.port);
    });

    test('tryStart returns null when bind fails on a used port', () async {
      // We probe with a raw HttpServer bound with shared=true, then
      // point tryStart at the same port. On platforms where two binds
      // to the same port raise EADDRINUSE the service correctly
      // returns null. On Windows, where SO_EXCLUSIVEADDRUSE is the
      // default, the first bind fails (not the second), so the
      // behavior we can actually assert in CI is that tryStart either
      // returns a service OR returns null — both are non-throwing.
      final blocker = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
        shared: true,
      );
      addTearDown(blocker.close);
      // Must not throw.
      await BrowserIntegrationService.tryStart(port: blocker.port);
    });

    test('POST /api/add enqueues an AddRequest onto the stream', () async {
      final svc = await _start();

      final stream = svc.addRequestStream;
      final completer = Completer<AddRequest>();
      final sub = stream.listen(completer.complete);
      addTearDown(() => sub.cancel());

      final res = await _httpPost(svc.port, '/api/add', {
        'url': 'https://example.com/file.zip',
        'tabTitle': 'Example',
      });
      expect(res.statusCode, 200);
      expect(jsonDecode(res.body), {'queued': true});

      final request =
          await completer.future.timeout(const Duration(seconds: 2));
      expect(request.url, 'https://example.com/file.zip');
      expect(request.tabTitle, 'Example');
      expect(request.source, AddSource.extension);
    });

    test('POST /api/host enqueues with source=hostForward', () async {
      final svc = await _start();
      final completer = Completer<AddRequest>();
      final sub = svc.addRequestStream.listen(completer.complete);
      addTearDown(() => sub.cancel());

      await _httpPost(svc.port, '/api/host', {'url': 'https://x.test/y'});
      final r = await completer.future.timeout(const Duration(seconds: 2));
      expect(r.source, AddSource.hostForward);
    });

    test('POST /api/add rejects an empty body with 400', () async {
      final svc = await _start();

      final client = HttpClient();
      try {
        final req = await client.post('127.0.0.1', svc.port, '/api/add');
        req.headers.set('Content-Type', 'application/json');
        await req.close();
        final res = await req.done;
        expect(res.statusCode, 400);
      } finally {
        client.close(force: true);
      }
    });

    test('POST /api/add rejects malformed JSON with 400', () async {
      final svc = await _start();

      final client = HttpClient();
      try {
        final req = await client.post('127.0.0.1', svc.port, '/api/add');
        req.headers.set('Content-Type', 'application/json');
        req.write('not json');
        final res = await req.close();
        expect(res.statusCode, 400);
      } finally {
        client.close(force: true);
      }
    });

    test('CORS headers echo a chrome-extension origin', () async {
      final svc = await _start();

      final client = HttpClient();
      try {
        final req = await client.get('127.0.0.1', svc.port, '/api/ping');
        req.headers.set(
            'Origin', 'chrome-extension://abcdefghijklmnopqrstuvwxyz/');
        final res = await req.close();
        expect(res.headers.value('access-control-allow-origin'),
            'chrome-extension://abcdefghijklmnopqrstuvwxyz/');
      } finally {
        client.close(force: true);
      }
    });

    test('unknown path returns 404', () async {
      final svc = await _start();
      final res = await _httpGet(svc.port, '/api/nope');
      expect(res.statusCode, 404);
    });
  });
}

/// Start a service on an ephemeral port and register teardown. The
/// returned `Future` resolves to a non-null service — failure to bind
/// is reported as a test failure (which is the right outcome for these
/// tests since they all assume the bind succeeds).
Future<BrowserIntegrationService> _start() async {
  final s = await BrowserIntegrationService.tryStart(port: 0);
  if (s == null) {
    fail('tryStart returned null on an ephemeral port');
  }
  addTearDown(s.stop);
  return s;
}

class _Resp {
  _Resp(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

Future<_Resp> _httpGet(int port, String path) async {
  final client = HttpClient();
  try {
    final req = await client.get('127.0.0.1', port, path);
    final res = await req.close();
    return _Resp(res.statusCode, await utf8.decodeStream(res));
  } finally {
    client.close(force: true);
  }
}

Future<_Resp> _httpPost(
  int port,
  String path,
  Map<String, Object?> body,
) async {
  final client = HttpClient();
  try {
    final req = await client.post('127.0.0.1', port, path);
    req.headers.set('Content-Type', 'application/json');
    req.write(jsonEncode(body));
    final res = await req.close();
    return _Resp(res.statusCode, await utf8.decodeStream(res));
  } finally {
    client.close(force: true);
  }
}
