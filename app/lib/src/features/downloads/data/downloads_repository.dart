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
  DownloadsRepository(this._rpc);

  final Aria2RpcClient _rpc;

  /// Add a download and return its gid.
  Future<String> addUri(String url) async {
    final gid = await _rpc.addUri([url]);
    return gid;
  }

  /// Add a magnet URI — aria2 fetches metadata and starts the download.
  Future<String> addMagnet(String magnet) async {
    final gid = await _rpc.addMagnet(magnet);
    return gid;
  }

  /// Add a torrent file (already read into bytes).
  Future<String> addTorrent(List<int> bytes) async {
    final gid = await _rpc.addTorrent(bytes);
    return gid;
  }

  /// Pause a task.
  Future<void> pause(String gid) async => _rpc.pause(gid);

  /// Resume a paused task.
  Future<void> resume(String gid) async => _rpc.unpause(gid);

  /// Remove a task (preserves files by default).
  Future<void> remove(String gid, {bool force = false}) =>
      _rpc.remove(gid, force: force);

  /// Snapshot all active tasks.
  Future<List<TaskSummary>> activeTasks() async {
    final raws = await _rpc.tellActive();
    return raws.map(taskFromAria2).toList(growable: false);
  }

  /// Snapshot a single task.
  Future<TaskSummary?> oneTask(String gid) async {
    final raw = await _rpc.tellStatus(gid);
    return taskFromAria2(raw);
  }
}
