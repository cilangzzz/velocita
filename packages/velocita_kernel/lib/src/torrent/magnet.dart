/// Pure-Dart Magnet URI parser.
///
/// Spec: <https://en.wikipedia.org/wiki/Magnet_link>
///
/// Magnet URIs look like:
///   magnet:?xt=urn:btih:...&dn=Display+Name&tr=tracker1&tr=tracker2&ws=...
///
/// We extract:
///   - `xt`  : exact-topics (we keep `urn:btih:<hash>` form)
///   - `dn`  : display name
///   - `tr`  : trackers (multi-valued)
///   - `ws`  : web seeds (multi-valued)
///   - `xs`  : exact source (a `.torrent` URL)
///   - `as`  : acceptable source
///   - `mt`  : metadata link
///   - `x.pe` / `x.pe.*` : PEX-compatible peer hints
class Magnet {
  Magnet({
    required this.exactTopics,
    required this.displayName,
    required this.trackers,
    required this.webSeeds,
    this.exactSource,
    this.acceptableSource,
    this.metadataLink,
    this.raw,
  });

  /// The full magnet URI text (after URL-decoding once).
  final String? raw;

  /// xt values, e.g. `["urn:btih:abcdef..."]`.
  final List<String> exactTopics;

  /// Best-effort filename.
  final String? displayName;

  /// `tr` values, deduplicated.
  final List<String> trackers;

  /// `ws` values.
  final List<String> webSeeds;

  /// `xs` — preferred torrent URL.
  final String? exactSource;

  /// `as` — fallback torrent URL.
  final String? acceptableSource;

  /// `mt` — metadata link.
  final String? metadataLink;

  /// True if any `urn:btih:` exact-topic is present — that's what aria2
  /// consumes for BitTorrent.
  bool get hasBtih => exactTopics.any((t) => t.startsWith('urn:btih:'));

  /// `xt:urn:btih:<hash>` — the SHA1 info hash aria2.addUri passes as a
  /// metadata source.
  String? get btihHash {
    for (final t in exactTopics) {
      if (t.startsWith('urn:btih:')) return t.substring('urn:btih:'.length);
    }
    return null;
  }
}

/// Parse a `magnet:?...` URI into a [Magnet].
///
/// Decoding follows the magnet-link spec: percent-decoding uses `+` for
/// space (form-style), but `&` inside trackers should not be split. We do a
/// single-pass split on `&` and decode each name=value pair.
Magnet parseMagnet(String input) {
  // Normalize: strip `magnet:?` if present.
  final queryStart = input.indexOf('?');
  if (queryStart < 0) {
    // No '?' — assume the whole thing is query (without scheme).
    return _parseQuery(input);
  }
  return _parseQuery(input.substring(queryStart + 1));
}

Magnet _parseQuery(String query) {
  final pairs = <String, String>{};
  final listKeys = <String, List<String>>{};
  for (final segment in query.split('&')) {
    if (segment.isEmpty) continue;
    final eq = segment.indexOf('=');
    final rawKey = eq < 0 ? segment : segment.substring(0, eq);
    final rawValue = eq < 0 ? '' : segment.substring(eq + 1);
    final key = _decode(rawKey);
    final value = _decode(rawValue);
    if (rawKey.startsWith('x.')) {
      // 'x.' prefix is a namespace; we don't need to specialize.
      listKeys.putIfAbsent(rawKey, () => <String>[]).add(value);
      continue;
    }
    switch (key) {
      case 'xt':
      case 'tr':
      case 'ws':
        listKeys.putIfAbsent(key, () => <String>[]).add(value);
        break;
      case 'dn':
      case 'xs':
      case 'as':
      case 'mt':
        pairs[key] = value;
        break;
      default:
        // Unknown keys are ignored for now.
        break;
    }
  }
  return Magnet(
    raw: query,
    exactTopics: listKeys['xt'] ?? const [],
    displayName: pairs['dn'],
    trackers: (listKeys['tr'] ?? const []).toSet().toList(growable: false),
    webSeeds: listKeys['ws'] ?? const [],
    exactSource: pairs['xs'],
    acceptableSource: pairs['as'],
    metadataLink: pairs['mt'],
  );
}

String _decode(String input) {
  // Magnet uses form-style percent-encoding with `+` for space.
  var result = StringBuffer();
  var i = 0;
  while (i < input.length) {
    final c = input[i];
    if (c == '+') {
      result.write(' ');
    } else if (c == '%' && i + 2 < input.length) {
      final hex = input.substring(i + 1, i + 3);
      final byte = int.tryParse(hex, radix: 16);
      if (byte != null) {
        result.writeCharCode(byte);
        i += 2;
      } else {
        result.write(c);
      }
    } else {
      result.write(c);
    }
    i++;
  }
  return result.toString();
}

/// Heuristic test for whether `s` looks like a magnet URI.
bool looksLikeMagnet(String s) =>
    s.startsWith('magnet:?') || s.startsWith('magnet:?');