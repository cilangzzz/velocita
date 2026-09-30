import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:synchronized/synchronized.dart';

import '../errors.dart';

/// Spawns and supervises the `aria2c` subprocess.
///
/// Reference: Motrix's `src/core/engine/aria2/aria2-process-manager.ts`
/// (~500 lines). The Dart implementation is shorter because Dart's
/// [Process] API handles stdio + exit codes natively.
class Aria2ProcessManager {
  Aria2ProcessManager({
    required this.binaryPath,
    required this.workingDirectory,
    required this.arguments,
    Map<String, String>? environment,
  }) : _environment = environment ?? const {};

  final String binaryPath;
  final String workingDirectory;
  final List<String> arguments;
  final Map<String, String> _environment;

  final Lock _lock = Lock();
  final Logger _log = Logger('Aria2ProcessManager');

  Process? _process;
  final StreamController<int> _exit = StreamController<int>.broadcast();
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;

  Process? get process => _process;
  bool get isRunning => _process != null;
  Stream<int> get onExit => _exit.stream;
  int? get pid => _process?.pid;

  Future<void> start() async {
    await _lock.synchronized(() async {
      if (_process != null) {
        throw const EngineFailure('already running');
      }
      _log.info('spawning aria2c pid=? args=${arguments.length}');
      try {
        final proc = await Process.start(
          binaryPath,
          arguments,
          workingDirectory: workingDirectory,
          environment: _environment,
          mode: ProcessStartMode.normal,
        );
        _process = proc;
        _stdoutSub = proc.stdout
            .transform(const SystemEncoding().decoder)
            .listen(_handleStdout);
        _stderrSub = proc.stderr
            .transform(const SystemEncoding().decoder)
            .listen(_handleStderr);
        unawaited(proc.exitCode.then((code) async {
          await _onExit(code);
        }));
      } catch (e, st) {
        throw EngineFailure('spawn failed', cause: e, context: {'stack': st.toString()});
      }
    });
  }

  void _handleStdout(String line) {
    _log.fine('stdout: $line');
  }

  void _handleStderr(String line) {
    _log.warning('stderr: $line');
  }

  Future<void> _onExit(int code) async {
    _log.info('aria2c exited code=$code');
    _process = null;
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;
    _exit.add(code);
  }

  Future<void> stop({Duration gracePeriod = const Duration(seconds: 5)}) async {
    await _lock.synchronized(() async {
      final proc = _process;
      if (proc == null) return;
      _log.info('stopping aria2c pid=${proc.pid}');
      proc.kill(ProcessSignal.sigterm);
      try {
        await proc.exitCode.timeout(gracePeriod);
      } on TimeoutException {
        _log.warning('grace period elapsed, sending SIGKILL');
        proc.kill(ProcessSignal.sigkill);
      }
      _process = null;
    });
  }
}
