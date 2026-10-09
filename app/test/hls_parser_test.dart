// Unit tests for the HLS playlist parser (pure Dart, no I/O).
import 'package:flutter_test/flutter_test.dart';
import 'package:velocita/src/features/hls/data/hls_parser.dart';
import 'package:velocita/src/features/hls/domain/hls_models.dart';

Uri _base(String s) => Uri.parse(s);

void main() {
  group('HlsParser — media playlists', () {
    test('parses minimal media playlist with EXTINF + URL', () {
      const body = '''
#EXTM3U
#EXT-X-TARGETDURATION:10
#EXTINF:5.0,
seg1.ts
#EXT-X-ENDLIST
''';
      final p = parseHlsPlaylist(body, _base('https://cdn.example.com/p/x.m3u8'));
      expect(p.isMaster, isFalse);
      expect(p.isVod, isTrue);
      expect(p.segments.length, 1);
      expect(p.segments.first.uri.toString(),
          'https://cdn.example.com/p/seg1.ts');
      expect(p.segments.first.durationSec, 5.0);
    });

    test('resolves relative URIs against the playlist URL', () {
      const body = '''
#EXTM3U
#EXTINF:4.0,
seg.ts
#EXT-X-ENDLIST
''';
      final p = parseHlsPlaylist(
          body, _base('https://example.com/path/to/playlist.m3u8'));
      expect(p.segments.first.uri.toString(), 'https://example.com/path/to/seg.ts');
    });

    test('resolves protocol-relative URIs', () {
      const body = '''
#EXTM3U
#EXTINF:4.0,
//cdn.example.com/x.ts
#EXT-X-ENDLIST
''';
      final p = parseHlsPlaylist(body, _base('https://example.com/p/main.m3u8'));
      expect(p.segments.first.uri.toString(), 'https://cdn.example.com/x.ts');
    });

    test('handles CRLF and LF line endings', () {
      const body = '#EXTM3U\r\n#EXTINF:3.0,\r\na.ts\r\n#EXTINF:3.0,\nb.ts\n#EXT-X-ENDLIST\r\n';
      final p = parseHlsPlaylist(body, _base('https://cdn.example.com/x.m3u8'));
      expect(p.segments.length, 2);
    });

    test('ignores blank lines and unknown EXT tags', () {
      const body = '''
#EXTM3U

#EXT-X-DATERANGE:ID=1
#EXT-X-PROGRAM-DATE-TIME:2026-01-01T00:00:00Z
#EXTINF:2.0,

a.ts
#EXT-X-ENDLIST
''';
      final p = parseHlsPlaylist(body, _base('https://cdn.example.com/x.m3u8'));
      expect(p.segments.length, 1);
    });

    test('EXTINF title may contain commas (split on FIRST comma)', () {
      const body = '''
#EXTM3U
#EXTINF:5.0,Hello, World - episode 1
seg.ts
#EXT-X-ENDLIST
''';
      final p = parseHlsPlaylist(body, _base('https://cdn.example.com/x.m3u8'));
      expect(p.segments.first.title, 'Hello, World - episode 1');
      expect(p.segments.first.durationSec, 5.0);
    });

    test('EXTINF without a title still parses the duration', () {
      const body = '''
#EXTM3U
#EXTINF:7.5
seg.ts
#EXT-X-ENDLIST
''';
      final p = parseHlsPlaylist(body, _base('https://cdn.example.com/x.m3u8'));
      expect(p.segments.first.durationSec, 7.5);
      expect(p.segments.first.title, isNull);
    });

    test('EXTINF comma-decimal is treated as title separator (RFC mandates dot)', () {
      // `#EXTINF:4,5,` — RFC 8216 only allows '.' decimals, so the
      // first comma ends the duration: duration=4, title='5,'.
      const body = '''
#EXTM3U
#EXTINF:4,5,
seg.ts
#EXT-X-ENDLIST
''';
      final p = parseHlsPlaylist(body, _base('https://cdn.example.com/x.m3u8'));
      expect(p.segments.first.durationSec, 4.0);
      expect(p.segments.first.title, '5,');
    });

    test('strips a UTF-8 BOM', () {
      final body = '﻿#EXTM3U\n#EXTINF:1.0,\ns.ts\n#EXT-X-ENDLIST\n';
      final p = parseHlsPlaylist(body, _base('https://cdn.example.com/x.m3u8'));
      expect(p.segments.length, 1);
    });

    test('throws on a media playlist with no segments', () {
      const body = '''
#EXTM3U
#EXT-X-ENDLIST
''';
      expect(
        () => parseHlsPlaylist(body, _base('https://cdn.example.com/x.m3u8')),
        throwsA(isA<HlsParseException>()),
      );
    });
  });

  group('HlsParser — master playlists', () {
    test('parses variants with bandwidth + resolution', () {
      const body = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1280x720,CODECS="avc1.640029"
720p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
360p.m3u8
''';
      final p = parseHlsPlaylist(body, _base('https://cdn.example.com/master.m3u8'));
      expect(p.isMaster, isTrue);
      expect(p.segments, isEmpty);
      expect(p.variants.length, 2);
      expect(p.variants.first.bandwidth, 2000000);
      expect(p.variants.first.resolution, '1280x720');
      expect(p.variants.first.uri.toString(),
          'https://cdn.example.com/720p.m3u8');
    });

    test('throws on a master playlist with no variants', () {
      const body = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=100
''';
      expect(
        () => parseHlsPlaylist(body, _base('https://cdn.example.com/m.m3u8')),
        throwsA(isA<HlsParseException>()),
      );
    });
  });

  group('HlsParser — unsupported features', () {
    test('throws on EXT-X-KEY (AES-128)', () {
      const body = '''
#EXTM3U
#EXT-X-KEY:METHOD=AES-128,URI="https://cdn.example.com/key",IV=0x1234
#EXTINF:5.0,
seg.ts
#EXT-X-ENDLIST
''';
      expect(
        () => parseHlsPlaylist(body, _base('https://cdn.example.com/x.m3u8')),
        throwsA(isA<HlsUnsupportedFeature>()
            .having((e) => e.feature, 'feature', contains('AES'))),
      );
    });

    test('captures EXT-X-MAP init segment URI (fMP4)', () {
      const body = '''
#EXTM3U
#EXT-X-MAP:URI="init.mp4"
#EXTINF:5.0,
seg.m4s
#EXT-X-ENDLIST
''';
      final p = parseHlsPlaylist(body, _base('https://cdn.example.com/x.m3u8'));
      expect(p.mapUri.toString(), 'https://cdn.example.com/init.mp4');
      expect(p.segments.length, 1);
    });

    test('same EXT-X-MAP repeated is fine', () {
      const body = '''
#EXTM3U
#EXT-X-MAP:URI="init.mp4"
#EXTINF:5.0,
a.m4s
#EXT-X-MAP:URI="init.mp4"
#EXTINF:5.0,
b.m4s
#EXT-X-ENDLIST
''';
      final p = parseHlsPlaylist(body, _base('https://cdn.example.com/x.m3u8'));
      expect(p.mapUri.toString(), 'https://cdn.example.com/init.mp4');
      expect(p.segments.length, 2);
    });

    test('throws on two different EXT-X-MAP URIs', () {
      const body = '''
#EXTM3U
#EXT-X-MAP:URI="init1.mp4"
#EXTINF:5.0,
a.m4s
#EXT-X-MAP:URI="init2.mp4"
#EXTINF:5.0,
b.m4s
#EXT-X-ENDLIST
''';
      expect(
        () => parseHlsPlaylist(body, _base('https://cdn.example.com/x.m3u8')),
        throwsA(isA<HlsUnsupportedFeature>()
            .having((e) => e.feature, 'feature', contains('EXT-X-MAP'))),
      );
    });
  });
}
