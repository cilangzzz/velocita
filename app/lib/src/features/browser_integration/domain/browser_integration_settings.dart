/// Pure-Dart value object for the user-facing browser-integration settings.
///
/// Persisted at `<appSupport>/velocita/browser-integration.json` — kept
/// separate from `DownloadSettings` because these knobs are about the app
/// shell's behavior when a download arrives, not about what the aria2
/// engine does with it.
library;

enum BrowserKind { chrome, edge, firefox }

class BrowserIntegrationSettings {
  const BrowserIntegrationSettings({
    this.enabled = true,
    this.showConfirmationPopup = true,
    this.port = defaultPort,
    this.installedBrowsers = const <BrowserKind>{},
  });

  /// Master switch for the whole feature. When `false`, the local HTTP
  /// IPC server is not started and the extension / `velocita://` deep
  /// link cannot hand off requests to this instance. The toggle in
  /// Settings is the single source of truth — flipping it starts /
  /// stops the server live without a relaunch.
  final bool enabled;

  /// When true, the user gets a confirmation dialog before each
  /// browser-sent download is enqueued. When false, the task is added
  /// to aria2 immediately and a SnackBar is shown instead.
  final bool showConfirmationPopup;

  /// Port the local HTTP IPC server binds on (loopback only).
  final int port;

  /// Which browsers have already been registered via the "Install for
  /// {Chrome,Edge,Firefox}" buttons. Reflected in the Settings UI so the
  /// user can tell at a glance which browsers are wired up.
  final Set<BrowserKind> installedBrowsers;

  static const int defaultPort = 16800;
  static const int minPort = 1024;
  static const int maxPort = 65535;

  BrowserIntegrationSettings copyWith({
    bool? enabled,
    bool? showConfirmationPopup,
    int? port,
    Set<BrowserKind>? installedBrowsers,
  }) {
    return BrowserIntegrationSettings(
      enabled: enabled ?? this.enabled,
      showConfirmationPopup:
          showConfirmationPopup ?? this.showConfirmationPopup,
      port: port ?? this.port,
      installedBrowsers: installedBrowsers ?? this.installedBrowsers,
    );
  }

  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'showConfirmationPopup': showConfirmationPopup,
        'port': port,
        'installedBrowsers': [
          for (final b in installedBrowsers) b.name,
        ],
      };

  static BrowserIntegrationSettings fromJson(Map<String, Object?> raw) {
    final port = (raw['port'] as int?) ?? defaultPort;
    final names = (raw['installedBrowsers'] as List?) ?? const <Object?>[];
    return BrowserIntegrationSettings(
      enabled: (raw['enabled'] as bool?) ?? true,
      showConfirmationPopup: (raw['showConfirmationPopup'] as bool?) ?? true,
      port: port.clamp(minPort, maxPort),
      installedBrowsers: {
        for (final n in names.cast<String>())
          if (BrowserKind.values.any((b) => b.name == n))
            BrowserKind.values.firstWhere((b) => b.name == n),
      },
    );
  }
}
