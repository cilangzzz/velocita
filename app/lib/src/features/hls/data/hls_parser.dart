/// Pure-Dart HLS playlist parser (no I/O).
///
/// Parses a media or master playlist body and returns the resulting
/// [HlsPlaylist]. Throws [HlsUnsupportedFeature] for features v1
/// does not support (AES-128 / SAMPLE-AES / fMP4 init segments /
/// live streams over the segment cap) and [HlsParseException] for
/// structural problems.
library;

import '../domain/hls_models.dart';

/// Parse a single playlist body. Pass the [baseUri] that the
/// playlist was fetched from so relative segment / variant URIs
/// can be resolved.
HlsPlaylist parseHlsPlaylist(String body, Uri baseUri) {
  if (body.isNotEmpty && body.codeUnitAt(0) == 0xFEFF) {
    body = body.substring(1);
  }
  final lines = body.split(RegExp(r'\r\n|\r|\n'));

  var isMaster = false;
  var isVod = false;
  final variants = <HlsVariant>[];
  final segments = <HlsSegment>[];
  Uri? mapUri;

  double? currentDuration;
  String? currentTitle;
  String? currentByterange;
  var pendingStreamInf = false;
  int? pendingBandwidth;
  String? pendingResolution;
  String? pendingCodecs;

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    if (line.startsWith('#EXTM3U')) continue;

    if (line.startsWith('#')) {
      // Comments + EXT tags.
      if (line.startsWith('#EXT-X-VERSION:')) continue;
      if (line.startsWith('#EXT-X-TARGETDURATION:')) continue;
      if (line.startsWith('#EXT-X-MEDIA-SEQUENCE:')) continue;
      if (line.startsWith('#EXT-X-ENDLIST')) {
        isVod = true;
        pendingStreamInf = false;
        continue;
      }
      if (line.startsWith('#EXT-X-PLAYLIST-TYPE:VOD')) {
        isVod = true;
        pendingStreamInf = false;
        continue;
      }
      if (line.startsWith('#EXT-X-KEY:')) {
        throw HlsUnsupportedFeature('AES-128 / SAMPLE-AES (EXT-X-KEY)');
      }
      if (line.startsWith('#EXT-X-MAP:')) {
        // fMP4 init segment (Apple Dolby Vision examples etc.). For a
        // concat-based merge the init file is simply the first file in
        // the output, so we support a single map URI. Multiple
        // *different* maps (per-period/discontinuity) need proper
        // muxing — not supported.
        final u = _strAttr(line.substring('#EXT-X-MAP:'.length), 'URI');
        if (u != null && u.isNotEmpty) {
          final resolved = _resolve(_stripQuotes(u), baseUri);
          if (mapUri == null) {
            mapUri = resolved;
          } else if (mapUri != resolved) {
            throw HlsUnsupportedFeature('multiple EXT-X-MAP segments');
          }
        }
        continue;
      }
      if (line.startsWith('#EXT-X-BYTERANGE:')) {
        currentByterange = line.substring('#EXT-X-BYTERANGE:'.length).trim();
        continue;
      }
      if (line.startsWith('#EXT-X-DISCONTINUITY')) {
        // Discontinuity — keep pending byterange (it spans the tag) but
        // any open EXTINF belongs to the previous segment.
        continue;
      }
      if (line.startsWith('#EXTINF:')) {
        final rest = line.substring('#EXTINF:'.length);
        // RFC 8216 §4.3.1: `#EXTINF:<duration>,[<title>]` — the FIRST
        // comma separates duration from title, and the title runs to
        // end of line (it may itself contain commas).
        final commaIdx = rest.indexOf(',');
        if (commaIdx < 0) {
          currentDuration = _parseDouble(rest);
        } else {
          currentDuration = _parseDouble(rest.substring(0, commaIdx));
          currentTitle = rest.substring(commaIdx + 1);
        }
        continue;
      }
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        isMaster = true;
        pendingStreamInf = true;
        final attrs = line.substring('#EXT-X-STREAM-INF:'.length);
        pendingBandwidth = _intAttr(attrs, 'BANDWIDTH');
        pendingResolution = _strAttr(attrs, 'RESOLUTION');
        pendingCodecs = _strAttr(attrs, 'CODECS');
        continue;
      }
      // Any other tag — ignore (DATERANGE, PROGRAM-DATE-TIME, etc.).
      pendingStreamInf = false;
      continue;
    }

    // URI line.
    if (pendingStreamInf) {
      variants.add(HlsVariant(
        uri: _resolve(line, baseUri),
        bandwidth: pendingBandwidth ?? 0,
        resolution: pendingResolution,
        codecs: pendingCodecs,
      ));
      pendingStreamInf = false;
      pendingBandwidth = null;
      pendingResolution = null;
      pendingCodecs = null;
    } else {
      segments.add(HlsSegment(
        uri: _resolve(line, baseUri),
        durationSec: currentDuration ?? 0,
        title: currentTitle,
        byterange: currentByterange,
      ));
      currentDuration = null;
      currentTitle = null;
      currentByterange = null;
    }
  }

  if (isMaster && variants.isEmpty) {
    throw HlsParseException('master playlist with no variants');
  }
  if (!isMaster && segments.isEmpty) {
    throw HlsParseException('media playlist with no segments');
  }
  return HlsPlaylist(
    isMaster: isMaster,
    isVod: isVod,
    variants: List.unmodifiable(variants),
    segments: List.unmodifiable(segments),
    mapUri: mapUri,
  );
}

Uri _resolve(String raw, Uri baseUri) {
  // `Uri.resolve` handles absolute, relative, and protocol-relative
  // (//host/path) forms in one call. No extra branching needed.
  return baseUri.resolve(raw.trim());
}

double? _parseDouble(String s) {
  // RFC 8216 uses '.' as the decimal separator. Some legacy playlists
  // may use ','; we accept both defensively.
  return double.tryParse(s.trim().replaceAll(',', '.'));
}

int? _intAttr(String attrs, String name) {
  final i = attrs.indexOf('$name=');
  if (i < 0) return null;
  final start = i + name.length + 1;
  var end = attrs.indexOf(',', start);
  if (end < 0) end = attrs.length;
  return int.tryParse(attrs.substring(start, end).trim());
}

String? _strAttr(String attrs, String name) {
  final i = attrs.indexOf('$name=');
  if (i < 0) return null;
  final start = i + name.length + 1;
  // Quoted values may contain commas (e.g. CODECS="a,b") — read up to
  // the closing quote instead of the next comma.
  if (start < attrs.length && attrs[start] == '"') {
    final close = attrs.indexOf('"', start + 1);
    if (close < 0) return attrs.substring(start + 1);
    return attrs.substring(start + 1, close);
  }
  final end = attrs.indexOf(',', start);
  if (end < 0) return attrs.substring(start).trim();
  return attrs.substring(start, end).trim();
}

String _stripQuotes(String s) {
  final t = s.trim();
  if (t.length >= 2 && t.startsWith('"') && t.endsWith('"')) {
    return t.substring(1, t.length - 1);
  }
  return t;
}
