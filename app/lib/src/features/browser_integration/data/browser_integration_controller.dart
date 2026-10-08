// ignore_for_file: avoid_relative_lib_imports
// Controller for the browser-integration HTTP service.
//
// Owns the `BrowserIntegrationService` (the loopback HTTP server on
// 127.0.0.1:16800) and ties its lifecycle to the user's
// [BrowserIntegrationSettings.enabled] toggle. Flipping the toggle in
// Settings starts / stops the server live without a relaunch.
//
// Exposes the running state as a [bool] so widgets can show
// "Listening on…" vs "Disabled" without having to inspect the service
// directly. Also exposes the active service's stream through
// [addRequestStream] for the pendingAddRequestsProvider.
//
// Lifecycle:
//   * `main.dart` calls `BrowserIntegrationService.tryStart` once at
//     startup purely to detect "second instance" (port-bind race). If
//     it returns a service, the process is the primary and the
//     service is passed in via [initialBrowserIntegrationServiceProvider].
//   * The controller's `build()` picks up the initial service if any.
//     If the user's [enabled] setting is true, the service keeps
//     running. If false, the controller stops it immediately.
//   * Subsequent toggles in Settings start / stop the service live.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/add_request.dart';
import '../domain/browser_integration_settings.dart';
import 'browser_integration_service.dart';
import 'browser_integration_settings_provider.dart';

/// Optional initial service provided by `main.dart` after its
/// second-instance probe. The default is `null`; the controller
/// starts its own service on demand if no initial one was supplied.
final initialBrowserIntegrationServiceProvider =
    Provider<BrowserIntegrationService?>((ref) => null);

/// Port the controller binds when it has to start its own service.
/// Overridable for tests (set to `0` to bind an ephemeral port).
final browserIntegrationPortProvider =
    Provider<int>((ref) => 16800);

/// Notifier owning the browser-integration service. State is `true`
/// when the HTTP server is actually listening and `false` otherwise.
final browserIntegrationControllerProvider =
    NotifierProvider<BrowserIntegrationController, bool>(
  BrowserIntegrationController.new,
);

class BrowserIntegrationController extends Notifier<bool> {
  BrowserIntegrationService? _service;
  StreamController<AddRequest>? _passthrough;
  Future<void>? _pendingStart;

  @override
  bool build() {
    // If main.dart successfully bound the port, take ownership of
    // that service. We re-broadcast its stream through our own
    // controller so listeners can subscribe without depending on
    // the (replaceable) service instance.
    final initial = ref.read(initialBrowserIntegrationServiceProvider);
    if (initial != null) {
      _service = initial;
      _passthrough = StreamController<AddRequest>.broadcast();
      final sub = _service!.addRequestStream.listen(_passthrough!.add);
      ref.onDispose(sub.cancel);
    }

    // React to changes in the enabled toggle.
    ref.listen<AsyncValue<BrowserIntegrationSettings>>(
      browserIntegrationSettingsProvider,
      (prev, next) => next.whenData(_onSettings),
      fireImmediately: true,
    );
    ref.onDispose(_stop);
    return _service != null;
  }

  /// Called by the user (via the Settings toggle) to flip the master
  /// switch. The actual start / stop happens in the listener above.
  Future<void> setEnabled(bool v) async {
    await ref
        .read(browserIntegrationSettingsProvider.notifier)
        .apply(enabled: v);
  }

  void _onSettings(BrowserIntegrationSettings s) {
    if (s.enabled && _service == null) {
      // Fire-and-forget. The future is stored so concurrent settings
      // changes don't kick off two parallel starts.
      _pendingStart ??= _start().whenComplete(() => _pendingStart = null);
    } else if (!s.enabled && _service != null) {
      // Fire-and-forget the async stop. The state will flip to
      // false once the server's close() future resolves — see
      // _stopAsync below.
      unawaited(_stopAsync());
    }
  }

  Future<void> _start() async {
    _passthrough ??= StreamController<AddRequest>.broadcast();
    final port = ref.read(browserIntegrationPortProvider);
    final svc = await BrowserIntegrationService.tryStart(port: port);
    if (svc == null) {
      // Port already in use → another instance is the primary. We
      // are presumably the new "second instance" being launched;
      // `main.dart` will have already detected this and forwarded /
      // exited. The controller just stays in the "not running" state.
      return;
    }
    _service = svc;
    final sub = svc.addRequestStream.listen(_passthrough!.add);
    ref.onDispose(sub.cancel);
    state = true;
  }

  Future<void> _stopAsync() async {
    final svc = _service;
    _service = null;
    _passthrough?.close();
    _passthrough = null;
    if (svc != null) {
      await svc.stop();
    }
    state = false;
  }

  void _stop() {
    _service?.stop();
    _service = null;
    _passthrough?.close();
    _passthrough = null;
  }

  /// Broadcast stream that the UI's `PendingAddRequestListener`
  /// subscribes to. Always non-null but empty while the service is
  /// disabled.
  Stream<AddRequest> get addRequestStream =>
      (_passthrough ??= StreamController<AddRequest>.broadcast()).stream;
}
