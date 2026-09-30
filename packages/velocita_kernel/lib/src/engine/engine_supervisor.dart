import 'dart:async';

import 'package:logging/logging.dart';

import '../events/event_bus.dart';
import 'aria2_process_manager.dart';

/// `EngineSupervisor` owns the lifecycle of one aria2 instance.
///
/// Reference: Motrix's `src/core/engine/engine-supervisor.ts` (~1109 lines).
/// The Dart implementation focuses on the M0 surface — spawn → WS connect
/// → health check → emit `EngineReady`. The full restart/state-machine
/// behavior lands in M1.
class EngineSupervisor {
  EngineSupervisor({
    required Aria2ProcessManager processManager,
    required Future<EngineReady> Function() onConnected,
  })  : _processManager = processManager,
        _onConnected = onConnected;

  final Aria2ProcessManager _processManager;
  final Future<EngineReady> Function() _onConnected;
  final EventBus _events = EventBus();
  final Logger _log = Logger('EngineSupervisor');

  Timer? _healthCheck;

  EventBus get events => _events;

  Future<void> start() async {
    _events.emit(const EngineStateChanged(EngineState.starting));
    try {
      await _processManager.start();
      // Give aria2 a moment to bind the RPC port.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final ready = await _onConnected();
      _events.emit(EngineStateChanged(EngineState.running));
      _events.emit(ready);
      _startHealthCheck();
    } catch (e) {
      _events.emit(const EngineStateChanged(EngineState.failed));
      _events.emit(EngineFailed(e.toString()));
      rethrow;
    }
  }

  void _startHealthCheck() {
    _healthCheck?.cancel();
    _healthCheck = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_processManager.isRunning) {
        _events.emit(const EngineDisconnected('process not running'));
        return;
      }
      // Cheap ping: a successful `getVersion` round-trip.
      try {
        // The health check is best-effort; failures are non-fatal as long
        // as the underlying WebSocket is still connected. We do not yet
        // dispatch a full RPC call here because the supervisor in M0 only
        // owns the lifecycle, not the RPC adapter.
      } catch (e) {
        _log.fine('health check error: $e');
      }
    });
  }

  Future<void> stop({Duration gracePeriod = const Duration(seconds: 5)}) async {
    _healthCheck?.cancel();
    await _processManager.stop(gracePeriod: gracePeriod);
    _events.emit(const EngineStateChanged(EngineState.stopped));
    await _events.close();
  }

  /// Exposed so the prototype CLI can pipe `events` to stdout.
  Stream<Object> get eventStream =>
      _events.on<EngineStateChanged>().map((e) => e as Object).cast<Object>();
}
