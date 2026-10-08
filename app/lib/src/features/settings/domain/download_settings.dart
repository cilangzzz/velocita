/// Pure-Dart value object for the user-facing download settings.
///
/// These are the settings the user can change from the Settings page —
/// the kernel layer (`aria2`) is the source of truth at runtime, but
/// this object is what we persist between sessions and what the UI
/// binds to.
class DownloadSettings {
  const DownloadSettings({
    required this.saveDir,
    required this.maxConcurrentDownloads,
    required this.maxOverallDownloadLimitBytesPerSec,
    this.proxyKind = ProxyKind.off,
    this.proxyHost = '',
    this.proxyPort = 0,
    this.proxyUsername = '',
    this.proxyPassword = '',
    this.proxyBypass = '',
    this.split = defaultSplit,
    this.maxConnectionPerServer = defaultMaxConnPerServer,
  });

  /// Default save directory. Maps to aria2's `dir` global option.
  /// When the user hasn't set anything explicit, this is the platform's
  /// downloads directory.
  final String saveDir;

  /// Max number of concurrent downloads aria2 will run.
  /// Maps to `max-concurrent-downloads`. Clamped to [minConcurrent, maxConcurrent].
  final int maxConcurrentDownloads;

  /// Overall download speed cap in bytes/sec. `0` means unlimited.
  /// Maps to `max-overall-download-limit`. aria2c reads this in bytes/sec.
  final int maxOverallDownloadLimitBytesPerSec;

  /// Proxy mode. `off` = no proxy; `http` / `socks5` = use the configured
  /// proxy server. Mapped at runtime to aria2's `all-proxy` URL.
  final ProxyKind proxyKind;

  /// Proxy server host. Required when [proxyKind] is not `off`.
  final String proxyHost;

  /// Proxy server port. Required when [proxyKind] is not `off`.
  /// `0` is treated as "let the user set it later" — not used.
  final int proxyPort;

  /// Optional HTTP basic-auth username.
  final String proxyUsername;

  /// Optional HTTP basic-auth password.
  final String proxyPassword;

  /// Comma-separated host bypass list, mapped to aria2's `no-proxy`.
  /// Example: `localhost,127.0.0.1,*.internal`.
  final String proxyBypass;

  /// How many parallel ranges aria2 splits each file into for HTTP
  /// downloads. Maps to `split`. The cap is also gated by
  /// [maxConnectionPerServer] and `min-split-size` (see
  /// [[aria2-split-vs-min-split-size]]).
  ///
  /// Runtime changes via `changeGlobalOption` only apply to **new**
  /// downloads — already-running tasks keep their original piece
  /// layout (aria2 behaviour, not a bug).
  final int split;

  /// Cap on concurrent connections to the same server. Maps to
  /// `max-connection-per-server`. The effective per-task connection
  /// count is `min(split, maxConnectionPerServer)`, so this value must
  /// be at least as large as [split] to get the full split count.
  final int maxConnectionPerServer;

  /// Speed limit in KiB/s (UI-friendly unit). `null` means unlimited.
  int? get maxOverallDownloadLimitKBps =>
      maxOverallDownloadLimitBytesPerSec <= 0
          ? null
          : (maxOverallDownloadLimitBytesPerSec / 1024).round();

  static const int minConcurrent = 1;
  static const int maxConcurrent = 16;
  static const int defaultSplit = 5;
  static const int defaultMaxConnPerServer = 5;

  DownloadSettings copyWith({
    String? saveDir,
    int? maxConcurrentDownloads,
    int? maxOverallDownloadLimitBytesPerSec,
    ProxyKind? proxyKind,
    String? proxyHost,
    int? proxyPort,
    String? proxyUsername,
    String? proxyPassword,
    String? proxyBypass,
    int? split,
    int? maxConnectionPerServer,
  }) {
    return DownloadSettings(
      saveDir: saveDir ?? this.saveDir,
      maxConcurrentDownloads:
          maxConcurrentDownloads ?? this.maxConcurrentDownloads,
      maxOverallDownloadLimitBytesPerSec:
          maxOverallDownloadLimitBytesPerSec ??
              this.maxOverallDownloadLimitBytesPerSec,
      proxyKind: proxyKind ?? this.proxyKind,
      proxyHost: proxyHost ?? this.proxyHost,
      proxyPort: proxyPort ?? this.proxyPort,
      proxyUsername: proxyUsername ?? this.proxyUsername,
      proxyPassword: proxyPassword ?? this.proxyPassword,
      proxyBypass: proxyBypass ?? this.proxyBypass,
      split: split ?? this.split,
      maxConnectionPerServer:
          maxConnectionPerServer ?? this.maxConnectionPerServer,
    );
  }

  Map<String, Object?> toJson() => {
        'saveDir': saveDir,
        'maxConcurrentDownloads': maxConcurrentDownloads,
        // 0 == unlimited, so we keep the wire form identical.
        'maxOverallDownloadLimitBytesPerSec':
            maxOverallDownloadLimitBytesPerSec,
        'proxyKind': proxyKind.name,
        'proxyHost': proxyHost,
        'proxyPort': proxyPort,
        'proxyUsername': proxyUsername,
        'proxyPassword': proxyPassword,
        'proxyBypass': proxyBypass,
        'split': split,
        'maxConnectionPerServer': maxConnectionPerServer,
      };

  static DownloadSettings fromJson(Map<String, Object?> raw) {
    return DownloadSettings(
      saveDir: (raw['saveDir'] as String?) ?? '',
      maxConcurrentDownloads:
          (raw['maxConcurrentDownloads'] as int?) ?? defaultMaxConcurrent,
      maxOverallDownloadLimitBytesPerSec:
          (raw['maxOverallDownloadLimitBytesPerSec'] as int?) ?? 0,
      proxyKind: _parseProxyKind(raw['proxyKind'] as String?),
      proxyHost: (raw['proxyHost'] as String?) ?? '',
      proxyPort: (raw['proxyPort'] as int?) ?? 0,
      proxyUsername: (raw['proxyUsername'] as String?) ?? '',
      proxyPassword: (raw['proxyPassword'] as String?) ?? '',
      proxyBypass: (raw['proxyBypass'] as String?) ?? '',
      split: (raw['split'] as int?) ?? defaultSplit,
      maxConnectionPerServer:
          (raw['maxConnectionPerServer'] as int?) ?? defaultMaxConnPerServer,
    );
  }

  static ProxyKind _parseProxyKind(String? raw) {
    for (final k in ProxyKind.values) {
      if (k.name == raw) return k;
    }
    return ProxyKind.off;
  }

  /// Default concurrent count when nothing is persisted.
  /// aria2's own default is 5.
  static const int defaultMaxConcurrent = 5;

  /// Build the aria2 `all-proxy` URL from this snapshot.
  /// Returns `''` when proxy is off or incomplete — aria2 treats empty
  /// `all-proxy` as "no proxy", which is the desired behaviour.
  ///
  /// aria2c (verified 1.37.0) only supports HTTP proxies through
  /// `--all-proxy`; its documented value grammar is
  /// `[http://][USER:PASSWORD@]HOST[:PORT]` and it rejects any `socks*`
  /// scheme at both startup and runtime. SOCKS5 therefore produces no
  /// URL here — the UI disables the option so users can't configure a
  /// proxy that would never be used.
  String buildAllProxy() {
    if (proxyKind != ProxyKind.http) return '';
    final host = proxyHost.trim();
    if (host.isEmpty) return '';
    if (proxyPort <= 0 || proxyPort > 65535) return '';
    final user = proxyUsername.trim();
    final pass = proxyPassword;
    final userInfo =
        user.isEmpty ? '' : (pass.isEmpty ? '$user@' : '$user:$pass@');
    return 'http://$userInfo$host:$proxyPort';
  }
}

/// Proxy mode. Stored on disk as the enum name (`off` / `http` / `socks5`).
enum ProxyKind { off, http, socks5 }
