// ignore_for_file: avoid_relative_lib_imports
// Browser-integration IPC service.
//
// Owns:
//   * the local HTTP server on 127.0.0.1:<port> (default 16800) that the
//     browser extension / popup / fallback path talks to,
//   * the AddRequest stream that the UI listener subscribes to,
//   * a single instance check used by `main.dart` to decide between
//     "become the primary" and "forward to the primary and exit".
//
// The service does NOT touch the Native Messaging host directly. NM
// handling is layered on top — when Chrome spawns `velocita.exe` as a
// host, `main.dart` detects the second-instance case and POSTs the NM
// payload into this service's `/api/host` endpoint, then exits.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import '../domain/add_request.dart';
import 'host_installer.dart' as host_installer;

final _log = Logger('Velocita.BrowserIntegration');

class BrowserIntegrationException implements Exception {
  const BrowserIntegrationException(this.message);
  final String message;
  @override
  String toString() => 'BrowserIntegrationException: $message';
}

/// The browser-integration HTTP service.
///
/// Public surface:
///   * [tryStart] — bind the port, begin serving; returns `null` if the
///     port is already taken (caller is the "second instance")
///   * [addRequestStream] — broadcast stream of incoming requests
///   * [port] — the port actually bound
///   * [enqueue] — push a request from non-HTTP sources (Native
///     Messaging, deep link) into the same stream
///   * [stop] — close the server and the controller
///
/// Wire format (JSON over HTTP on loopback only):
///   GET  /api/ping   -> 200 {"ok":true,"version":"…"}
///   POST /api/add    -> 200 {"queued":true}, body is an AddRequest payload
///   POST /api/host   -> 200 {"forwarded":true}, identical body, used by
///                        a second-instance host process to push a NM
///                        payload into the running primary
///   POST /api/deeplink -> 200 {"queued":true}, used by the
///                        `velocita://add?url=…` deep-link wake-up path
class BrowserIntegrationService {
  BrowserIntegrationService._({
    required this.port,
    required HttpServer server,
    required StreamController<AddRequest> controller,
  })  : _server = server,
        _controller = controller;

  /// Tries to bind [port] on loopback. Returns `null` if the port is
  /// already in use (the caller is the "second instance" — the existing
  /// primary is serving on this port).
  static Future<BrowserIntegrationService?> tryStart({int port = 16800}) async {
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      final controller = StreamController<AddRequest>.broadcast();
      final svc = BrowserIntegrationService._(
        port: server.port,
        server: server,
        controller: controller,
      );
      svc._serve();
      _log.info('browser integration listening on 127.0.0.1:${svc.port}');
      return svc;
    } on SocketException {
      // Any bind failure on the loopback port is treated as "the
      // primary is already running" for our purposes. On Linux / macOS
      // this is EADDRINUSE (98 / 48); on Windows the underlying error
      // can surface as either WSAEADDRINUSE (10048) or as a Dart-level
      // "shared flag" error if the first bind did not enable
      // SO_REUSEADDR. We don't care which one — the recovery is the
      // same: the caller forwards its NM payload via `host_bridge`.
      _log.info('port $port unavailable; assuming primary is running');
      return null;
    }
  }

  final int port;
  final HttpServer _server;
  final StreamController<AddRequest> _controller;

  /// Public broadcast stream. Each subscriber gets every request.
  Stream<AddRequest> get addRequestStream => _controller.stream;

  /// Forwards an externally-sourced request (e.g. a Native Messaging
  /// payload delivered by stdin) into the same stream the HTTP endpoint
  /// feeds. Used by `main.dart` when this process is the host.
  void enqueue(AddRequest request) {
    if (!_controller.isClosed) _controller.add(request);
  }

  /// True while the HTTP server is still accepting connections.
  bool get isRunning => !_closed;
  bool _closed = false;

  Future<void> stop() async {
    _closed = true;
    await _server.close(force: true);
    await _controller.close();
  }

  // ── request loop ────────────────────────────────────────────

  Future<void> _serve() async {
    await for (final req in _server) {
      // Each request is handled independently; failures in one don't
      // affect others.
      unawaited(_handle(req));
    }
  }

  Future<void> _handle(HttpRequest req) async {
    final origin = req.headers.value('origin');
    try {
      if (req.method == 'OPTIONS') {
        _setCorsHeaders(req.response, origin);
        req.response.statusCode = 204;
        await req.response.close();
        return;
      }

      switch ((req.method, req.uri.path)) {
        case ('GET', '/api/ping'):
          _writeJson(req.response, 200, origin, {
            'ok': true,
            'version': '1.0',
            'port': port,
          });
        case ('POST', '/api/add'):
          await _handleAdd(req, AddSource.extension, origin);
        case ('POST', '/api/host'):
          await _handleAdd(req, AddSource.hostForward, origin);
        case ('POST', '/api/deeplink'):
          await _handleAdd(req, AddSource.deepLink, origin);
        case ('POST', '/api/register-extension'):
          await _handleRegisterExtension(req, origin);
        default:
          _writeJson(req.response, 404, origin, {'error': 'not found'});
      }
    } catch (e, st) {
      _log.warning('handler failed: $e\n$st');
      try {
        _writeJson(req.response, 500, origin, {'error': e.toString()});
      } catch (_) {
        // response already closed by the time we hit the catch
      }
    }
  }

  Future<void> _handleAdd(
    HttpRequest req,
    AddSource defaultSource,
    String? origin,
  ) async {
    final chunks = <int>[];
    await for (final c in req) {
      chunks.addAll(c);
    }
    if (chunks.isEmpty) {
      _writeJson(req.response, 400, origin, {'error': 'empty body'});
      return;
    }
    Object? parsed;
    try {
      parsed = jsonDecode(utf8.decode(chunks));
    } catch (e) {
      _writeJson(req.response, 400, origin, {'error': 'invalid json'});
      return;
    }
    if (parsed is! Map) {
      _writeJson(req.response, 400, origin, {'error': 'expected json object'});
      return;
    }
    final url = (parsed['url'] as String?)?.trim();
    if (url == null || url.isEmpty) {
      _writeJson(req.response, 400, origin, {'error': 'missing url'});
      return;
    }
    final sourceName = parsed['source'] as String?;
    final source = sourceName == null
        ? defaultSource
        : AddSource.values.firstWhere(
            (s) => s.name == sourceName,
            orElse: () => defaultSource,
          );
    final cookieHeader = (parsed['cookieHeader'] as String?)?.trim();
    final rawHeaders = parsed['headers'];
    final requestHeaders = rawHeaders is List
        ? rawHeaders.whereType<String>().toList(growable: false)
        : null;
    final request = AddRequest(
      url: url,
      source: source,
      receivedAt: DateTime.now(),
      referer: parsed['referer'] as String?,
      tabTitle: parsed['tabTitle'] as String?,
      cookieHeader:
          cookieHeader == null || cookieHeader.isEmpty ? null : cookieHeader,
      requestHeaders:
          requestHeaders == null || requestHeaders.isEmpty ? null : requestHeaders,
    );
    final dedupKey = (parsed['dedupKey'] as String?)?.trim();
    if (dedupKey != null && dedupKey.isNotEmpty) {
      request.dedupKey = dedupKey;
    }
    enqueue(request);
    _log.info('queued add from $source url-hash=${url.hashCode}');
    _writeJson(
      req.response,
      200,
      origin,
      source == AddSource.hostForward
          ? {'forwarded': true}
          : {'queued': true},
    );
  }

  // ── response helpers ────────────────────────────────────────

  /// Registers the calling browser extension's origin so the Native
  /// Messaging host JSON's `allowed_origins` lists it. The extension calls
  /// this with `{id: chrome.runtime.id}` before falling back to loopback
  /// HTTP, so the *next* `sendNativeMessage` succeeds (Chrome refuses NM
  /// delivery to an unlisted origin without spawning the host).
  ///
  /// Body: `{"id": "abc…"}` (the extension ID, with or without the
  /// `chrome-extension://…/` wrapper).
  Future<void> _handleRegisterExtension(HttpRequest req, String? origin) async {
    final chunks = <int>[];
    await for (final c in req) {
      chunks.addAll(c);
    }
    Object? parsed;
    try {
      parsed = jsonDecode(utf8.decode(chunks));
    } catch (e) {
      _writeJson(req.response, 400, origin, {'error': 'invalid json'});
      return;
    }
    final id = (parsed is Map) ? (parsed['id'] as String?)?.trim() : null;
    if (id == null || id.isEmpty) {
      _writeJson(req.response, 400, origin, {'error': 'missing id'});
      return;
    }
    try {
      await host_installer.registerExtensionId(id);
      _writeJson(req.response, 200, origin, {'ok': true});
    } catch (e) {
      _log.warning('register-extension failed: $e');
      _writeJson(req.response, 500, origin, {'error': e.toString()});
    }
  }

  static void _setCorsHeaders(HttpResponse res, String? origin) {
    // The server is bound to loopback only, so the only "attacker" is
    // another extension on the user's machine. Echo the origin if it
    // looks like a browser extension; otherwise, allow all (the
    // default for loopback).
    if (origin != null &&
        (origin.startsWith('chrome-extension://') ||
            origin.startsWith('moz-extension://') ||
            origin.startsWith('edge-extension://'))) {
      res.headers.set('Access-Control-Allow-Origin', origin);
    } else {
      res.headers.set('Access-Control-Allow-Origin', '*');
    }
    res.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.headers.set('Access-Control-Allow-Headers', 'Content-Type');
    res.headers.set('Access-Control-Max-Age', '600');
  }

  void _writeJson(
    HttpResponse res,
    int status,
    String? origin,
    Object body,
  ) {
    _setCorsHeaders(res, origin);
    res.statusCode = status;
    res.headers.set('Content-Type', 'application/json; charset=utf-8');
    res.write(jsonEncode(body));
    res.close();
  }
}
