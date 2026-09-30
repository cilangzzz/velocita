# Velocita

A Flutter-native download manager built on the Motrix kernel model.

Velocita keeps Motrix's mature `aria2c` engine as the actual download
backend, but replaces the Electron + Node.js stack with a single Dart VM.
The same host-neutral core that Motrix serves from `src/core/` becomes a
**pure-Dart package** here (`packages/velocita_kernel/`); the Electron
shell is replaced by a Flutter Desktop app; the JSON-RPC over WebSocket
that Motrix uses to talk to aria2 is reused verbatim.

## Layout

```
velocita/
├── bin/aria2c.exe                                    # aria2 1.37.0 (downloaded on first build)
├── packages/
│   └── velocita_kernel/                              # PURE DART — no Flutter, no Material
│       └── lib/src/{rpc,engine,events,domain,errors,torrent}/
├── tools/feat/
│   ├── aria2_ping.dart                                # M0 prototype (CLI)
│   ├── download_smoke.dart                            # M2 real HTTP download
│   ├── magnet_test.dart                               # M3 magnet parser smoke
│   └── m3_smoke.dart                                  # M3 URL+magnet+torrent call-shape
└── app/                                              # Flutter Desktop
    └── lib/src/{app,common_widgets,features,localization,
                  platform,routing,kernel_bridge}/
```

## Build

```bash
# 1. Get the kernel's dependencies.
cd packages/velocita_kernel && dart pub get && cd ../..

# 2. Get the app's dependencies.
cd app && flutter pub get

# 3. Build the Windows binary (debug).
flutter build windows --debug

# 4. Stage aria2c next to the binary.
cp ../bin/aria2c.exe build/windows/x64/runner/Debug/

# 5. Run.
./build/windows/x64/runner/Debug/velocita.exe
```

The app boots, spawns aria2c, connects to its WebSocket, and renders
"Engine: Connected aria2 v1.37.0" in the bottom status bar.

## Test

```bash
# Kernel unit tests (magnet parser, JSON-RPC protocol).
cd packages/velocita_kernel && dart test

# App widget tests.
cd ../app && flutter test
```

## Run the M0 / M2 / M3 prototypes directly

```bash
cd tools/feat
dart pub get

# M0: spawn → WS → getVersion (1 second end-to-end).
dart run aria2_ping.dart

# M2: real HTTP download from speed.cloudflare.com (1 MiB in ~3s).
dart run download_smoke.dart

# M3: exercise addUri + addMagnet + addTorrent call shapes.
dart run m3_smoke.dart
```

## Features delivered

| M | What | Where |
|---|---|---|
| **M0** | Spawn aria2c, connect WS, call getVersion | `tools/feat/aria2_ping.dart` |
| **M1** | Flutter Desktop app boots, window manager, status bar | `app/lib/main.dart`, `lib/src/app.dart`, `lib/src/common_widgets/status_bar.dart` |
| **M2** | HTTP download via the kernel, real download verified | `app/lib/src/features/downloads/`, `tools/feat/download_smoke.dart` |
| **M3** | Magnet URI parsing + addMagnet + addTorrent; sidebar + filters | `packages/velocita_kernel/lib/src/torrent/magnet.dart`, `app/lib/src/features/downloads/presentation/add_task_dialog.dart` |
| **M4** | i18n (en + zh-CN), Settings / Scheduler / Plugins pages, NavigationBar | `app/lib/src/localization/`, `app/lib/src/features/{settings,scheduler,plugins}/`, `app/lib/src/routing/router.dart` |
| **M5** | Unit tests (8/8 in kernel, 3/3 in app) + docs | `packages/velocita_kernel/test/`, `app/test/`, this README |

## M5 — what's done vs skipped

| Item | Status |
|---|---|
| Unit tests (kernel: magnet + JSON-RPC) | ✅ done — 8 passing |
| Widget tests (DownloadsScreen + AddTaskDialog) | ✅ done — 3 passing |
| `flutter analyze` | ✅ clean — 0 issues |
| README + CHANGELOG | ✅ this file + `CHANGELOG.md` |
| Third-party licenses | ⏭️ requires `flutter_licenses` extractor (skipped) |
| Windows installer (NSIS) | ⏭️ requires NSIS toolchain (skipped) |
| macOS DMG + notarization | ⏭️ requires Xcode + codesign identity (skipped) |
| Linux deb/rpm/pacman/AppImage | ⏭️ requires distribution-specific tooling (skipped) |
| Code signing | ⏭️ requires signing certificate (skipped) |
| Crash reporting (Sentry) | ⏭️ Sentry not yet integrated |
| Auto-update | ⏭️ not yet integrated |
| CI matrix (Win/macOS/Linux) | ⏭️ GitHub Actions not yet configured |

## Known limitations

- The binary is built and verified to **run**, not **ship**. To produce
  release builds, sign certs + platform packagers must be configured.
- The plugin system is a UI stub in M4; Dart Isolate sandboxing + capability
  tokens land in M5+ once we have a real plugin to load.
- The `finalize-fs` Rust sidecar is **not** integrated yet — file
  completion currently relies on aria2's default atomic-rename behavior.
- `aria2` is downloaded as a pre-built Windows binary (`1.37.0` from
  GitHub releases). For production, we'd vendor a fork with our patches
  and sign it.

## Architecture invariant

> The kernel never imports `package:flutter/*`. The UI never talks to
> `Aria2RpcClient` directly. Every cross-layer request flows through the
> `DownloadsRepository`. Lint enforces this; tests assume it.

This is the entire reason Velocita exists as a single Dart VM: to make
that invariant cheap to maintain.
