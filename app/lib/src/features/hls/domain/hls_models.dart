/// Domain types for the HLS (.m3u8) downloader.
///
/// Velocita's HLS support parses the playlist in-Dart, then drives
/// aria2 (which does NOT support HLS natively — confirmed against
/// the upstream source tree and three Windows 1.37.0 binaries) to
/// fetch each segment as an ordinary task, then concatenates the
/// completed segments into a single `.ts` file.

import 'package:flutter/foundation.dart';

/// A single TS segment referenced by a media playlist.
@immutable
class HlsSegment {
  const HlsSegment({
    required this.uri,
    required this.durationSec,
    this.title,
    this.byterange,
  });

  /// Absolute segment URL (relative URIs are resolved against the
  /// playlist URL by the parser).
  final Uri uri;

  /// Nominal segment duration in seconds (from `#EXTINF`). May be 0
  /// for some live streams.
  final double durationSec;

  /// Optional human-readable title from `#EXTINF:<duration>,<title>`.
  final String? title;

  /// Optional `#EXT-X-BYTERANGE:n@m` string. v1 does not act on
  /// byte-range slicing; aria2 fetches the whole segment.
  final String? byterange;
}

/// A variant declared by a master playlist.
@immutable
class HlsVariant {
  const HlsVariant({
    required this.uri,
    required this.bandwidth,
    this.resolution,
    this.codecs,
  });

  final Uri uri;
  final int bandwidth;
  final String? resolution;
  final String? codecs;
}

/// A parsed HLS playlist.
@immutable
class HlsPlaylist {
  const HlsPlaylist({
    required this.isMaster,
    required this.isVod,
    required this.variants,
    required this.segments,
    this.mapUri,
  });

  /// True if this was a master (variant) playlist.
  final bool isMaster;

  /// True if `#EXT-X-ENDLIST` or `#EXT-X-PLAYLIST-TYPE:VOD` is present.
  final bool isVod;

  /// Non-empty when [isMaster] is true.
  final List<HlsVariant> variants;

  /// Non-empty when [isMaster] is false.
  final List<HlsSegment> segments;

  /// `#EXT-X-MAP` init-segment URI for fMP4 streams (e.g. Apple's
  /// Dolby Vision examples), resolved absolute. `null` for MPEG-TS
  /// playlists. When present, the downloader fetches the init segment
  /// FIRST and the merge concatenates `init + segments` — the result
  /// is a valid fragmented MP4, so the merged file is named `.mp4`
  /// instead of `.ts`.
  final Uri? mapUri;
}

/// One in-flight HLS job: the playlist URL, its working directory
/// (where per-segment files land before merging), and the parallel
/// aria2 gids of the segment downloads.
class HlsJob {
  HlsJob({
    required this.id,
    required this.url,
    required this.saveDir,
    required this.workingDir,
    required this.baseName,
    required this.segments,
    this.mapUri,
  });

  final String id;
  final String url;
  final String saveDir;
  final String workingDir;
  final String baseName;
  final List<HlsSegment> segments;

  /// fMP4 init segment (from `#EXT-X-MAP`), `null` for MPEG-TS.
  final Uri? mapUri;

  final List<String> segmentGids = [];

  bool completed = false;
  String? error;

  /// Total download units = optional init segment + media segments.
  int get itemCount =>
      segments.length + (mapUri != null ? 1 : 0);

  /// `.mp4` for fMP4 (init segment present), `.ts` for MPEG-TS.
  String get outputExtension => mapUri != null ? '.mp4' : '.ts';

  /// Name of the merged output file in [saveDir].
  String get outputFileName => '$baseName$outputExtension';
}

/// Thrown by the parser when the playlist body is unparseable.
class HlsParseException implements Exception {
  HlsParseException(this.message);
  final String message;
  @override
  String toString() => 'HlsParseException: $message';
}

/// Thrown when the playlist references a feature v1 does not support
/// (AES-128, SAMPLE-AES, fMP4 init segments via `#EXT-X-MAP`, live
/// streams over the segment cap).
class HlsUnsupportedFeature implements Exception {
  HlsUnsupportedFeature(this.feature);
  final String feature;
  @override
  String toString() => 'HlsUnsupportedFeature: $feature';
}

/// Thrown by the playlist fetcher on HTTP errors / network failures.
class HlsFetchException implements Exception {
  HlsFetchException(this.statusCode);
  final int? statusCode;
  @override
  String toString() => statusCode == null
      ? 'HlsFetchException'
      : 'HlsFetchException: HTTP $statusCode';
}

/// Thrown by the merger on I/O failures during concatenation.
class HlsMergerException implements Exception {
  HlsMergerException(this.message);
  final String message;
  @override
  String toString() => 'HlsMergerException: $message';
}
