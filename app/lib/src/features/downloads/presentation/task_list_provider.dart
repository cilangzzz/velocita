import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/downloads_repository.dart';
import '../domain/download_task.dart';

/// The single source of truth for the downloads list in M2.
///
/// Backed by:
///   - a periodic `tellActive` poll (5s)
///   - per-task `tellStatus` after add/pause/resume/remove mutations
///
/// Per `docs/rule/flutter_rule/06-performance.md`:
///   - source throttle: poll at 5s, not 1s, in M2
///   - boundary coalesce: tasks are uniquely keyed by gid; we never emit two
///     updates for the same gid in the same microtask burst
///   - consumer select: consumers below should `select((t) => t[id])` rather
///     than read the whole map
final taskListProvider =
    AsyncNotifierProvider<TaskListNotifier, Map<String, TaskSummary>>(
  TaskListNotifier.new,
);

class TaskListNotifier extends AsyncNotifier<Map<String, TaskSummary>> {
  Timer? _poll;
  static const _pollInterval = Duration(seconds: 5);

  @override
  Future<Map<String, TaskSummary>> build() async {
    final repo = ref.read(downloadsRepositoryProvider);
    // First snapshot.
    final initial = await repo.activeTasks();
    final map = {for (final t in initial) t.gid: t};

    // Subscribe: poll + manual refresh.
    _poll?.cancel();
    _poll = Timer.periodic(_pollInterval, (_) => _refresh());

    ref.onDispose(() {
      _poll?.cancel();
    });

    return map;
  }

  Future<void> _refresh() async {
    final repo = ref.read(downloadsRepositoryProvider);
    try {
      final tasks = await repo.activeTasks();
      final current = state.value ?? const {};
      final next = <String, TaskSummary>{
        for (final t in tasks) t.gid: t,
      };
      // Keep completed/error/paused tasks that are no longer active.
      for (final entry in current.entries) {
        if (entry.value.isComplete ||
            entry.value.isError ||
            entry.value.isPaused) {
          next[entry.key] = entry.value;
        }
      }
      state = AsyncData(next);
    } catch (e, st) {
      // Surface the error but keep the previous data on screen.
      state = AsyncError(e, st);
    }
  }

  /// Public API: add a new URI. Refreshes the list once the engine has
  /// picked it up.
  Future<void> addUri(String url) async {
    final repo = ref.read(downloadsRepositoryProvider);
    await repo.addUri(url);
    await refresh();
  }

  /// Add a magnet URI. aria2 fetches metadata; we refresh once to see the
  /// resulting `waiting` task.
  Future<void> addMagnet(String magnet) async {
    final repo = ref.read(downloadsRepositoryProvider);
    await repo.addMagnet(magnet);
    await refresh();
  }

  /// Add a torrent file.
  Future<void> addTorrent(List<int> bytes) async {
    final repo = ref.read(downloadsRepositoryProvider);
    await repo.addTorrent(bytes);
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

  Future<void> remove(String gid) async {
    final repo = ref.read(downloadsRepositoryProvider);
    await repo.remove(gid);
    final current = Map<String, TaskSummary>.from(state.value ?? const {});
    current.remove(gid);
    state = AsyncData(current);
  }

  /// Force a list refresh — used by the toolbar Refresh button.
  Future<void> refresh() => _refresh();

  Future<void> _refreshOne(String gid) async {
    final repo = ref.read(downloadsRepositoryProvider);
    final updated = await repo.oneTask(gid);
    if (updated == null) return;
    final current = Map<String, TaskSummary>.from(state.value ?? const {});
    current[gid] = updated;
    state = AsyncData(current);
  }
}
