// Unit tests for HLS URL detection and filename derivation.
import 'package:flutter_test/flutter_test.dart';
import 'package:velocita/src/features/hls/hls.dart';

void main() {
  group('isM3u8', () {
    test('detects lowercase .m3u8 suffix', () {
      expect(isM3u8('https://cdn.example.com/path/prog_index.m3u8'), isTrue);
    });

    test('detects uppercase .M3U8 suffix', () {
      expect(isM3u8('https://cdn.example.com/VIDEO.M3U8'), isTrue);
    });

    test('detects .m3u8 with query string', () {
      expect(isM3u8('https://cdn.example.com/x.m3u8?token=abc'), isTrue);
    });

    test('detects .m3u8 with fragment', () {
      expect(isM3u8('https://cdn.example.com/x.m3u8#frag'), isTrue);
    });

    test('detects .m3u (audio playlists)', () {
      expect(isM3u8('https://cdn.example.com/audio.m3u'), isTrue);
    });

    test('rejects .mp4', () {
      expect(isM3u8('https://cdn.example.com/video.mp4'), isFalse);
    });

    test('rejects m3u8api host (substring trap)', () {
      expect(isM3u8('https://m3u8api.example.com/foo.ts'), isFalse);
    });

    test('rejects api.m3u8v2 path segment (substring trap)', () {
      expect(isM3u8('https://example.com/api.m3u8v2/list'), isFalse);
    });

    test('rejects empty string', () {
      expect(isM3u8(''), isFalse);
    });
  });

  group('baseNameForHlsUrl', () {
    test('strips .m3u8 extension', () {
      final name = baseNameForHlsUrl(
          Uri.parse('https://cdn.example.com/videos/prog_index.m3u8'));
      expect(name, 'prog_index');
    });

    test('strips .m3u extension', () {
      final name =
          baseNameForHlsUrl(Uri.parse('https://cdn.example.com/audio.m3u'));
      expect(name, 'audio');
    });

    test('falls back to stream when path is empty', () {
      final name = baseNameForHlsUrl(Uri.parse('https://cdn.example.com/'));
      expect(name, 'stream');
    });

    test('sanitises filesystem-illegal characters', () {
      final name = baseNameForHlsUrl(
          Uri.parse('https://cdn.example.com/my%3Avideo%3Atitle.m3u8'));
      // %3A decodes to ':' in pathSegments — must become '_'.
      expect(name, isNot(contains(':')));
    });

    test('caps length at 80 characters', () {
      final long = 'a' * 200;
      final name = baseNameForHlsUrl(Uri.parse('https://cdn.example.com/$long.m3u8'));
      expect(name.length, lessThanOrEqualTo(80));
    });
  });
}
