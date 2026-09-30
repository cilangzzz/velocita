import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/downloads_repository.dart';
import '../domain/download_task.dart';

/// The single source of truth for the downloads list in M5.
///
/// Backed by:
///   - a periodic `tellActive` poll (5s)
///   - a periodic `tellStopped` poll (5s) for completed/error history
///   - per-task `tellStatus` after add/pause/resume mutations
///   - JSON file persistence under the app's support dir
final taskListProvider =
    AsyncNotifierProvider<TaskListNotifier, Map<String, TaskSummary>>(
  TaskListNotifier.new,
);

class TaskListNotifier extends AsyncNotifier<Map<String, TaskSummary>> {
  Timer? _poll;
  static const _pollInterval = Duration(seconds: 5);
  late File _historyFile;

  @override
  Future<Map<String, TaskSummary>> build() async {
    final repo = ref.read(downloadsRepositoryProvider);
    final dir = await getApplicationSupportDirectory();
    _historyFile = File('${dir.path}/velocita/history.json');
    await _historyFile.parent.create(recursive: true);

    // Load persisted history first.
    final persisted = await _loadHistory();

    // Then refresh from aria2.
    final active = await repo.activeTasks();
    final stopped = await repo.stoppedTasks();
    final map = <String, TaskSummary>{
      for (final t in active) t.gid: t,
      for (final t in stopped) t.gid: t,
      for (final t in persisted.values) t.gid: t,
    };

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
      // Preserve any history records that aria2 has not yet surfaced
      // (still in the persistence file).
      for (final entry in current.entries) {
        if (!liveGids.contains(entry.key)) {
          next[entry.key] = entry.value;
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
    await repo.addUri(url, saveDir: saveDir);
    await refresh();
  }

  Future<void> addMagnet(String magnet, {String? saveDir}) async {
    final repo = ref.read(downloadsRepositoryProvider);
    await repo.addMagnet(magnet, saveDir: saveDir);
    await refresh();
  }

  Future<void> addTorrent(List<int> bytes, {String? saveDir}) async {
    final repo = ref.read(downloadsRepositoryProvider);
    await repo.addTorrent(bytes, saveDir: saveDir);
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
    state = AsyncData(current);
    await _persist();
  }

  Future<void> refresh() => _refresh();

  Future<void> _refreshOne(String gid) async {
    final repo = ref.read(downloadsRepositoryProvider);
    final updated = await repo.oneTask(gid);
    if (updated == null) return;
    final current = Map<String, TaskSummary>.from(state.value ?? const {});
    current[gid] = updated;
    state = AsyncData(current);
    await _persist();
  }
}
