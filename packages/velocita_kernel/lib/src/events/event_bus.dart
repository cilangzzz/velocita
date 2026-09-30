import 'dart:async';

/// Typed broadcast event bus.
///
/// Events are typed by their runtime class. Consumers subscribe by
/// `[T]` to receive only events of that exact type.
///
/// Reference: Motrix's `core/events/TypedEventBus<TEventMap>` — but per event
/// type instead of a single map, to allow independent subscriptions across
/// packages.
class EventBus {
  final Map<Type, StreamController<Object?>> _controllers = {};

  Stream<T> on<T extends Object>() {
    final controller = _controllers[T] ??=
        StreamController<T>.broadcast();
    return controller.stream.cast<T>();
  }

  void emit<T extends Object>(T event) {
    final controller = _controllers[T];
    if (controller == null || controller.isClosed) return;
    controller.add(event);
  }

  Future<void> close() async {
    for (final c in _controllers.values) {
      if (!c.isClosed) await c.close();
    }
    _controllers.clear();
  }
}

/// Convenience event markers used by the kernel itself.
final class EngineStateChanged {
  const EngineStateChanged(this.state);
  final EngineState state;
}

enum EngineState {
  stopped,
  starting,
  running,
  reconnecting,
  failed,
}

final class EngineReady {
  const EngineReady(this.version, this.features);
  final String version;
  final List<String> features;
}

final class EngineDisconnected {
  const EngineDisconnected(this.reason);
  final String reason;
}

final class EngineReconnecting {
  const EngineReconnecting(this.attempt, this.nextRetryMs);
  final int attempt;
  final int nextRetryMs;
}

final class EngineFailed {
  const EngineFailed(this.reason);
  final String reason;
}
