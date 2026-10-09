// Unit tests for the HLS segment merger (file I/O in a temp dir).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:velocita/src/features/hls/data/hls_merger.dart';
import 'package:velocita/src/features/hls/domain/hls_models.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('hls_merger_test');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('mergeSegments', () {
    test('merges 3 small files in order', () async {
      final a = File('${tmp.path}/a')..writeAsStringSync('A');
      final b = File('${tmp.path}/b')..writeAsStringSync('B');
      final c = File('${tmp.path}/c')..writeAsStringSync('C');
      final out = File('${tmp.path}/out.ts');

      await mergeSegments(segmentFiles: [a, b, c], outputFile: out);

      expect(await out.readAsString(), 'ABC');
      // Temp file is gone after a successful merge.
      expect(await File('${out.path}.tmp').exists(), isFalse);
    });

    test('handles 0-byte segments in the middle', () async {
      final a = File('${tmp.path}/a')..writeAsStringSync('A');
      final b = File('${tmp.path}/b')..writeAsStringSync('');
      final c = File('${tmp.path}/c')..writeAsStringSync('C');
      final out = File('${tmp.path}/out.ts');

      await mergeSegments(segmentFiles: [a, b, c], outputFile: out);

      expect(await out.readAsString(), 'AC');
    });

    test('throws when a segment file is missing', () async {
      final a = File('${tmp.path}/a')..writeAsStringSync('A');
      final missing = File('${tmp.path}/nope');
      final out = File('${tmp.path}/out.ts');

      expect(
        () => mergeSegments(segmentFiles: [a, missing], outputFile: out),
        throwsA(isA<HlsMergerException>()),
      );
      // No half-written output left behind.
      expect(await out.exists(), isFalse);
      expect(await File('${out.path}.tmp').exists(), isFalse);
    });

    test('replaces an existing output file', () async {
      final a = File('${tmp.path}/a')..writeAsStringSync('NEW');
      final out = File('${tmp.path}/out.ts')..writeAsStringSync('OLD');

      await mergeSegments(segmentFiles: [a], outputFile: out);

      expect(await out.readAsString(), 'NEW');
    });
  });
}
