// ignore_for_file: avoid_relative_lib_imports
// Chrome Native Messaging wire format (verified against
// developer.chrome.com/docs/extensions/develop/concepts/native-messaging):
//
//   Each frame = 4-byte little-endian uint32 length prefix + UTF-8 JSON
//   payload. Length caps: 1 MB per frame.
//
// The host reads from stdin and writes to stdout. The browser closes
// stdin when the messaging port disconnects, which is how the host
// detects end-of-session.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Maximum single-frame payload size. Chrome / Firefox both cap at 1 MB.
const int nativeMessagingMaxFrameBytes = 1024 * 1024;

/// One frame read off stdin. [body] is the raw JSON UTF-8 bytes.
class NativeMessagingFrame {
  const NativeMessagingFrame(this.body);
  final Uint8List body;
  String get jsonText => utf8.decode(body);
  Map<String, Object?> get json =>
      jsonDecode(jsonText) as Map<String, Object?>;
}

/// Reads a single frame from [input]. The returned future completes after
/// the 4-byte header has been consumed **and** [length] body bytes have
/// been consumed. Throws [FormatException] on length == 0, length >
/// [nativeMessagingMaxFrameBytes], or non-UTF-8 body.
Future<NativeMessagingFrame> readFrame(Stream<List<int>> input) async {
  // The single-subscription stdin stream cannot be re-listened to,
  // so we drain it through one StreamIterator and split the bytes
  // into the 4-byte header and the body buffer ourselves.
  final iter = StreamIterator(input);
  final pending = <int>[];
  try {
    final header = await _readBytes(iter, pending, 4);
    final length =
        ByteData.sublistView(header).getUint32(0, Endian.little);
    if (length == 0) {
      throw const FormatException('native messaging: zero-length frame');
    }
    if (length > nativeMessagingMaxFrameBytes) {
      throw FormatException(
        'native messaging: frame too large ($length > '
        '$nativeMessagingMaxFrameBytes)',
      );
    }
    final body = await _readBytes(iter, pending, length);
    try {
      utf8.decode(body); // validate utf-8 eagerly
    } on FormatException catch (e) {
      throw FormatException('native messaging: invalid utf-8 in body: $e');
    }
    return NativeMessagingFrame(body);
  } finally {
    await iter.cancel();
  }
}

/// Writes a single frame to [output] as 4-byte LE length + UTF-8 bytes.
/// [output] is flushed once the write is complete.
Future<void> writeFrame(
  IOSink output,
  Map<String, Object?> message,
) async {
  final bytes = Uint8List.fromList(utf8.encode(jsonEncode(message)));
  if (bytes.length > nativeMessagingMaxFrameBytes) {
    throw const FormatException(
      'native messaging: response exceeds 1 MB cap',
    );
  }
  final header = ByteData(4)..setUint32(0, bytes.length, Endian.little);
  output.add(header.buffer.asUint8List());
  output.add(bytes);
  await output.flush();
}

/// Reads exactly [n] bytes from [iter], pulling more chunks as needed.
/// [pending] is a side-channel byte buffer holding any bytes the
/// previous pull produced that we haven't yet consumed (the chunk
/// boundaries do not align with the [n]-byte request).
Future<Uint8List> _readBytes(
  StreamIterator<List<int>> iter,
  List<int> pending,
  int n,
) async {
  while (pending.length < n) {
    if (await iter.moveNext()) {
      pending.addAll(iter.current);
    } else {
      throw const FormatException(
        'native messaging: stream closed before frame was complete',
      );
    }
  }
  // Pop the first n bytes; the rest stay in pending for the next
  // call to consume.
  final out = Uint8List.fromList(pending.sublist(0, n));
  pending.removeRange(0, n);
  return out;
}
