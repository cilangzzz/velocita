/// Domain value objects for the downloads feature.
///
/// Pure Dart, freezed-free for M2 simplicity. Per
/// `docs/rule/flutter_rule/03-domain-and-contracts.md` these types are
/// the public surface of the feature; every other file in this folder
/// depends on them.
library;

/// Filter applied to the list of tasks shown in the UI.
enum TaskFilter { all, active, paused, completed, error }

/// Combined snapshot of a download task for the list view.
class TaskSummary {
  const TaskSummary({
    required this.gid,
    required this.filename,
    required this.totalLength,
    required this.completedLength,
    required this.status,
    required this.downloadSpeed,
    required this.dir,
    this.errorCode,
    this.errorMessage,
    this.addedAt,
    this.completedAt,
    this.sourceUrl,
  });

  final String gid;
  final String filename;
  final int totalLength;
  final int completedLength;
  final DownloadStatus status;
  final int downloadSpeed;
  final String dir;
  final String? errorCode;
  final String? errorMessage;

  /// aria2 reports `addedAt` as epoch seconds. `null` when not yet known
  /// (e.g. a freshly added task before the first refresh).
  final DateTime? addedAt;

  /// aria2 reports `completedAt` as epoch seconds. `null` until complete.
  final DateTime? completedAt;

  /// The URL or magnet URI the user originally handed us at add time.
  /// Set once on the notifier side and never changes — the UI uses it
  /// for "Copy link" and other actions that need the original source.
  /// `null` for torrent tasks (no link to copy) and for synthetic HLS
  /// rows that predate this field.
  final String? sourceUrl;

  double get progress => totalLength > 0 ? completedLength / totalLength : 0;
  bool get isActive => status == DownloadStatus.active;
  bool get isPaused => status == DownloadStatus.paused;
  bool get isComplete => status == DownloadStatus.complete;
  bool get isError => status == DownloadStatus.error;

  TaskSummary copyWith({
    String? filename,
    int? totalLength,
    int? completedLength,
    DownloadStatus? status,
    int? downloadSpeed,
    String? errorCode,
    String? errorMessage,
    DateTime? addedAt,
    DateTime? completedAt,
    String? sourceUrl,
  }) {
    return TaskSummary(
      gid: gid,
      filename: filename ?? this.filename,
      totalLength: totalLength ?? this.totalLength,
      completedLength: completedLength ?? this.completedLength,
      status: status ?? this.status,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      dir: dir,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      addedAt: addedAt ?? this.addedAt,
      completedAt: completedAt ?? this.completedAt,
      sourceUrl: sourceUrl ?? this.sourceUrl,
    );
  }
}

/// aria2 status string -> typed enum.
enum DownloadStatus {
  active,
  waiting,
  paused,
  complete,
  error,
  removed,
  unknown,
}

DownloadStatus parseStatus(String raw) {
  switch (raw) {
    case 'active':
      return DownloadStatus.active;
    case 'waiting':
      return DownloadStatus.waiting;
    case 'paused':
      return DownloadStatus.paused;
    case 'complete':
      return DownloadStatus.complete;
    case 'error':
      return DownloadStatus.error;
    case 'removed':
      return DownloadStatus.removed;
    default:
      return DownloadStatus.unknown;
  }
}

String _basename(String path) {
  var i = path.length - 1;
  while (i >= 0 && path[i] != '/' && path[i] != '\\') {
    i--;
  }
  return i < 0 ? path : path.substring(i + 1);
}

TaskSummary taskFromAria2(Map<String, Object?> raw) {
  final status = parseStatus((raw['status'] as String?) ?? 'unknown');
  final files = raw['files'] as List?;
  String filename = '';
  int totalLength = 0;
  int completedLength = 0;
  if (files != null && files.isNotEmpty) {
    final first = (files.first as Map).cast<String, Object?>();
    filename = (first['path'] as String?) ?? '';
    totalLength = int.tryParse(first['length']?.toString() ?? '0') ?? 0;
    completedLength =
        int.tryParse(first['completedLength']?.toString() ?? '0') ?? 0;
  }
  if (totalLength == 0) {
    totalLength = int.tryParse(raw['totalLength']?.toString() ?? '0') ?? 0;
  }
  if (completedLength == 0) {
    completedLength =
        int.tryParse(raw['completedLength']?.toString() ?? '0') ?? 0;
  }
  // Return an empty filename when aria2 hasn't picked a path yet. The
  // notifier pre-fills a sensible name at add time and preserves it
  // when merging; the UI layer falls back to "(unnamed)" if it ever
  // sees an empty value, so failed tasks never show "file (1)".
  filename = filename.isNotEmpty ? _basename(filename) : '';

  // aria2 reports `addedAt` and `completedAt` as epoch seconds.
  // Only `complete` tasks get a non-zero `completedAt`.
  DateTime? _parseEpoch(Object? raw) {
    if (raw == null) return null;
    final secs = int.tryParse(raw.toString());
    if (secs == null || secs <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(secs * 1000);
  }

  return TaskSummary(
    gid: (raw['gid'] as String?) ?? '',
    filename: filename,
    totalLength: totalLength,
    completedLength: completedLength,
    status: status,
    downloadSpeed: int.tryParse(raw['downloadSpeed']?.toString() ?? '0') ?? 0,
    dir: (raw['dir'] as String?) ?? '',
    errorCode: raw['errorCode'] as String?,
    errorMessage: raw['errorMessage'] as String?,
    addedAt: _parseEpoch(raw['addedAt']),
    completedAt: _parseEpoch(raw['completedAt']),
  );
}
