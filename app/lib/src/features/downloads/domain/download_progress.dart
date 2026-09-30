/// Lightweight progress event used by the throttle/coalesce layer.
class DownloadProgress {
  const DownloadProgress({
    required this.gid,
    required this.completedLength,
    required this.totalLength,
    required this.downloadSpeed,
    required this.status,
  });

  final String gid;
  final int completedLength;
  final int totalLength;
  final int downloadSpeed;
  final String status;
}
