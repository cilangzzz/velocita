# M0 — aria2_ping prototype

**Goal** (from `docs/rule/flutter_rule/12-implementation-plan.md`):
> a Dart CLI that spawns aria2, connects to its WebSocket, calls `getVersion`, prints the response.

**Status**: ✅ **PASSING**

## How to run

From `velocita/`:

```bash
# aria2c binary must be at velocita/bin/aria2c.exe (or pass path as arg)
dart run tools/feat/aria2_ping.dart
```

Optional first argument overrides the binary path.

## What it does

1. Picks a free local port by binding then closing a `ServerSocket`.
2. Spawns `aria2c` with `--enable-rpc`, `--rpc-listen-port=<free>`, `--rpc-secret=<random>`.
3. Connects to `ws://127.0.0.1:<port>/jsonrpc`.
4. Calls `aria2.getVersion` with `params: ["token:<secret>"]`.
5. Prints the engine info to stdout (one JSON line, easy for tests to consume).
6. Graceful shutdown.

## Wire trace (success)

```
→ {"jsonrpc":"2.0","id":"1","method":"aria2.getVersion","params":["token:velocita-XXX"]}
← {"id":"1","jsonrpc":"2.0","result":{"enabledFeatures":[...],"version":"1.37.0"}}
```

## Pitfalls encountered (now documented for M1)

| Pitfall | Fix |
|---|---|
| `ProcessMode.detached` → no stdio access | use `ProcessStartMode.normal` for the M0 prototype; M1 will revisit daemonization via `detachedWithStdio` or platform-specific flag |
| `ProcessStartMode.detachedWithStdio` → no `exitCode` future | poll `Process.kill(pid, ProcessSignal.sigusr1)` is the cheapest liveness check |
| Bare secret was rejected with `code:1 Unauthorized` | aria2 expects `token:<secret>` as first param, not bare secret |
| `dart:io`'s `ProcessMode` was renamed in Dart 3 | use `ProcessStartMode.{normal,inheritStdio,detached,detachedWithStdio}` |
| `Platform.script.resolve('../bin/...')` from `tools/feat/` | needs `../../bin/...` (two levels up) |

## Code locations

| File | Role |
|---|---|
| `packages/velocita_kernel/lib/src/rpc/web_socket_transport.dart` | WebSocket wrapper |
| `packages/velocita_kernel/lib/src/rpc/json_rpc_protocol.dart` | JSON-RPC 2.0 envelope + id correlation + timeout |
| `packages/velocita_kernel/lib/src/engine/aria2_process_manager.dart` | `Process.start` + stdio capture + graceful stop |
| `packages/velocita_kernel/lib/src/engine/aria2_rpc_client.dart` | `EngineAdapter` impl with secret injection |
| `packages/velocita_kernel/lib/src/domain/engine_adapter.dart` | engine contract |
| `packages/velocita_kernel/lib/src/errors.dart` | sealed `AppError` hierarchy |
| `packages/velocita_kernel/lib/src/events/event_bus.dart` | typed broadcast `EventBus` (unused in M0 but ready) |
| `tools/feat/aria2_ping.dart` | the prototype CLI |

## Outputs

Stdout (one line, JSON):

```json
{"status":"engine_ready","version":"1.37.0","features":["Async DNS","BitTorrent","Firefox3 Cookie","GZip","HTTPS","Message Digest","Metalink","XML-RPC","SFTP"],"pid":132}
```

Stderr (human-readable):

```
workDir: C:\Users\sysadmin\AppData\Local\Temp\velocita_ping_XXXX
binary: H:\...\velocita\bin\aria2c.exe  port: 1956
[INFO] Aria2ProcessManager: spawning aria2c pid=? args=8
aria2 spawned pid=132
connected
aria2 version: 1.37.0
enabled features: Async DNS, BitTorrent, ...
clean shutdown complete
```

## Next milestone

M1 — Flutter skeleton + `velocita_lint` analyzer plugin + `EngineSupervisor` lifecycle.
