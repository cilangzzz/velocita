/// Orchestrator for HLS (.m3u8) downloads.
///
/// aria2c (the engine Velocita spawns) does NOT support HLS — it
/// downloads `.m3u8` as a plain text file and never fetches the
/// segments. The [HlsDownloader] works around this by:
///   1. Fetching the playlist itself (with the user's headers).
///   2. Parsing it (see [parseHlsPlaylist]).
///   3. Driving aria2 to download each segment as an ordinary task
///      with a zero-padded `out` filename and a working-directory
///      `dir` so they can be concatenated in order later.
///   4. Polling `tellStatus` and rolling the per-segment progress up
///      into ONE synthetic task row (segments themselves are hidden
///      from the table by the task-list notifier).
///   5. Concatenating the segments into `<saveDir>/<baseName>.ts`
///      (or `.mp4` for fMP4 streams with an init segment) and
///      verifying the container signature.
///   6. Removing the segment gids and the working directory; the
///      synthetic row flips to `complete` and points at the file.
///
/// A first HLS job bumps aria2's `--max-concurrent-downloads` to
/// 16 (so the segments actually progress in parallel) via
/// `changeGlobalOption`; the value is restored when the last
/// HLS job finishes.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import '../../../kernel_bridge/kernel_provider.dart';
import '../../downloads/data/downloads_repository.dart';
import '../../downloads/domain/download_task.dart';
import '../../downloads/presentation/task_list_provider.dart';
import '../data/hls_merger.dart';
import '../data/hls_parser.dart';
import '../data/hls_playlist_fetcher.dart';
import '../domain/hls_models.dart';
import '../domain/hls_url.dart';

/// Lifecycle event from a finished (or aborted) HLS job. Published
/// via [hlsEventsProvider] so the UI can show a snackbar.
@immutable
class HlsEvent {
  const HlsEvent({
    required this.jobId,
    required this.url,
    required this.success,
    this.message,
    this.mergedFilePath,
  });

  final String jobId;
  final String url;
  final bool success;
  final String? message;
  final String? mergedFilePath;
}

/// Latest HLS event; the screen watches this and shows a snackbar
/// when it changes.
final hlsEventsProvider = StateProvider<HlsEvent?>((ref) => null);

final hlsDownloaderProvider = Provider<HlsDownloader>((ref) {
  return HlsDownloader(ref);
});

class HlsDownloader {
  HlsDownloader(this._ref) {
    _log.info('ready');
  }

  final Ref _ref;
  final Logger _log = Logger('HlsDownloader');

  /// In-flight jobs by id (kept for the duration of the download
  /// for debugging and potential future per-job UI).
  final Map<String, HlsJob> _jobs = {};

  /// Jobs the user cancelled by removing their table row.
  final Set<String> _cancelRequested = {};

  /// Reference count for the global `max-concurrent-downloads` bump.
  /// When it goes from 0 → 1 we bump 5 → 16. When it goes from 1 → 0
  /// we restore the original value.
  int _hlsModeRefCount = 0;
  String? _savedMaxConcurrent;

  /// Start an HLS download. Returns when the segments have been
  /// enqueued (or when the playlist fetch/parse fails). Progress is
  /// surfaced through a single synthetic task row; completion emits
  /// an [HlsEvent].
  Future<String> start({
    required String url,
    required String saveDir,
    required Map<String, Object?>? aria2Options,
    String? displayName,
  }) async {
    final jobId = _mintJobId();
    _log.info('start $jobId url=$url saveDir=$saveDir'
        '${displayName != null ? ' name=$displayName' : ''}');

    final headers = _extractRawHeaders(aria2Options);
    final referer = _extractReferer(aria2Options);
    final proxyUrl = _proxyUrl();

    // Working dir for the per-segment .ts files. Created eagerly so
    // we can clean it up on early failures.
    final dataDir = await getApplicationSupportDirectory();
    final workingDir = Directory('${dataDir.path}/velocita/hls/$jobId');
    await workingDir.create(recursive: true);

    // Fetch + parse.
    var playlistUri = Uri.parse(url);
    HlsPlaylist playlist;
    try {
      final fetcher = HlsPlaylistFetcher(proxyUrl: proxyUrl);
      final first = await fetcher.fetch(playlistUri,
          headerLines: headers, referer: referer);
      playlistUri = first.finalUri;
      playlist = parseHlsPlaylist(first.body, playlistUri);
      if (playlist.isMaster) {
        // Pick the first variant for v1 (no variant-selection UI yet).
        final variant = playlist.variants.first;
        final media = await fetcher.fetch(variant.uri,
            headerLines: headers, referer: referer);
        playlist = parseHlsPlaylist(media.body, media.finalUri);
      }
      _assertPlayable(playlist);
    } catch (e) {
      await _safeDelete(workingDir);
      final msg = e is HlsUnsupportedFeature
          ? e.feature
          : e is HlsFetchException
              ? 'HTTP ${e.statusCode ?? 'error'}'
              : '$e';
      _emit(HlsEvent(
        jobId: jobId,
        url: url,
        success: false,
        message: msg,
      ));
      rethrow;
    }

    final job = HlsJob(
      id: jobId,
      url: url,
      saveDir: saveDir,
      workingDir: workingDir.path,
      baseName: _resolveBaseName(displayName, originalUri: Uri.parse(url)),
      segments: playlist.segments,
      mapUri: playlist.mapUri,
    );
    _jobs[jobId] = job;
    // Surface the job row immediately (before the segments appear).
    _upsertRow(job, status: DownloadStatus.active);
    unawaited(_runJob(job, headers, referer));
    return jobId;
  }

  /// User removed the HLS row — stop polling, force-remove the
  /// segments, delete the work dir. No-op for unknown/finished jobs.
  Future<void> cancel(String jobId) async {
    _cancelRequested.add(jobId);
    _log.info('cancel requested: $jobId');
  }

  Future<void> _runJob(
    HlsJob job,
    List<String> headers,
    String? referer,
  ) async {
    await _enterHlsMode();
    try {
      if (_isCancelled(job.id)) throw const HlsCancelled();
      await _enqueueSegments(job, headers, referer);
      _log.info('${job.id} enqueued ${job.segmentGids.length} items');
      await _pollUntilDone(job);
      _log.info('${job.id} all segments complete — merging');
      await _merge(job);
      if (_isCancelled(job.id)) throw const HlsCancelled();
      final size = await _verifyMergedOutput(job);
      await _cleanupSegments(job);
      _log.info('${job.id} merged → ${job.saveDir}\\${job.outputFileName}');
      // Flip the row to complete and unhide its gids (they are gone
      // from aria2 anyway). The completed row stays in the table and
      // points at the merged file.
      _upsertRow(
        job,
        status: DownloadStatus.complete,
        ownedGids: const {},
        totalBytes: size,
        doneBytes: size,
      );
      _emit(HlsEvent(
        jobId: job.id,
        url: job.url,
        success: true,
        mergedFilePath: '${job.saveDir}\\${job.outputFileName}',
      ));
    } catch (e, st) {
      final cancelled = e is HlsCancelled || _isCancelled(job.id);
      _cancelRequested.remove(job.id);
      await _forceRemoveAll(job);
      if (cancelled) {
        _log.info('${job.id} cancelled — cleaned up');
        // The user already removed the row; emit nothing.
        return;
      }
      _log.warning('${job.id} failed: $e', e, st);
      _upsertRow(
        job,
        status: DownloadStatus.error,
        ownedGids: const {},
        errorMessage: '$e',
      );
      _emit(HlsEvent(
        jobId: job.id,
        url: job.url,
        success: false,
        message: '$e',
      ));
    } finally {
      await _safeDelete(Directory(job.workingDir));
      _jobs.remove(job.id);
      await _exitHlsMode();
    }
  }

  bool _isCancelled(String jobId) => _cancelRequested.contains(jobId);

  void _assertPlayable(HlsPlaylist p) {
    if (p.isMaster) return; // already resolved to media at this point
    if (p.segments.isEmpty) {
      throw HlsParseException('media playlist has no segments');
    }
    if (!p.isVod && p.segments.length > 1000) {
      throw HlsUnsupportedFeature('live stream exceeds 1000-segment cap');
    }
  }

  /// Base filename for the merged output. Preference order:
  /// 1. caller-supplied display name (page title from the browser
  ///    extension) — stripped of a trailing playlist/media extension
  ///    and sanitized;
  /// 2. the stem of the ORIGINAL playlist URL (not the resolved
  ///    variant/media URL, whose name is often meaningless, e.g.
  ///    `prog_index`).
  String _resolveBaseName(String? displayName, {required Uri originalUri}) {
    var stem = (displayName ?? '').trim();
    stem = stem.replaceFirst(
        RegExp(r'\.(m3u8?|ts|mp4)$', caseSensitive: false), '');
    stem = sanitizeFileName(stem);
    if (stem.isNotEmpty) return stem;
    return baseNameForHlsUrl(originalUri);
  }

  Future<void> _enqueueSegments(
    HlsJob job,
    List<String> headers,
    String? referer,
  ) async {
    const batchSize = 50;
    const batchDelay = Duration(milliseconds: 200);
    final repo = _ref.read(downloadsRepositoryProvider);
    // Download units in merge order: the fMP4 init segment (when
    // present) is unit 0, then the media segments. Unit i is saved as
    // `<i padded to 5>.ts` so the merge can replay the order.
    final items = <Uri>[
      if (job.mapUri != null) job.mapUri!,
      for (final s in job.segments) s.uri,
    ];
    for (var i = 0; i < items.length; i += batchSize) {
      if (_isCancelled(job.id)) throw const HlsCancelled();
      final end = (i + batchSize).clamp(0, items.length).toInt();
      for (var j = i; j < end; j++) {
        final outName = j.toString().padLeft(5, '0');
        final options = <String, Object?>{
          'dir': job.workingDir,
          'out': '$outName.ts',
          // String per aria2 RPC convention — int values are dropped
          // silently (see velocita memory note).
          'max-connection-per-server': '4',
          if (headers.isNotEmpty) 'header': headers,
          if (referer != null && referer.isNotEmpty) 'referer': referer,
        };
        try {
          final gid = await repo.addUri(
            items[j].toString(),
            saveDir: job.workingDir,
            aria2Options: options,
          );
          job.segmentGids.add(gid);
        } catch (e) {
          throw HlsMergerException(
              'failed to enqueue item ${j + 1}/${items.length}: $e');
        }
      }
      if (end < items.length) {
        await Future.delayed(batchDelay);
      }
    }
  }

  /// Poll every segment gid and roll the progress up into the
  /// synthetic table row. Throws on the first permanently-failed
  /// segment (the whole job is atomic from the user's perspective).
  Future<void> _pollUntilDone(HlsJob job) async {
    final repo = _ref.read(downloadsRepositoryProvider);
    while (true) {
      if (_isCancelled(job.id)) throw const HlsCancelled();
      await Future.delayed(const Duration(seconds: 2));
      final results = await Future.wait(
        job.segmentGids
            .map((g) async => (g, await repo.tellStatusRaw(g)))
            .toList(),
      );
      var doneCount = 0;
      var totalBytes = 0;
      var doneBytes = 0;
      var speedSum = 0;
      for (final (gid, status) in results) {
        if (status == null) continue;
        final s = status['status'] as String?;
        if (s == 'error' || s == 'removed') {
          final code = status['errorCode'] as String?;
          throw HlsMergerException(
              'segment failed${code != null ? ' ($code)' : ''}: $gid');
        }
        totalBytes += int.tryParse('${status['totalLength'] ?? 0}') ?? 0;
        doneBytes += int.tryParse('${status['completedLength'] ?? 0}') ?? 0;
        speedSum += int.tryParse('${status['downloadSpeed'] ?? 0}') ?? 0;
        if (s == 'complete') doneCount++;
      }
      _upsertRow(
        job,
        status: DownloadStatus.active,
        totalBytes: totalBytes,
        doneBytes: doneBytes,
        speed: speedSum,
      );
      if (doneCount == job.segmentGids.length && job.segmentGids.isNotEmpty) {
        return;
      }
    }
  }

  Future<void> _merge(HlsJob job) async {
    final outputFile = File('${job.saveDir}\\${job.outputFileName}');
    final segmentFiles = [
      for (var i = 0; i < job.segmentGids.length; i++)
        File('${job.workingDir}\\${i.toString().padLeft(5, '0')}.ts'),
    ];
    await mergeSegments(segmentFiles: segmentFiles, outputFile: outputFile);
  }

  /// Sanity-check the merged container: an fMP4 output must start
  /// with an `ftyp` box, an MPEG-TS output with the 0x47 sync byte.
  /// Catches concat-order / wrong-stream bugs early instead of
  /// leaving the user with a silently unplayable file.
  Future<int> _verifyMergedOutput(HlsJob job) async {
    final outputFile = File('${job.saveDir}\\${job.outputFileName}');
    final size = await outputFile.length();
    if (size < 12) {
      throw HlsMergerException('merged file is too small (${size}B)');
    }
    final raf = await outputFile.open();
    try {
      final header = await raf.read(12);
      if (job.mapUri != null) {
        final brand = String.fromCharCodes(header.sublist(4, 8));
        if (brand != 'ftyp') {
          throw HlsMergerException(
              'merged fMP4 is missing its ftyp box (got "$brand")');
        }
      } else {
        if (header[0] != 0x47) {
          throw HlsMergerException(
              'merged MPEG-TS is missing the 0x47 sync byte');
        }
      }
    } finally {
      await raf.close();
    }
    return size;
  }

  Future<void> _cleanupSegments(HlsJob job) async {
    final repo = _ref.read(downloadsRepositoryProvider);
    for (final gid in job.segmentGids) {
      try {
        await repo.remove(gid, force: true);
      } catch (_) {}
    }
    // Force the notifier to re-pull aria2 state so the gone segment
    // gids disappear from the table.
    try {
      await _ref.read(taskListProvider.notifier).refresh();
    } catch (_) {}
  }

  Future<void> _forceRemoveAll(HlsJob job) async {
    final repo = _ref.read(downloadsRepositoryProvider);
    for (final gid in job.segmentGids) {
      try {
        await repo.remove(gid, force: true);
      } catch (_) {}
    }
    try {
      await _ref.read(taskListProvider.notifier).refresh();
    } catch (_) {}
  }

  // ── synthetic row ───────────────────────────────────────────

  void _upsertRow(
    HlsJob job, {
    required DownloadStatus status,
    int totalBytes = 0,
    int doneBytes = 0,
    int speed = 0,
    Set<String> ownedGids = const {},
    String? errorMessage,
  }) {
    try {
      _ref.read(taskListProvider.notifier).upsertHlsJob(
            syntheticGid: job.id,
            jobId: job.id,
            ownedGids: ownedGids.isEmpty ? job.segmentGids.toSet() : ownedGids,
            row: TaskSummary(
              gid: job.id,
              filename: job.outputFileName,
              totalLength: totalBytes,
              completedLength: doneBytes,
              status: status,
              downloadSpeed: speed,
              dir: job.saveDir,
              errorMessage: errorMessage,
              addedAt: job.addedAt,
              // Stash the playlist URL so the right-click "Copy link"
              // entry can offer it back to the user.
              sourceUrl: job.url,
            ),
          );
    } catch (_) {
      // Notifier not ready (e.g. startup race) — the next poll tick
      // re-upserts.
    }
  }

  Future<void> _enterHlsMode() async {
    _hlsModeRefCount++;
    if (_hlsModeRefCount > 1) return;
    final repo = _ref.read(downloadsRepositoryProvider);
    try {
      final cur = await repo.getGlobalOption(['max-concurrent-downloads']);
      final original = cur['max-concurrent-downloads']?.toString() ?? '5';
      _savedMaxConcurrent = original;
    } catch (_) {
      _savedMaxConcurrent = '5';
    }
    try {
      await repo.changeGlobalOption({'max-concurrent-downloads': '16'});
      _log.info('aria2 max-concurrent-downloads 5→16 (HLS mode)');
    } catch (e) {
      _log.warning('failed to bump max-concurrent-downloads: $e');
    }
  }

  Future<void> _exitHlsMode() async {
    if (_hlsModeRefCount <= 0) return;
    _hlsModeRefCount--;
    if (_hlsModeRefCount > 0) return;
    final repo = _ref.read(downloadsRepositoryProvider);
    final restore = _savedMaxConcurrent ?? '5';
    try {
      await repo.changeGlobalOption({'max-concurrent-downloads': restore});
      _log.info('aria2 max-concurrent-downloads restored to $restore');
    } catch (e) {
      _log.warning('failed to restore max-concurrent-downloads: $e');
    }
    _savedMaxConcurrent = null;
  }

  // ── helpers ────────────────────────────────────────────────

  String _proxyUrl() {
    try {
      return _ref.read(kernelProvider).proxyUrl ?? '';
    } catch (_) {
      return '';
    }
  }

  void _emit(HlsEvent event) {
    _log.info('event ${event.success ? 'ok' : 'fail'} ${event.jobId}'
        '${event.message != null ? ' ${event.message}' : ''}'
        '${event.mergedFilePath != null ? ' ${event.mergedFilePath}' : ''}');
    _ref.read(hlsEventsProvider.notifier).state = event;
  }

  String _mintJobId() {
    final t = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final r = Random.secure()
        .nextInt(1 << 32)
        .toRadixString(16)
        .padLeft(8, '0');
    return 'hls-$t-$r';
  }

  List<String> _extractRawHeaders(Map<String, Object?>? opts) {
    if (opts == null) return const [];
    final raw = opts['header'];
    if (raw is List) {
      return [for (final e in raw) e.toString()];
    }
    return const [];
  }

  String? _extractReferer(Map<String, Object?>? opts) {
    if (opts == null) return null;
    final r = opts['referer'];
    if (r is String && r.isNotEmpty) return r;
    return null;
  }

  Future<void> _safeDelete(Directory d) async {
    try {
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
  }
}
