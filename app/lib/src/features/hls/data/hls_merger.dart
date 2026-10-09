/// Concatenates HLS segment files into a single output file.
///
/// The merge is atomic: writes go to `<output>.tmp` first, then the
/// temp is renamed over the target. If any segment is missing or
/// the stream errors out, the temp is removed and the target is left
/// untouched. Each segment is streamed (no full-file buffering) and
/// the upstream is always cancelled in a `finally` so partial
/// downloads don't leak file handles.
library;

import 'dart:io';

import '../domain/hls_models.dart';

/// Concatenate [segmentFiles] in order into [outputFile].
Future<void> mergeSegments({
  required List<File> segmentFiles,
  required File outputFile,
}) async {
  await outputFile.parent.create(recursive: true);

  final tmp = File('${outputFile.path}.tmp');
  if (await tmp.exists()) await tmp.delete();

  final sink = tmp.openWrite();
  try {
    for (final seg in segmentFiles) {
      if (!await seg.exists()) {
        throw HlsMergerException('segment missing: ${seg.path}');
      }
      // addStream fully consumes the read stream and its future
      // completes (or errors) when the copy finishes — no explicit
      // cancel needed.
      await sink.addStream(seg.openRead());
    }
  } catch (_) {
    await sink.close();
    if (await tmp.exists()) await tmp.delete();
    rethrow;
  }
  await sink.close();

  if (await outputFile.exists()) await outputFile.delete();
  await tmp.rename(outputFile.path);
}
