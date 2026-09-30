// Unit tests for the magnet URI parser.
import 'package:test/test.dart';
import 'package:velocita_kernel/velocita_kernel.dart';

void main() {
  group('parseMagnet', () {
    test('Big Buck Bunny reference magnet', () {
      final m = parseMagnet(
        'magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c&dn=Big+Buck+Bunny&tr=udp%3A%2F%2Fexplodie.org%3A6969&tr=udp%3A%2F%2Ftracker.coppersurfer.tk%3A6969&ws=https%3A%2F%2Fwebseed.bbtvdl.de%2Fbbb',
      );
      expect(m.displayName, 'Big Buck Bunny');
      expect(m.btihHash, 'dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c');
      expect(m.trackers, [
        'udp://explodie.org:6969',
        'udp://tracker.coppersurfer.tk:6969',
      ]);
      expect(m.webSeeds, ['https://webseed.bbtvdl.de/bbb']);
      expect(m.hasBtih, isTrue);
    });

    test('empty trackers', () {
      final m = parseMagnet('magnet:?xt=urn:btih:abc&dn=test');
      expect(m.trackers, isEmpty);
      expect(m.webSeeds, isEmpty);
      expect(m.displayName, 'test');
    });

    test('plus sign decoded as space', () {
      final m = parseMagnet('magnet:?xt=urn:btih:abc&dn=hello+world');
      expect(m.displayName, 'hello world');
    });

    test('looksLikeMagnet', () {
      expect(looksLikeMagnet('magnet:?xt=urn:btih:abc'), isTrue);
      expect(looksLikeMagnet('http://example.com'), isFalse);
    });

    test('deduplicates trackers', () {
      final m = parseMagnet(
        'magnet:?xt=urn:btih:abc&tr=udp%3A%2F%2Fa.example%3A6969&tr=udp%3A%2F%2Fa.example%3A6969',
      );
      expect(m.trackers.length, 1);
      expect(m.trackers.first, 'udp://a.example:6969');
    });
  });
}
