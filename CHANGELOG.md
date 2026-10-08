# Changelog

All notable changes to Velocita are documented here. Dates in `YYYY-MM-DD`.

## 2026-10-08 — M6: Browser integration (Native Messaging + velocita://)

### Added

- **M6** — Chrome / Edge / Firefox extensions plus a local IPC service
  that turns the browser into a first-class download source.
  - `BrowserIntegrationService`: loopback HTTP server on
    `127.0.0.1:16800` with `GET /api/ping`, `POST /api/add`,
    `POST /api/host`, `POST /api/deeplink`. CORS echoes
    `chrome-extension://` / `moz-extension://` origins.
  - Single-instance detection via the 16800 bind race: bind succeeds →
    primary; bind fails → 200ms stdin-vs-`app_links`-initial-URI race in
    `host_bridge.dart`, POST the payload into the primary, write a
    JSON ack to stdout (NM case), exit.
  - `NativeMessagingHost` (pure Dart, no deps) reads / writes
    4-byte LE uint32 length-prefixed UTF-8 JSON frames per the Chrome
    Native Messaging spec.
  - `host_installer` writes `com.velocita.host.json` plus the three
    `HKCU\…\NativeMessagingHosts\com.velocita.host` registry keys
    for Chrome / Edge / Firefox.
  - `PendingAddRequestListener` (mounted in `app.dart`'s `builder`)
    consumes the service's `Stream<AddRequest>`, opens the existing
    `AddTaskDialog` with the URL prefilled (or silently calls
    `taskListProvider.notifier.addUri` when the user disables the
    "show confirmation" toggle in Settings).
  - `BrowserIntegrationSection` in Settings: "Install for {Chrome,
    Edge, Firefox}" buttons, "Uninstall", live status line, the
    toggle.
  - Cross-browser MV3 + WebExtension source in
    `browser_extension/src/`; `tools/build_extensions.dart` stages
    it into `app/assets/extensions/{chrome,edge,firefox}/` for
    bundling via `pubspec.yaml`'s `assets:` section.
  - 8 new i18n keys in `AppLocalizations` for both `en` and
    `zh-CN`.
  - 5 new unit tests (NM host: 7 cases; service: 8; settings
    JSON: 6; AddRequest enum: 2). `flutter test` now 77 passing.
  - `docs/browser_integration.md` — flow diagram + manual QA
    matrix.

### Files

```
app/lib/src/features/browser_integration/
├── browser_integration.dart                barrel
├── domain/
│   ├── add_request.dart
│   └── browser_integration_settings.dart
├── data/
│   ├── browser_integration_service.dart
│   ├── host_bridge.dart
│   ├── host_installer.dart
│   ├── host_installer_windows.dart
│   ├── browser_integration_settings_provider.dart
│   ├── native_messaging_host.dart
│   └── pending_add_requests_provider.dart
└── presentation/
    ├── browser_integration_section.dart
    ├── install_instructions_dialog.dart
    └── pending_add_request_listener.dart
app/lib/main.dart                           MOD — bind race + self-heal
app/lib/src/app.dart                        MOD — wrap builder in listener
app/lib/src/routing/router.dart             MOD — rootNavigatorKey
app/lib/src/features/downloads/presentation/add_task_dialog.dart  MOD — initialUrl
app/lib/src/features/settings/settings_page.dart                  MOD — section
app/lib/src/localization/app_localizations.dart                    MOD — 8 keys
app/pubspec.yaml                                                  MOD — assets
app/assets/extensions/{chrome,edge,firefox}/                       NEW (built)
app/test/{browser_integration_service,settings,native_messaging_host,add_request}_test.dart
browser_extension/src/{manifest.*.json,background.js,popup.*,options.*,icons/}
tools/build_extensions.dart
docs/browser_integration.md
```

### Known limitations

- Linux / macOS per-browser manifest locations are not implemented
  (Windows HKCU only). Documented in `docs/browser_integration.md`.
- Firefox permanent install requires AMO signing; v1 is "Load
  Temporary Add-on" only.
- No cookie / auth passthrough — URL + referer + tabTitle only.

## 2026-09-30 — M0 → M5 prototype

> Source: synthesized from the 12-rule Flutter code-design doc and the
> Motrix `src/core/engine/aria2/` reference implementation.

### Added

- **M0** — aria2 process manager (spawn, stdio capture, graceful stop);
  WebSocket transport (`ws://127.0.0.1:<port>/jsonrpc`); JSON-RPC 2.0
  protocol with id correlation + 30 s timeout + token-secret injection.
  Verified by `tools/feat/aria2_ping.dart`.
- **M1** — Flutter Desktop app skeleton with `window_manager` (1280×800
  default, dark theme), `system_tray`, `app_links`, Riverpod
  `ProviderContainer` override of the bootstrapped kernel, and a
  `StatusBar` widget that shows `aria2 v1.37.0` + pid.
- **M2** — `DownloadsRepository` facade, `TaskListNotifier`
  (AsyncNotifier, 5 s poll throttle, per-mutation refresh), 3-tab
  `AddTaskDialog` (URL / Magnet / Torrent), real HTTP download
  verified by `tools/feat/download_smoke.dart` (1 MiB in ~3 s from
  `speed.cloudflare.com`).
- **M3** — Magnet URI parser (`parseMagnet`, `Magnet`, form-style
  percent-decoding, `xt` / `dn` / `tr` / `ws` deduplication); aria2
  protocol layer gains `addMagnet` + `addTorrent`; sidebar with
  status filters (All / Active / Paused / Completed / Error) + category
  placeholders.
- **M4** — Static i18n catalog (`AppLocalizations`) for `en` + `zh-CN`;
  `localeProvider` (StateNotifierProvider); 4-tab `NavigationBar`
  (Downloads / Scheduler / Plugins / Settings); `SchedulerPage` with
  7×24 grid; `PluginsPage` (SwitchListTile stub); `SettingsPage` with
  theme + language picker.
- **M5** — Kernel unit tests (`magnet_test.dart`, `json_rpc_test.dart`):
  8/8 passing. App widget tests (`downloads_screen_test.dart`): 3/3
  passing. `flutter analyze`: 0 issues. `flutter build windows --debug`:
  builds and runs.

### Fixed

- **M0** — `ProcessMode` was renamed to `ProcessStartMode` in Dart 3;
  `detached` does not give parent access to stdio or `exitCode`;
  `token:<secret>` prefix is required by aria2 (not bare secret).
- **M2** — `addUri` params were double-wrapped: `[secret, uris]` was
  encoded as `[[secret, uris]]` and rejected with "wrong type". Fix:
  `_withSecretInPlace` prepends to the call-site list instead of wrapping.
- **M3** — `--bt-enable-pex` is not an aria2 flag (it's
  `--enable-peer-exchange`); `--enable-pex=false` was rejected at
  spawn time.
- **M4** — `../localization/...` was a wrong relative path
  (`../../localization/...` from `features/<x>/<file>.dart`); several
  `ListTile`s were rendered without a Material ancestor in widget tests.

### Skipped (M5 — release engineering)

These require external tooling or signing certificates:

- Windows installer via NSIS (skipped)
- macOS DMG + notarization (skipped)
- Linux deb/rpm/pacman/AppImage (skipped)
- Code signing (skipped)
- Auto-update integration (skipped)
- Crash reporting (Sentry or similar) (skipped)
- CI matrix (Win/macOS/Linux GitHub Actions) (skipped)
- Third-party license extraction (skipped)

### Architecture notes (carry-over to future milestones)

- `velocita_kernel` stays pure-Dart; no Flutter imports allowed by
  convention (the `velocita_lint` analyzer plugin is the planned
  enforcement mechanism).
- `DownloadsRepository` is the only path the UI uses to talk to
  `Aria2RpcClient`; this invariant is load-bearing for the
  Drift-backed persistence in the next milestone.
- The aria2 binary is fetched from GitHub releases at version
  `1.37.0`; the `engine.lock.json`-style pinning that Motrix uses
  for its fork (`aria2_motrix 1.37.0-16`) is a TODO.
