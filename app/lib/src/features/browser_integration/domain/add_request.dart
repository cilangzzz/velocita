/// Pure-Dart value object for a pending "add task" request coming from a
/// browser extension, a `velocita://add?url=…` deep link, or the local
/// HTTP IPC bridge.
///
/// The browser extension produces this on the wire as
/// `{"url":"…","referer":"…","tabTitle":"…"}`; the HTTP bridge parses the
/// same shape. JSON ↔ `AddRequest` mapping lives in
/// `data/browser_integration_service.dart` (private), so the domain layer
/// stays free of any serialization concern.
///
/// Wire format additions (used for cookie-aware download interception):
///   * [cookieHeader] — pre-joined `"k1=v1; k2=v2"` string emitted by the
///     extension's `chrome.cookies.getAll` collection; the listener
///     prepends `"Cookie: "` and folds it into aria2's `header` option.
///   * [requestHeaders] — full list of `"Header: value"` strings already
///     shaped for aria2's `header` array option. Use this when you need
///     non-cookie overrides (e.g. `Referer`, `User-Agent`). Duplicating
///     `Referer` here alongside [referer] is harmless — aria2 prefers the
///     `referer` option when both are set, so the dedicated field wins.
library;

enum AddSource { extension, deepLink, hostForward, unknown }

class AddRequest {
  AddRequest({
    required this.url,
    required this.source,
    required this.receivedAt,
    this.referer,
    this.tabTitle,
    this.cookieHeader,
    this.requestHeaders,
    this.suggestedFilename,
  });

  final String url;
  final AddSource source;
  final DateTime receivedAt;
  final String? referer;
  final String? tabTitle;

  /// Pre-baked cookie string (`"k1=v1; k2=v2"`) from
  /// `chrome.cookies.getAll`. `null`/empty when not applicable.
  final String? cookieHeader;

  /// Pre-shaped aria2 `header` array entries. Each string is `"Name: value"`.
  /// Typically carries `Cookie:` and the browser's `User-Agent:` so the
  /// replayed request authenticates like the original page load did.
  /// `null` when not applicable.
  final List<String>? requestHeaders;

  /// Filename the browser determined for this download (basename only).
  /// Mapped to aria2's `out` option so intercepted downloads land under
  /// the name the browser picked. `null` when unknown.
  final String? suggestedFilename;

  /// Extension-generated dedup hint. When two requests with the same key
  /// arrive within [dedupWindow], the second one is silently dropped.
  /// `null` disables dedup for this request.
  ///
  /// Mutable so the deep-link / HTTP-host path can stamp a key after
  /// construction (the HTTP bridge parses JSON without a typed hint).
  String? dedupKey;

  /// Window in which two requests with the same [dedupKey] are collapsed.
  static const Duration dedupWindow = Duration(seconds: 2);
}
