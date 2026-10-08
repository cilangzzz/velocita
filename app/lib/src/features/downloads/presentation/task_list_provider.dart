import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

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
  late File _historyFile;

  /// Local timestamps we track ourselves because aria2 1.37.0 does not
  /// surface `addedAt`/`completedAt` through `tellStatus`. Keys are gid.
  final Map<String, DateTime> _addedAt = {};
  final Map<String, DateTime> _completedAt = {};

  @override
  Future<Map<String, TaskSummary>> build() async {
    final repo = ref.read(downloadsRepositoryProvider);
    final dir = await getApplicationSupportDirectory();
    _historyFile = File('${dir.path}/velocita/history.json');
    await _historyFile.parent.create(recursive: true);

    final persisted = await _loadHistory();

    final active = await repo.activeTasks();
    final stopped = await repo.stoppedTasks();
    final map = <String, TaskSummary>{
      for (final t in active) t.gid: t,
      for (final t in stopped) t.gid: t,
      for (final t in persisted.values) t.gid: t,
    };

    // Hydrate the local time maps from persisted records.
    for (final t in persisted.values) {
      if (t.addedAt != null) _addedAt[t.gid] = t.addedAt!;
      if (t.completedAt != null) _completedAt[t.gid] = t.completedAt!;
    }
    // For active tasks, aria2 doesn't tell us when they were added; if
    // we haven't recorded it, use the persisted value or "now".
    for (final t in active) {
      _addedAt.putIfAbsent(t.gid, () => t.addedAt ?? DateTime.now());
    }

    _poll?.cancel();
    _poll = Timer.periodic(_pollInterval, (_) => _refresh());

    ref.onDispose(() {
      _poll?.cancel();
    });

    return map;
  }

  Future<Map<String, TaskSummary>> _loadHistory() async {
    if (!await _historyFile.exists()) return {};
    try {
      final raw =
          jsonDecode(await _historyFile.readAsString()) as Map<String, dynamic>;
      final entries = (raw['tasks'] as List?) ?? const [];
      return {
        for (final e in entries.cast<Map<String, dynamic>>())
          (e['gid'] as String): TaskSummary(
            gid: e['gid'] as String,
            filename: e['filename'] as String,
            totalLength: e['totalLength'] as int? ?? 0,
            completedLength: e['completedLength'] as int? ?? 0,
            status: parseStatus(e['status'] as String? ?? 'unknown'),
            downloadSpeed: 0,
            dir: e['dir'] as String? ?? '',
            errorCode: e['errorCode'] as String?,
            errorMessage: e['errorMessage'] as String?,
            addedAt: e['addedAt'] != null
                ? DateTime.tryParse(e['addedAt'] as String)
                : null,
            completedAt: e['completedAt'] != null
                ? DateTime.tryParse(e['completedAt'] as String)
                : null,
          ),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _persist() async {
    final tasks = state.value ?? const <String, TaskSummary>{};
    final payload = {
      'tasks': tasks.values
          .map((t) => {
                'gid': t.gid,
                'filename': t.filename,
                'totalLength': t.totalLength,
                'completedLength': t.completedLength,
                'status': t.status.name,
                'dir': t.dir,
                'errorCode': t.errorCode,
                'errorMessage': t.errorMessage,
                'addedAt':
                    _addedAt[t.gid]?.toIso8601String() ?? t.addedAt?.toIso8601String(),
                'completedAt': _completedAt[t.gid]?.toIso8601String() ??
                    t.completedAt?.toIso8601String(),
                'savedAt': DateTime.now().toIso8601String(),
              })
          .toList(),
    };
    try {
      await _historyFile.writeAsString(jsonEncode(payload));
    } catch (_) {
      // Best-effort persistence; don't crash the app if the disk is full.
    }
  }

  /// Refresh: ask aria2 for both `tellActive` and `tellStopped`, merge with
  /// the in-memory map (preserving any tasks aria2 has forgotten).
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
      final next = <String, TaskSummary>{
        for (final t in active) t.gid: t,
        for (final t in stopped) t.gid: t,
      };
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
      // Stamp missing addedAt for active tasks (e.g. history restored but
      // we lost the local time map across a hot reload).
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
      state = AsyncData(next);
      await _persist();
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> addUri(String url, {String? saveDir}) async {
    final repo = ref.read(downloadsRepositoryProvider);
    final gid = await repo.addUri(url, saveDir: saveDir);
    // Stamp local "added" time immediately.
    _addedAt[gid] = DateTime.now();
    // Probe the new task directly so the row appears in the table
    // immediately (aria2's `tellActive` poll may not include the task
    // for a few hundred ms after `addUri` returns).
    await _refreshOne(gid);
    await refresh();
  }

  Future<void> addMagnet(String magnet, {String? saveDir}) async {
    final repo = ref.read(downloadsRepositoryProvider);
    final gid = await repo.addMagnet(magnet, saveDir: saveDir);
    _addedAt[gid] = DateTime.now();
    await _refreshOne(gid);
    await refresh();
  }

  Future<void> addTorrent(List<int> bytes, {String? saveDir}) async {
    final repo = ref.read(downloadsRepositoryProvider);
    final gid = await repo.addTorrent(bytes, saveDir: saveDir);
    _addedAt[gid] = DateTime.now();
    await _refreshOne(gid);
    await refresh();
  }

  Future<void> pause(String gid) async {
    final repo = ref.read(downloadsRepositoryProvider);
    await repo.pause(gid);
    await _refreshOne(gid);
  }

  Future<void> resume(String gid) async {
    final repo = ref.read(downloadsRepositoryProvider);
    await repo.resume(gid);
    await _refreshOne(gid);
  }

  /// Remove from aria2 tracking. Files on disk are untouched — the
  /// record stays in the history list until the user explicitly removes it.
  Future<void> remove(String gid) async {
    final repo = ref.read(downloadsRepositoryProvider);
    await repo.remove(gid);
    await _refresh();
  }

  /// Remove the record from the history list (no aria2 round-trip, no
  /// disk changes). This is what the UI's trash icon calls.
  Future<void> removeFromHistory(String gid) async {
    final current = Map<String, TaskSummary>.from(state.value ?? const {});
    current.remove(gid);
    _addedAt.remove(gid);
    _completedAt.remove(gid);
    state = AsyncData(current);
    await _persist();
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
    final merged = (added != null || completed != null)
        ? updated.copyWith(
            addedAt: added ?? updated.addedAt,
            completedAt: completed ?? updated.completedAt,
          )
        : updated;
    final current = Map<String, TaskSummary>.from(state.value ?? const {});
    current[gid] = merged;
    state = AsyncData(current);
    await _persist();
  }
}
