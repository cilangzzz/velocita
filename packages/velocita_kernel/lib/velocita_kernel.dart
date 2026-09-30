/// Velocita kernel — pure Dart, no Flutter dependency.
///
/// The kernel owns the download engine (aria2 subprocess) and exposes a
/// typed, batch-coalesced event surface to the UI layer.
///
/// Layer rules (lint-enforced via `tools/velocita_lint`):
/// - NO Flutter imports
/// - NO `Map<String, dynamic>` in public APIs
/// - NO direct SDK calls (drift, http) — those belong to the data layer
library velocita_kernel;

export 'src/errors.dart';
export 'src/events/event_bus.dart';
export 'src/rpc/json_rpc_protocol.dart';
export 'src/rpc/web_socket_transport.dart';
export 'src/engine/aria2_process_manager.dart';
export 'src/engine/aria2_rpc_client.dart';
export 'src/engine/engine_supervisor.dart';
export 'src/domain/engine_adapter.dart';
export 'src/torrent/magnet.dart';
