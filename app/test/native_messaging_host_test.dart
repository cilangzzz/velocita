// Unit tests for the Chrome Native Messaging frame reader/writer.
//
// The wire format is 4-byte little-endian uint32 length + UTF-8 JSON
// payload. We exercise boundary cases and a few malformed inputs.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:velocita/src/features/browser_integration/data/native_messaging_host.dart';

void main() {
  group('readFrame', () {
    test('reads a small valid frame in one chunk', () async {
      final payload = utf8.encode(jsonEncode({'type': 'add', 'url': 'x'}));
      final stream = _streamOf(_frame(payload));
      final frame = await readFrame(stream);
      expect(frame.json, {'type': 'add', 'url': 'x'});
    });

    test('reads a frame that arrives split across multiple chunks', () async {
      final payload = utf8.encode(jsonEncode({'k': 'v' * 256}));
      final bytes = _frame(payload);
      // Hand-feed one byte at a time to simulate a slow / chunked pipe.
      final ctrl = StreamController<List<int>>();
      final stream = ctrl.stream;
      final future = readFrame(stream);
      for (final b in bytes) {
        ctrl.add([b]);
      }
      ctrl.close();
      final frame = await future;
      expect(frame.json['k'], 'v' * 256);
    });

    test('rejects a zero-length frame', () async {
      final stream = _streamOf([0, 0, 0, 0]);
      expect(() => readFrame(stream), throwsA(isA<FormatException>()));
    });

    test('rejects a frame larger than the 1 MB cap', () async {
      // 0x00100000 + 1 = 1 MiB + 1 byte
      final header = ByteData(4)..setUint32(0, 0x100001, Endian.little);
      final stream = _streamOf([...header.buffer.asUint8List()]);
      expect(() => readFrame(stream), throwsA(isA<FormatException>()));
    });

    test('accepts a frame at the 1 MB cap exactly', () async {
      // 1 MiB of 'A' bytes is valid UTF-8 (it isn't JSON but the
      // frame reader only validates utf-8, not JSON shape).
      final body = Uint8List(nativeMessagingMaxFrameBytes);
      for (var i = 0; i < body.length; i++) {
        body[i] = 0x41; // 'A'
      }
      final stream = _streamOf(_frame(body));
      final frame = await readFrame(stream);
      expect(frame.body.length, nativeMessagingMaxFrameBytes);
    });

    test('rejects when stdin closes mid-frame', () async {
      final stream = _streamOf([0x10, 0x00]); // length 16, but no body
      expect(() => readFrame(stream), throwsA(isA<FormatException>()));
    });
  });

  group('writeFrame', () {
    test('emits length-prefixed JSON', () async {
      final tmpFile = await _tempFile();
      try {
        final sink = tmpFile.openWrite();
        await writeFrame(sink, {'ok': true, 'n': 42});
        await sink.flush();
        await sink.close();
        final bytes = await tmpFile.readAsBytes();
        final len = ByteData.sublistView(bytes).getUint32(0, Endian.little);
        expect(len, bytes.length - 4);
        final body = jsonDecode(utf8.decode(bytes.sublist(4)));
        expect(body, {'ok': true, 'n': 42});
      } finally {
        if (await tmpFile.exists()) await tmpFile.delete();
      }
    });
  });
}

List<int> _frame(List<int> body) {
  final header = ByteData(4)..setUint32(0, body.length, Endian.little);
  return [...header.buffer.asUint8List(), ...body];
}

Stream<List<int>> _streamOf(List<int> bytes) async* {
  yield bytes;
}

Future<File> _tempFile() async {
  final dir = Directory.systemTemp.createTempSync('velocita_nm_');
  final f = File('${dir.path}/t.bin');
  return f;
}
