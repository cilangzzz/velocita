/// Sealed `AppError` hierarchy.
///
/// All public APIs in the kernel return `Result<T, AppError>` (see
/// `kernel_bridge` in the app layer for the Riverpod-friendly `AsyncValue`
/// adapter).
sealed class AppError implements Exception {
  const AppError(this.message, {this.cause, this.context = const {}});

  final String message;
  final Object? cause;
  final Map<String, Object?> context;

  @override
  String toString() => '$runtimeType($message)';
}

/// Engine process / RPC failure.
final class EngineFailure extends AppError {
  const EngineFailure(super.message, {super.cause, super.context});
}

/// RPC protocol-level error (bad JSON, malformed request).
final class RpcProtocolError extends AppError {
  const RpcProtocolError(super.message, {super.cause, super.context});
}

/// WebSocket transport failure (connect refused, dropped).
final class TransportError extends AppError {
  const TransportError(super.message, {super.cause, super.context});
}

/// Configuration / settings failure.
final class ConfigError extends AppError {
  const ConfigError(super.message, {super.cause, super.context});
}

/// Domain validation failure.
final class ValidationError extends AppError {
  const ValidationError(super.message, {super.cause, super.context, this.field});

  final String? field;
}
