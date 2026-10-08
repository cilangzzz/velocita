/// Engine contract: what the kernel can ask the download engine to do.
///
/// `Aria2EngineAdapter` is the only implementation today. Future
/// implementations (HTTP-only fallback, mock for tests) live elsewhere.
abstract class EngineAdapter {
  /// Add a download. Returns the engine-assigned task identifier.
  Future<String> addUri(List<String> uris, {Map<String, Object?>? options});

  /// Pause a single task.
  Future<void> pause(String gid);

  /// Resume a paused task.
  Future<void> unpause(String gid);

  /// Remove a task from the engine (preserves files by default).
  Future<void> remove(String gid, {bool force = false});

  /// Query a single task's full status.
  Future<Map<String, Object?>> tellStatus(String gid);

  /// Query a single task's status with explicit keys (e.g. ['addedAt',
  /// 'completedAt']). aria2 includes those fields only when explicitly
  /// requested.
  Future<Map<String, Object?>> tellStatusWithKeys(
    String gid,
    List<String> keys,
  );

  /// List active (downloading) tasks.
  Future<List<Map<String, Object?>>> tellActive();

  /// Fetch the current value of one or more engine-wide options.
  /// Returns a map keyed by the requested option name.
  Future<Map<String, Object?>> getGlobalOption(List<String> keys);

  /// Patch a subset of engine-wide options. Aria2c returns a JSON `null`
  /// on success; any error surfaces as an `EngineFailure`.
  Future<void> changeGlobalOption(Map<String, Object?> options);

  /// Fetch engine version and enabled features.
  Future<EngineVersionInfo> getVersion();

  /// Shut the engine down. After this call no further methods may be invoked.
  Future<void> shutdown();
}

class EngineVersionInfo {
  const EngineVersionInfo({
    required this.version,
    required this.enabledFeatures,
  });

  final String version;
  final List<String> enabledFeatures;
}
