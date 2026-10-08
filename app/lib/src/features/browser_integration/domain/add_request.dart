/// Pure-Dart value object for a pending "add task" request coming from a
/// browser extension, a `velocita://add?url=…` deep link, or the local
/// HTTP IPC bridge.
///
/// The browser extension produces this on the wire as
/// `{"url":"…","referer":"…","tabTitle":"…"}`; the HTTP bridge parses the
/// same shape. JSON ↔ `AddRequest` mapping lives in
/// `data/browser_integration_service.dart` (private), so the domain layer
/// stays free of any serialization concern.
library;

enum AddSource { extension, deepLink, hostForward, unknown }

class AddRequest {
  const AddRequest({
    required this.url,
    required this.source,
    required this.receivedAt,
    this.referer,
    this.tabTitle,
  });

  final String url;
  final AddSource source;
  final DateTime receivedAt;
  final String? referer;
  final String? tabTitle;

  /// Extension-generated dedup hint. When two requests with the same key
  /// arrive within [dedupWindow], the second one is silently dropped.
  /// `null` disables dedup for this request.
  final String? dedupKey = null;

  /// Window in which two requests with the same [dedupKey] are collapsed.
  static const Duration dedupWindow = Duration(seconds: 2);
}
