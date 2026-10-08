import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:velocita_kernel/velocita_kernel.dart';

import '../domain/download_task.dart';

/// Repository — the only place that talks to the kernel RPC client.
///
/// Per `docs/rule/flutter_rule/04-state-management.md` §"Repository pattern",
/// the repository is a `Provider` exposing async methods; providers
/// downstream depend on its methods, not on the raw RPC client.
final downloadsRepositoryProvider = Provider<DownloadsRepository>((ref) {
  throw UnimplementedError(
    'downloadsRepositoryProvider was read before bootstrapKernel() finished.',
  );
});

class DownloadsRepository {
  DownloadsRepository(this._rpc, {this.defaultSaveDir});

  /// A directory to use when no other resolver applies (e.g. when no
  /// category matches). Kept as a final field so the repo can be moved
  /// without touching the kernel.
  final String? defaultSaveDir;
  final Aria2RpcClient _rpc;

  /// Add a download and return its gid.
  ///
  /// [saveDir] defaults to the category-resolved directory if `null`
  /// (the caller is expected to have classified already).
  Future<String> addUri(String url, {String? saveDir}) async {
    final dir = saveDir ?? defaultSaveDir;
    final gid = await _rpc.addUri([url], options: dir == null ? null : {'dir': dir});
    return gid;
  }

  /// Add a magnet URI — aria2 fetches metadata and starts the download.
  Future<String> addMagnet(String magnet, {String? saveDir}) async {
    final dir = saveDir ?? defaultSaveDir;
    final gid = await _rpc.addMagnet(magnet, options: dir == null ? null : {'dir': dir});
    return gid;
  }

  /// Add a torrent file (already read into bytes).
  Future<String> addTorrent(List<int> bytes, {String? saveDir}) async {
    final dir = saveDir ?? defaultSaveDir;
    final gid = await _rpc.addTorrent(bytes, options: dir == null ? null : {'dir': dir});
    return gid;
  }

  /// Pause a task.
  Future<void> pause(String gid) async => _rpc.pause(gid);

  /// Resume a paused task.
  Future<void> resume(String gid) async => _rpc.unpause(gid);

  /// Remove a task from aria2's tracking. Files on disk are untouched.
  Future<void> remove(String gid, {bool force = false}) =>
      _rpc.remove(gid, force: force);

  /// Snapshot all active tasks.
  Future<List<TaskSummary>> activeTasks() async {
    final raws = await _rpc.tellActive();
    return raws.map(taskFromAria2).toList(growable: false);
  }

  /// Snapshot completed/error tasks (aria2's `tellStopped`).
  /// offset/num paginate; we ask for a large slice since the engine caps
  /// `--max-download-result` at 1000 by default.
  Future<List<TaskSummary>> stoppedTasks({
    int offset = 0,
    int num = 1000,
  }) async {
    final raws = await _rpc.tellStopped(offset, num);
    return raws.map(taskFromAria2).toList(growable: false);
  }

  /// Snapshot a single task.
  Future<TaskSummary?> oneTask(String gid) async {
    final raw = await _rpc.tellStatus(gid);
    return taskFromAria2(raw);
  }

  /// Read engine-wide options. The keys are aria2's native option names
  /// (e.g. `dir`, `max-concurrent-downloads`, `max-overall-download-limit`).
  Future<Map<String, Object?>> getGlobalOption(List<String> keys) =>
      _rpc.getGlobalOption(keys);

  /// Patch engine-wide options. Values are coerced to the aria2-expected
  /// types by the engine itself (e.g. `int` for `max-concurrent-downloads`).
  Future<void> changeGlobalOption(Map<String, Object?> options) =>
      _rpc.changeGlobalOption(options);
}
