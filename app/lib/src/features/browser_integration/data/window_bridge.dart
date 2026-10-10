// ignore_for_file: avoid_relative_lib_imports
// IPC contract for the Add-Task sub-window.
//
// Velocita's main app and the Add-Task dialog run as separate
// Flutter engines in separate OS windows (via `desktop_multi_window`).
// They communicate over the package's `MethodChannel`-based
// `setMethodHandler` / `invokeMethod` primitives — there is no
// shared memory, no shared Riverpod scope, no shared `BuildContext`.
// Every value that crosses the boundary has to be serialisable.
//
// The contract is intentionally tiny: only an AddRequest goes in,
// only a SubmitResult (or `null` for cancel) comes out. The serialised
// shapes are stable and live here so the sub-window's main entry
// and the main app's listener can evolve together.
//
// `desktop_multi_window` 0.2.1 API (verified):
//   * `DesktopMultiWindow.createWindow([String? arguments])` creates
//     a sub-window; `arguments` is forwarded to the sub-window's
//     `main(List<String> args)` as `args[2]`.
//   * Sub-window reads `args = ['multi_window', windowId, arguments]`.
//   * `DesktopMultiWindow.setMethodHandler(handler)` makes the current
//     window receive `invokeMethod` calls from any other window.
//   * `DesktopMultiWindow.invokeMethod(targetWindowId, method, [args])`
//     sends a call to a specific other window.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/add_request.dart';
import '../../downloads/presentation/add_task_dialog.dart';

/// Bounds for the sub-window, computed at spawn time from the main
/// app's current window size. Encoded as `{w, h}` inside the payload.
class AddTaskWindowSpec {
  const AddTaskWindowSpec(this.width, this.height);
  final double width;
  final double height;

  Map<String, Object?> toMap() => {'w': width, 'h': height};
  static AddTaskWindowSpec? fromMap(Map<String, Object?>? m) {
    if (m == null) return null;
    final w = (m['w'] as num?)?.toDouble();
    final h = (m['h'] as num?)?.toDouble();
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return AddTaskWindowSpec(w, h);
  }
}

/// Minimum / maximum bounds for the Add-Task sub-window. Sized to fit
/// the dialog comfortably on small screens but never larger than a
/// common 720p viewport. Picked to keep the dialog readable on both
/// a 1366×768 laptop and a 4K monitor without dominating either.
const double _kSubMinW = 460;
const double _kSubMinH = 360;
const double _kSubMaxW = 720;
const double _kSubMaxH = 640;
const double _kSubDefaultW = 560;
const double _kSubDefaultH = 460;

/// Width/height as a fraction of the main window. Tuned so the dialog
/// reads as a centred overlay, not a full takeover.
const double _kSubRatioW = 0.60;
const double _kSubRatioH = 0.55;

/// Compute a sub-window size for the given main window [w]×[h] (or
/// defaults if either dimension is missing). The result always lies
/// within `[_kSubMinW, _kSubMaxW] × [_kSubMinH, _kSubMaxH]`.
double _clampSize(double v, double minV, double maxV) =>
    v < minV ? minV : (v > maxV ? maxV : v);

({double w, double h}) computeAddTaskSubWindowSize({
  required double? mainW,
  required double? mainH,
}) {
  if (mainW == null || mainH == null || mainW <= 0 || mainH <= 0) {
    return (w: _kSubDefaultW, h: _kSubDefaultH);
  }
  final w = _clampSize(mainW * _kSubRatioW, _kSubMinW, _kSubMaxW);
  final h = _clampSize(mainH * _kSubRatioH, _kSubMinH, _kSubMaxH);
  return (w: w, h: h);
}

/// Read the main app's current window bounds. Best-effort: returns null
/// on any failure (window_manager not initialised, hidden, headless
/// tests). The sub-window spawner falls back to a default size.
Future<({double? w, double? h})> _readMainWindowSize() async {
  try {
    final rect = await windowManager.getBounds();
    return (w: rect.width, h: rect.height);
  } catch (_) {
    return (w: null, h: null);
  }
}
Future<void> ipcLog(String line) async {
  try {
    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) return;
    final f = File('$appData/Velocita/ipc.log');
    await f.parent.create(recursive: true);
    final stamp = DateTime.now().toIso8601String();
    await f.writeAsString('[$stamp] $line\n', mode: FileMode.append);
  } catch (_) {}
}

// ── Channel names ──────────────────────────────────────────────

/// `args[0]` for the sub-window. The C++ side dispatches any
/// process whose argv[0] equals this to the sub-window's `main()`.
const String kMultiWindowChannel = 'multi_window';

/// The first token inside the sub-window's `args[2]` payload — a
/// logical channel so multiple sub-window kinds can share the same
/// engine dispatch.
const String kAddTaskChannel = 'velocita.add_task';

/// Method name the sub-window `invokeMethod`s back to the main
/// window (id 0) when the user confirms or dismisses the dialog.
const String kAddTaskResultMethod = 'velocita.add_task.result';

// ── Payload shapes ────────────────────────────────────────────

/// What the main app hands to the sub-window via
/// `DesktopMultiWindow.createWindow(arguments)`.
class AddTaskPayload {
  const AddTaskPayload({required this.request, this.window});
  final AddRequest request;

  /// Computed at spawn time from the main window's bounds. Read by the
  /// sub-window's main() to size the OS window before showing it.
  /// `null` means "use a sensible default".
  final AddTaskWindowSpec? window;

  /// Encode as a single string (the C++ side joins it back to
  /// argv[2] on the sub-window side).
  String encode() => jsonEncode({
        'url': request.url,
        'source': request.source.name,
        'receivedAt': request.receivedAt.millisecondsSinceEpoch,
        if (request.referer != null) 'referer': request.referer,
        if (request.tabTitle != null) 'tabTitle': request.tabTitle,
        if (request.cookieHeader != null) 'cookieHeader': request.cookieHeader,
        if (request.requestHeaders != null)
          'requestHeaders': request.requestHeaders,
        if (request.dedupKey != null) 'dedupKey': request.dedupKey,
        if (window != null) 'window': window!.toMap(),
      });

  /// Decode from the JSON the C++ side hands the sub-window's
  /// main() via `args[2]`. Throws on malformed input — the
  /// sub-window's main() catches and exits with an error log.
  static AddTaskPayload decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final r = AddRequest(
      url: json['url'] as String,
      source: AddSource.values.firstWhere(
        (s) => s.name == (json['source'] as String? ?? 'unknown'),
        orElse: () => AddSource.unknown,
      ),
      receivedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['receivedAt'] as int?) ?? 0,
      ),
      referer: json['referer'] as String?,
      tabTitle: json['tabTitle'] as String?,
      cookieHeader: json['cookieHeader'] as String?,
      requestHeaders: (json['requestHeaders'] as List?)
          ?.whereType<String>()
          .toList(growable: false),
    );
    // `dedupKey` is a mutable field on AddRequest (not in the ctor)
    // — assign after construction.
    final dk = json['dedupKey'] as String?;
    if (dk != null && dk.isNotEmpty) r.dedupKey = dk;
    return AddTaskPayload(
      request: r,
      window: AddTaskWindowSpec.fromMap(
        (json['window'] as Map?)?.cast<String, Object?>(),
      ),
    );
  }
}

/// What the sub-window sends back to the main app. Used as the
/// `arguments` parameter of `invokeMethod(kAddTaskResultMethod, ...)`.
class AddTaskResult {
  const AddTaskResult.confirmed(this.submit) : cancelled = false;
  const AddTaskResult.cancelled()
      : submit = null,
        cancelled = true;

  final SubmitResult? submit;
  final bool cancelled;

  Map<String, Object?> toMap() => {
        'cancelled': cancelled,
        if (submit != null) 'submit': _submitToMap(submit!),
      };

  static AddTaskResult fromMap(Map<String, dynamic> json) {
    if ((json['cancelled'] as bool?) ?? false) {
      return const AddTaskResult.cancelled();
    }
    // The standard method codec decodes the nested `submit` map as
    // `Map<Object?, Object?>`, so `as Map<String, dynamic>?` THROWS a
    // TypeError here. Build a lazy cast view instead — the actual
    // values are already the right runtime types.
    final raw = json['submit'];
    if (raw is! Map) return const AddTaskResult.cancelled();
    final m = raw.cast<String, dynamic>();
    final kindName = m['kind'] as String? ?? 'url';
    final kind = switch (kindName) {
      'url' => SubmitKind.url,
      'magnet' => SubmitKind.magnet,
      'torrent' => SubmitKind.torrent,
      _ => SubmitKind.url,
    };
    return AddTaskResult.confirmed(SubmitResult(
      kind: kind,
      url: m['url'] as String?,
      magnet: m['magnet'] as String?,
      torrentBytes: (m['torrentBytes'] as List?)
          ?.whereType<int>()
          .toList(growable: false),
      torrentName: m['torrentName'] as String?,
      saveDir: m['saveDir'] as String?,
    ));
  }

  static Map<String, Object?> _submitToMap(SubmitResult r) => {
        'kind': r.kind.name,
        if (r.url != null) 'url': r.url,
        if (r.magnet != null) 'magnet': r.magnet,
        if (r.torrentBytes != null) 'torrentBytes': r.torrentBytes,
        if (r.torrentName != null) 'torrentName': r.torrentName,
        if (r.saveDir != null) 'saveDir': r.saveDir,
      };
}

// ── Sub-window spawning (called by the main app) ──────────────

/// Spawn an Add-Task sub-window. The window runs an isolated
/// Flutter engine that hosts `AddTaskSubWindowApp`. The main app
/// listens for the [kAddTaskResultMethod] call via
/// [DesktopMultiWindow.setMethodHandler] (subscribed by
/// `pendingAddRequestListener`).
///
/// The main app may be hidden in the tray at this point — the
/// sub-window is independent and self-contained.
///
/// Size: computed from the main window's current bounds (a fraction
/// clamped to sane min/max), and handed to the sub-window via the
/// payload so the OS window opens at the right size on the first
/// frame instead of growing into place.
Future<void> spawnAddTaskSubWindow(AddRequest request) async {
  final main = await _readMainWindowSize();
  final size = computeAddTaskSubWindowSize(mainW: main.w, mainH: main.h);
  await ipcLog('spawnAddTaskSubWindow: main=${main.w}x${main.h} '
      'sub=${size.w.toStringAsFixed(0)}x${size.h.toStringAsFixed(0)}');
  final payload = AddTaskPayload(
    request: request,
    window: AddTaskWindowSpec(size.w, size.h),
  ).encode();
  await DesktopMultiWindow.createWindow(
    '$kAddTaskChannel $payload',
  );
}

// ── Method handler (called by the main app) ───────────────────

/// The dispatcher that the main app registers with
/// `DesktopMultiWindow.setMethodHandler`. Routes incoming
/// `kAddTaskResultMethod` calls from sub-windows into [onResult].
/// Pass it directly:
///
/// ```dart
/// DesktopMultiWindow.setMethodHandler(addTaskResultHandler);
/// ```
Future<dynamic> addTaskResultHandler(
  MethodCall call,
  int fromWindowId,
) async {
  if (call.method != kAddTaskResultMethod) {
    // Not ours — return null so the framework's default behavior
    // applies (none, in this case).
    return null;
  }
  await ipcLog(
    'addTaskResultHandler: method=${call.method} '
    'from=$fromWindowId args=$call.arguments',
  );
  final map = (call.arguments as Map).cast<String, dynamic>();
  _mainAppResultSink.add(AddTaskResult.fromMap(map));
  return null;
}

/// Broadcast stream the main app subscribes to so its UI / data
/// layers can react to sub-window confirmations.
final _mainAppResultSink = _MainAppResultStream();

class _MainAppResultStream {
  final _controller = StreamController<AddTaskResult>.broadcast();
  Stream<AddTaskResult> get stream => _controller.stream;
  void add(AddTaskResult r) => _controller.add(r);
}

/// Public accessor the main-app listener subscribes to. Lazy-
/// initialised so we don't open a stream controller until something
/// actually listens.
Stream<AddTaskResult> get onSubWindowAddTaskResult {
  return _mainAppResultSink.stream;
}
