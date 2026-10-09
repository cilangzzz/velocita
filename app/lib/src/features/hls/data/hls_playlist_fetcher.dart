/// Fetches an HLS playlist body using `dart:io HttpClient` so the
/// request can carry the same `Referer` / `Cookie` / `User-Agent`
/// headers that the original URL was downloaded with, and (when
/// configured) honour the Velocita-level HTTP proxy.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/hls_models.dart';

class HlsPlaylistFetcher {
  HlsPlaylistFetcher({String? proxyUrl}) : _proxyUrl = proxyUrl;

  final String? _proxyUrl;

  /// GET [uri] and return the body + final URL (after redirects).
  /// [headerLines] are the aria2-form `["Name: value", ...]` strings
  /// already built by the browser extension wire. [referer] is
  /// applied as the `Referer` header.
  Future<({String body, Uri finalUri})> fetch(
    Uri uri, {
    required List<String> headerLines,
    String? referer,
  }) async {
    final client = HttpClient();
    try {
      if (_proxyUrl != null && _proxyUrl.isNotEmpty) {
        client.findProxy = (Uri _) => 'PROXY $_proxyUrl';
      }
      client.idleTimeout = const Duration(seconds: 30);
      client.connectionTimeout = const Duration(seconds: 30);

      final req = await client.getUrl(uri);
      for (final h in headerLines) {
        final colon = h.indexOf(':');
        if (colon <= 0) continue;
        final name = h.substring(0, colon).trim();
        final value = h.substring(colon + 1).trim();
        if (name.isEmpty || value.isEmpty) continue;
        try {
          req.headers.set(name, value);
        } catch (_) {
          // Some header names are restricted; skip them silently
          // (e.g. `Host` cannot be set manually).
        }
      }
      if (referer != null && referer.isNotEmpty) {
        try {
          req.headers.set(HttpHeaders.refererHeader, referer);
        } catch (_) {}
      }

      final resp = await req.close();
      if (resp.statusCode >= 400) {
        // The response stream is single-subscription; we never listen
        // on the error path. Closing the client (outer finally, force)
        // detaches the socket.
        throw HlsFetchException(resp.statusCode);
      }
      // join() fully consumes the response stream — do NOT drain it
      // afterwards (a second listen throws "Stream has already been
      // listened to").
      final body = await resp.transform(utf8.decoder).join();
      // Follow the redirect chain to the final URL so relative
      // segment URIs resolve against the right base.
      final finalUri = resp.redirects.isEmpty ? uri : resp.redirects.last.location;
      return (body: body, finalUri: finalUri);
    } finally {
      client.close(force: true);
    }
  }
}
