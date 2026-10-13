import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/hls/hls.dart';
import '../../../kernel_bridge/kernel_provider.dart';
import '../../../persistence/database.dart' show DownloadRow, DownloadsDao;
import '../../../persistence/defaults.dart';
import '../data/downloads_repository.dart';
import '../domain/download_task.dart';

/// Status filter applied to the visible task list (toolbar dropdown).
enum DownloadFilter { all, active, paused, completed, error }

/// Filter state — UI-only, lives here next to the task list it filters.
final taskFilterProvider =
    StateProvider<DownloadFilter>((ref) => DownloadFilter.all);

/// The single source of truth for the downloads list in M5.
///
/// Backed by:
///   - a periodic `tellActive` poll (5s)
///   - a periodic `tellStopped` poll (5s) for completed/error history
///   - per-task `tellStatus` after add/pause/resume mutations
///   - JSON file persistence under the app's support dir
///   - local `addedAt` / `completedAt` tracking (aria2 1.37.0 does not
///     return these fields in `tellStatus`)
final taskListProvider =
    AsyncNotifierProvider<TaskListNotifier, Map<String, TaskSummary>>(
  TaskListNotifier.new,
);

class TaskListNotifier extends AsyncNotifier<Map<String, TaskSummary>> {
  Timer? _poll;
  static const _pollInterval = Duration(seconds: 5);
  late final DownloadsDao _dao;

  /// Local timestamps we track ourselves because aria2 1.37.0 does not
  /// surface `addedAt`/`completedAt` through `tellStatus`. Keys are gid.
  final Map<String, DateTime> _addedAt = {};
  final Map<String, DateTime> _completedAt = {};

  // ── HLS synthetic rows ────────────────────────────────────────
  // An HLS job is ONE user-visible row backed by N real aria2 segment
  // gids that must never appear in the table. The synthetic row lives
  // only in memory (not persisted); the merged file on disk is the
  // durable artifact.

  /// Synthetic HLS job rows by synthetic gid (prefix `hls-`).
  final Map<String, TaskSummary> _synthetic = {};

  /// Real aria2 gids owned by each HLS job, by job id — hidden from
  /// the table and excluded from history persistence. The set is
  /// REPLACED on every upsert, so passing an empty set on completion
  /// unhides the (by-then-removed) gids.
  final Map<String, Set<String>> _hlsJobGids = {};

  /// Synthetic gid → HLS job id, so removing the row from the table
  /// can cancel the underlying job.
  final Map<String, String> _syntheticJobIds = {};

  /// Insert or update the synthetic row for an HLS job and replace
  /// the set of aria2 segment gids it owns (those gids are hidden
  /// from the table and excluded from history persistence).
  void upsertHlsJob({
    required String syntheticGid,
    required String jobId,
    required TaskSummary row,
    Set<String> ownedGids = const {},
  }) {
    _synthetic[syntheticGid] = row;
    _syntheticJobIds[syntheticGid] = jobId;
    _hlsJobGids[jobId] = Set.of(ownedGids);
    _pushWithSynthetic();
  }

  /// True if [gid] is an HLS synthetic row (not a real aria2 task).
  static bool isHlsSyntheticGid(String gid) => gid.startsWith('hls-');

  void _pushWithSynthetic() {
    final current = Map<String, TaskSummary>.from(state.value ?? const {});
    for (final gids in _hlsJobGids.values) {
      for (final gid in gids) {
        current.remove(gid);
      }
    }
    current.addAll(_synthetic);
    state = AsyncData(current);
  }

  @override
  Future<Map<String, TaskSummary>> build() async {
    _dao = ref.read(appDatabaseProvider).downloadsDao;
    final repo = ref.read(downloadsRepositoryProvider);

    // Hydrate from the DB first. The 5s poll will merge aria2's
    // live state on top of this; tasks that just transitioned
    // to complete/error/removed are already here, so we never
    // show a "lost" entry after a restart.
    final persistedRows = await _dao.all();
    final persisted = {
      for (final r in persistedRows) r.gid: taskSummaryFromRow(r),
    };
    for (final r in persistedRows) {
      if (r.addedAt != null) _addedAt[r.gid] = r.addedAt!;
      if (r.completedAt != null) _completedAt[r.gid] = r.completedAt!;
    }

    // Bring aria2's live state in.
    final active = await repo.activeTasks();
    final stopped = await repo.stoppedTasks();
    final liveGids = <String>{
      for (final t in active) t.gid,
      for (final t in stopped) t.gid,
    };
    for (final t in active) {
      final merged = _mergeAria2(t, persisted[t.gid]);
      persisted[t.gid] = merged;
      _addedAt.putIfAbsent(t.gid, () => merged.addedAt ?? DateTime.now());
    }
    for (final t in stopped) {
      final merged = _mergeAria2(t, persisted[t.gid]);
      persisted[t.gid] = merged;
      if (merged.isComplete && _completedAt[t.gid] == null) {
        _completedAt[t.gid] = DateTime.now();
      }
    }
    // The DB has rows that aria2 has forgotten (pruned from
    // tellStopped). They stay in the table.
    // Replace any persisted state we don't trust with the
    // live-or-persisted merged value above.
    for (final entry in persisted.entries.toList()) {
      if (!liveGids.contains(entry.key)) {
        // keep the persisted one as-is
      }
    }

    _poll?.cancel();
    _poll = Timer.periodic(_pollInterval, (_) => _refresh());

    ref.onDispose(() {
      _poll?.cancel();
    });

    return persisted;
  }

  /// Merge an aria2 snapshot with the row we may have pre-filled
  /// at add time. Keeps the pre-filled filename when aria2's
  /// response didn't carry a path (common for tasks that errored
  /// instantly), and keeps the pre-filled source URL since aria2
  /// never reports the original URL back through `tellStatus`.
  TaskSummary _mergeAria2(TaskSummary aria2, TaskSummary? existing) {
    if (existing == null) return aria2;
    final keepFilename = aria2.filename.isEmpty && existing.filename.isNotEmpty;
    final keepSource = aria2.sourceUrl == null && existing.sourceUrl != null;
    if (!keepFilename && !keepSource) return aria2;
    return aria2.copyWith(
      filename: keepFilename ? existing.filename : null,
      sourceUrl: keepSource ? existing.sourceUrl : null,
    );
  }

  /// Push a freshly-derived snapshot into the table for [gid]
  /// BEFORE aria2 has had a chance to report back. Keeps the
  /// "(unnamed)" failure mode out of the UI.
  void _prefill(TaskSummary snapshot) {
    final current = Map<String, TaskSummary>.from(state.value ?? const {});
    current[snapshot.gid] = snapshot;
    state = AsyncData(current);
  }

  /// Refresh: ask aria2 for both `tellActive` and `tellStopped`,
  /// merge with the in-memory map (preserving any tasks aria2 has
  /// forgotten), and write a single batched upsert to the DB for
  /// everything that changed.
  Future<void> _refresh() async {
    final repo = ref.read(downloadsRepositoryProvider);
    try {
      final active = await repo.activeTasks();
      final stopped = await repo.stoppedTasks();
      final liveGids = <String>{
        for (final t in active) t.gid,
        for (final t in stopped) t.gid,
      };
      final current = state.value ?? const <String, TaskSummary>{};
      final next = <String, TaskSummary>{};
      for (final t in active) {
        next[t.gid] = _mergeAria2(t, current[t.gid]);
      }
      for (final t in stopped) {
        next[t.gid] = _mergeAria2(t, current[t.gid]);
      }
      for (final entry in current.entries) {
        if (!liveGids.contains(entry.key)) {
          next[entry.key] = entry.value;
        }
      }
      // Stamp completion times for tasks that just transitioned.
      for (final t in stopped) {
        if (!_completedAt.containsKey(t.gid) && t.isComplete) {
          _completedAt[t.gid] = DateTime.now();
        }
      }
      for (final t in active) {
        _addedAt.putIfAbsent(t.gid, () => DateTime.now());
      }
      // Re-apply local time stamps to the snapshots so the UI sees them.
      for (final t in next.values) {
        final added = _addedAt[t.gid];
        final completed = _completedAt[t.gid];
        if (added != null || completed != null) {
          next[t.gid] = t.copyWith(
            addedAt: added ?? t.addedAt,
            completedAt: completed ?? t.completedAt,
          );
        }
      }
      // Hide HLS-owned segment gids and surface the synthetic rows.
      for (final gids in _hlsJobGids.values) {
        for (final gid in gids) {
          next.remove(gid);
        }
      }
      next.addAll(_synthetic);
      state = AsyncData(next);

      // Persist everything except HLS-managed gids (segments) and
      // synthetic rows (memory-only) in a single batched transaction.
      final persistable = <DownloadRow>[
        for (final t in next.values)
          if (!TaskListNotifier.isHlsSyntheticGid(t.gid) &&
              !_isHlsSegment(t.gid))
            downloadRowFromSummary(t),
      ];
      await _dao.upsertBatch(persistable);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  bool _isHlsSegment(String gid) {
    for (final owned in _hlsJobGids.values) {
      if (owned.contains(gid)) return true;
    }
    return false;
  }

  Future<void> addUri(
    String url, {
    String? saveDir,
    Map<String, Object?>? aria2Options,
    String? displayName,
  }) async {
    // HLS playlists need special handling: aria2 doesn't understand
    // .m3u8, so route to the in-app HLS downloader which fetches the
    // playlist, parses it, and enqueues each segment as a regular
    // aria2 task under the hood.
    if (isM3u8(url)) {
      await ref.read(hlsDownloaderProvider).start(
            url: url,
            saveDir: saveDir ?? ref.read(downloadsRepositoryProvider).defaultSaveDir ?? '',
            aria2Options: aria2Options,
            displayName: displayName,
          );
      return;
    }
    final repo = ref.read(downloadsRepositoryProvider);
    final gid = await repo.addUri(
      url,
      saveDir: saveDir,
      aria2Options: aria2Options,
    );
    // Stamp local "added" time immediately.
    _addedAt[gid] = DateTime.now();
    // Pre-fill the row with a meaningful filename + source URL
    // *before* aria2 reports back. The table is then responsive on
    // add and a download that fails in the first millisecond shows
    // a recognisable name instead of "(unnamed)".
    _prefill(TaskSummary(
      gid: gid,
      filename: _deriveUrlFilename(
        url: url,
        aria2Options: aria2Options,
        displayName: displayName,
      ),
      totalLength: 0,
      completedLength: 0,
      status: DownloadStatus.waiting,
      downloadSpeed: 0,
      dir: saveDir ?? repo.defaultSaveDir ?? '',
      sourceUrl: url,
    ));
    // Probe the new task directly so the row updates immediately
    // (aria2's `tellActive` poll may not include the task for a few
    // hundred ms after `addUri` returns).
    await _refreshOne(gid);
    await refresh();
  }

  Future<void> addMagnet(
    String magnet, {
    String? saveDir,
    Map<String, Object?>? aria2Options,
    String? displayName,
  }) async {
    final repo = ref.read(downloadsRepositoryProvider);
    final gid = await repo.addMagnet(
      magnet,
      saveDir: saveDir,
      aria2Options: aria2Options,
    );
    _addedAt[gid] = DateTime.now();
    _prefill(TaskSummary(
      gid: gid,
      filename: _deriveMagnetFilename(magnet, displayName: displayName),
      totalLength: 0,
      completedLength: 0,
      status: DownloadStatus.waiting,
      downloadSpeed: 0,
      dir: saveDir ?? repo.defaultSaveDir ?? '',
      sourceUrl: magnet,
    ));
    await _refreshOne(gid);
    await refresh();
  }

  Future<void> addTorrent(
    List<int> bytes, {
    String? saveDir,
    Map<String, Object?>? aria2Options,
  }) async {
    final repo = ref.read(downloadsRepositoryProvider);
    final gid = await repo.addTorrent(
      bytes,
      saveDir: saveDir,
      aria2Options: aria2Options,
    );
    _addedAt[gid] = DateTime.now();
    await _refreshOne(gid);
    await refresh();
  }

  Future<void> pause(String gid) async {
    // Synthetic HLS rows have no aria2 gid to pause; the job-level
    // cancel lives in removeFromHistory.
    if (TaskListNotifier.isHlsSyntheticGid(gid)) return;
    final repo = ref.read(downloadsRepositoryProvider);
    await repo.pause(gid);
    await _refreshOne(gid);
  }

  Future<void> resume(String gid) async {
    if (TaskListNotifier.isHlsSyntheticGid(gid)) return;
    final repo = ref.read(downloadsRepositoryProvider);
    await repo.resume(gid);
    await _refreshOne(gid);
  }

  /// Remove from aria2 tracking. Files on disk are untouched — the
  /// record stays in the history list until the user explicitly
  /// removes it.
  Future<void> remove(String gid) async {
    final repo = ref.read(downloadsRepositoryProvider);
    await repo.remove(gid);
    await _refresh();
  }

  /// Remove the record from the history list (no aria2 round-trip,
  /// no disk changes). This is what the UI's trash icon calls.
  ///
  /// Removing a synthetic HLS row cancels the underlying job
  /// (stops polling, force-removes its segments, deletes the work
  /// dir) and is memory-only — synthetic rows aren't persisted.
  Future<void> removeFromHistory(String gid) async {
    if (_synthetic.containsKey(gid)) {
      final jobId = _syntheticJobIds[gid];
      _synthetic.remove(gid);
      _syntheticJobIds.remove(gid);
      if (jobId != null) _hlsJobGids.remove(jobId);
      state = AsyncData(
          Map<String, TaskSummary>.from(state.value ?? const {}));
      if (jobId != null) {
        try {
          await ref.read(hlsDownloaderProvider).cancel(jobId);
        } catch (_) {}
      }
      return;
    }
    final current = Map<String, TaskSummary>.from(state.value ?? const {});
    current.remove(gid);
    _addedAt.remove(gid);
    _completedAt.remove(gid);
    state = AsyncData(current);
    await _dao.deleteByGid(gid);
  }

  Future<void> refresh() => _refresh();

  Future<void> _refreshOne(String gid) async {
    final repo = ref.read(downloadsRepositoryProvider);
    final updated = await repo.oneTask(gid);
    if (updated == null) return;
    // If we just observed completion, stamp the wall clock.
    if (updated.isComplete && !_completedAt.containsKey(gid)) {
      _completedAt[gid] = DateTime.now();
    }
    final added = _addedAt[gid];
    final completed = _completedAt[gid];
    final preserved = _mergeAria2(updated, state.value?[gid]);
    final merged = (added != null || completed != null)
        ? preserved.copyWith(
            addedAt: added ?? preserved.addedAt,
            completedAt: completed ?? preserved.completedAt,
          )
        : preserved;
    final current = Map<String, TaskSummary>.from(state.value ?? const {});
    current[gid] = merged;
    state = AsyncData(current);
    // Persist immediately when the task just transitioned to a
    // terminal state, so a crash doesn't lose the entry. Active
    // tasks are flushed on the next 5s batch.
    if (merged.isComplete || merged.isError) {
      await _dao.upsertOne(downloadRowFromSummary(merged));
    }
  }
}

// ── Filename derivation helpers ─────────────────────────────────
//
// Used at add time to seed the table row with a meaningful name
// *before* aria2 reports back. Resolution order for URLs:
//   1. `aria2Options['out']` — the most explicit, used by the
//      browser-extension path to set the on-disk filename directly
//   2. `displayName` — the caller's preferred name (tab title, etc.)
//   3. URL basename (with query/fragment stripped and percent-escapes
//      decoded)
// For magnets, fall back through `displayName` → magnet `dn=`
// query param → first 8 chars of the v1 info-hash → a generic stub.

String _deriveUrlFilename({
  required String url,
  Map<String, Object?>? aria2Options,
  String? displayName,
}) {
  if (aria2Options != null) {
    final out = aria2Options['out'];
    if (out is String) {
      final clean = out.replaceAll(RegExp(r'[\\/]'), '').trim();
      if (clean.isNotEmpty) return clean;
    }
  }
  final dn = displayName?.trim();
  if (dn != null && dn.isNotEmpty) {
    final clean = dn.replaceAll(RegExp(r'[\\/]'), '').trim();
    if (clean.isNotEmpty) return clean;
  }
  return _basenameFromUrl(url);
}

String _deriveMagnetFilename(String magnet, {String? displayName}) {
  final dn = displayName?.trim();
  if (dn != null && dn.isNotEmpty) {
    final clean = _sanitizeFilename(dn);
    if (clean.isNotEmpty) return clean;
  }
  try {
    final uri = Uri.parse(magnet);
    final m = uri.queryParameters['dn'];
    if (m != null && m.trim().isNotEmpty) {
      final clean = _sanitizeFilename(m);
      if (clean.isNotEmpty) return clean;
    }
    final xt = uri.queryParameters['xt'];
    if (xt != null && xt.startsWith('urn:btih:')) {
      final h = xt.substring('urn:btih:'.length);
      if (h.length >= 8) return 'magnet_${h.substring(0, 8)}';
    }
  } catch (_) {}
  return 'magnet_download';
}

/// Last path component of [url], with query/fragment stripped and
/// percent-escapes decoded. Windows-illegal characters are replaced
/// with `_` so the filename is always safe to pass to aria2 as `out`.
String _basenameFromUrl(String url) {
  var u = url;
  final q = u.indexOf('?');
  if (q >= 0) u = u.substring(0, q);
  final h = u.indexOf('#');
  if (h >= 0) u = u.substring(0, h);
  var i = u.length - 1;
  while (i >= 0 && u[i] != '/' && u[i] != '\\') {
    i--;
  }
  var base = i < 0 ? u : u.substring(i + 1);
  if (base.isEmpty) return 'download';
  try {
    base = Uri.decodeComponent(base);
  } catch (_) {}
  base = _sanitizeFilename(base);
  return base.isEmpty ? 'download' : base;
}

String _sanitizeFilename(String name) {
  // Windows-illegal characters + control chars. Forward slashes and
  // backslashes are deliberately included so a stray URL path
  // component can never produce a name like "a/b" and aria2 can't
  // be tricked into writing outside `dir`.
  final cleaned = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_').trim();
  return cleaned;
}
