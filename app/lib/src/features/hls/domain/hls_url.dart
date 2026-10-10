/// Helpers for detecting HLS URLs and deriving a safe filename stem.
library;

/// True if [url] points at an HLS playlist (`.m3u8` or `.m3u`).
///
/// We deliberately check the **path component** (everything before
/// `?` / `#`) and use a suffix match — never a substring match.
/// A substring check would false-positive on URLs like
/// `https://m3u8api.example.com/foo` or `https://example.com/api.m3u8v2/`.
bool isM3u8(String url) {
  var end = url.length;
  final q = url.indexOf('?');
  if (q >= 0 && q < end) end = q;
  final hash = url.indexOf('#');
  if (hash >= 0 && hash < end) end = hash;
  final path = url.substring(0, end).toLowerCase();
  return path.endsWith('.m3u8') || path.endsWith('.m3u');
}

/// Derive a filesystem-safe base filename from an HLS playlist URL.
///
/// Strips the `.m3u8` / `.m3u` extension and delegates to
/// [sanitizeFileName]. The merged output is named `<baseName>.ts`
/// (or `.mp4` for fMP4); this is what produces the stem.
String baseNameForHlsUrl(Uri uri) {
  var last = uri.pathSegments.isEmpty ? 'stream' : uri.pathSegments.last;
  var stem = last;
  final dot = last.lastIndexOf('.');
  if (dot > 0) stem = last.substring(0, dot);
  if (stem.isEmpty) stem = 'stream';
  return sanitizeFileName(stem);
}

/// Sanitize a user- (or page-) supplied name for use as a filename
/// stem: strips characters forbidden on Windows and POSIX
/// (`< > : " / \ | ? *` plus control chars), trims, and caps at 80
/// characters.
String sanitizeFileName(String input, {int maxLength = 80}) {
  final banned = RegExp(r'[<>:"/\\|?*\x00-\x1f]');
  var v = input.replaceAll(banned, '_').trim();
  // Collapse runs of whitespace/underscores left by long page titles.
  v = v.replaceAll(RegExp(r'\s+'), ' ');
  if (v.length > maxLength) v = v.substring(0, maxLength).trim();
  return v;
}
