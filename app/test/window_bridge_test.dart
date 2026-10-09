// Unit tests for the Add-Task sub-window IPC contract.
//
// The `AddTaskPayload.encode()` / `AddTaskPayload.decode()` round-trip
// is the contract the C++ side hands the sub-window via argv; if it
// drifts the sub-window silently can't render. `AddTaskResult.toMap`
// / `fromMap` is what the sub-window sends back.
import 'package:flutter_test/flutter_test.dart';
import 'package:velocita/src/features/browser_integration/browser_integration.dart';
import 'package:velocita/src/features/downloads/downloads.dart';

void main() {
  group('AddTaskPayload round-trip', () {
    test('minimal: url + source', () {
      final req = AddRequest(
        url: 'https://example.com/file.zip',
        source: AddSource.extension,
        receivedAt: DateTime(2026, 1, 1),
      );
      final raw = AddTaskPayload(request: req).encode();
      final back = AddTaskPayload.decode(raw).request;
      expect(back.url, req.url);
      expect(back.source, AddSource.extension);
    });

    test('all optional fields survive', () {
      final sent = AddRequest(
        url: 'https://x.test/y?q=1',
        source: AddSource.deepLink,
        receivedAt: DateTime(2026, 10, 8, 17, 30),
        referer: 'https://referer.test/',
        tabTitle: 'Example',
        cookieHeader: 'sid=abc; token=xyz',
        requestHeaders: const ['X-Custom: a', 'X-Other: b'],
      );
      sent.dedupKey = 'k-1';
      final raw = AddTaskPayload(request: sent).encode();
      final back = AddTaskPayload.decode(raw).request;
      expect(back.url, sent.url);
      expect(back.source, AddSource.deepLink);
      expect(back.referer, sent.referer);
      expect(back.tabTitle, sent.tabTitle);
      expect(back.cookieHeader, sent.cookieHeader);
      expect(back.requestHeaders, sent.requestHeaders);
      expect(back.dedupKey, sent.dedupKey);
    });

    test('unknown source name falls back to AddSource.unknown', () {
      final raw = '{"url":"https://x","source":"alien","receivedAt":0}';
      final back = AddTaskPayload.decode(raw).request;
      expect(back.source, AddSource.unknown);
    });

    test('missing optional fields decode to null', () {
      final raw = '{"url":"https://x","source":"extension","receivedAt":0}';
      final back = AddTaskPayload.decode(raw).request;
      expect(back.referer, isNull);
      expect(back.tabTitle, isNull);
      expect(back.cookieHeader, isNull);
      expect(back.requestHeaders, isNull);
      expect(back.dedupKey, isNull);
    });

    test('malformed JSON throws', () {
      expect(
        () => AddTaskPayload.decode('not json'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('AddTaskResult round-trip', () {
    test('confirmed URL', () {
      final r = SubmitResult(
        kind: SubmitKind.url,
        url: 'https://x.test',
        saveDir: r'C:\dl',
      );
      final result = AddTaskResult.confirmed(r).toMap();
      final back = AddTaskResult.fromMap(result);
      expect(back.cancelled, false);
      expect(back.submit, isNotNull);
      expect(back.submit!.kind, SubmitKind.url);
      expect(back.submit!.url, 'https://x.test');
      expect(back.submit!.saveDir, r'C:\dl');
    });

    test('cancelled', () {
      final result = const AddTaskResult.cancelled().toMap();
      final back = AddTaskResult.fromMap(result);
      expect(back.cancelled, true);
      expect(back.submit, isNull);
    });

    test('missing submit field decodes as cancelled', () {
      final back = AddTaskResult.fromMap({'cancelled': false});
      expect(back.cancelled, true);
    });
  });
}
