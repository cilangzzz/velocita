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
//   * On startup, the controller also checks for an `velocita://`
//     deep link in argv (the OS-launched wake-up case when Velocita
//     was not already running). If one is found it is enqueued once
//     both the service is up and the listener is subscribed.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/add_request.dart';
import '../domain/browser_integration_settings.dart';
import 'browser_integration_service.dart';
import 'browser_integration_settings_provider.dart';
import 'host_bridge.dart';
import 'host_installer.dart';

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

  /// Resolves when the HTTP service is up and ready to accept
  /// enqueues. Used by the initial-deep-link watcher to wait until
  /// enqueuing is safe (i.e. an active listener is subscribed).
  /// Replaced on every stop so the next `_start()` resolves a fresh
  /// future for the next-generation service.
  Completer<BrowserIntegrationService> _ready =
      Completer<BrowserIntegrationService>();

  /// Set to true after we've already kicked off the initial-deep-link
  /// check, so we don't re-check on every `build()`.
  bool _initialChecked = false;

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
      if (!_ready.isCompleted) _ready.complete(initial);
    }

    // Kick off the initial-deep-link check exactly once. The actual
    // check is async; the result is held until the service is up.
    if (!_initialChecked) {
      _initialChecked = true;
      _consumeInitialDeepLink();
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
    // Keep the OS-level "browser startup program" entry in sync with
    // the enabled toggle, independent of whether the local service is
    // currently running. Self-healing: a stale exe path in the Run
    // value gets refreshed on every settings load.
    unawaited(_syncStartupProgram(s.enabled));
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

  Future<void> _syncStartupProgram(bool enabled) async {
    try {
      if (enabled) {
        await ensureBrowserStartupProgram();
      } else {
        await removeBrowserStartupProgram();
      }
    } catch (e) {
      // Don't fail the controller on a registry hiccup — the user can
      // still toggle the feature off and the next launch will retry.
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
    if (!_ready.isCompleted) _ready.complete(svc);
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
    // The service is gone; swap in a fresh completer so the next
    // `_start()` can re-resolve any future `await _ready.future`.
    if (_ready.isCompleted) _ready = Completer<BrowserIntegrationService>();
  }

  void _stop() {
    _service?.stop();
    _service = null;
    _passthrough?.close();
    _passthrough = null;
  }

  /// Check the OS-spawned argv for a `velocita://add?url=…` link and
  /// enqueue it once the service is up. The controller is the right
  /// place for this: it owns the service, and the enqueue is what
  /// shows the dialog in the listener.
  Future<void> _consumeInitialDeepLink() async {
    final link = await readInitialDeepLink();
    if (link == null) return;
    // Wait until the service is up before enqueueing. If the
    // listener hasn't subscribed yet (it's set up in
    // `initState`), the broadcast stream would drop the event.
    await _ready.future;
    // One microtask tick so the widget tree has a chance to mount
    // and the listener to subscribe.
    await Future<void>.delayed(Duration.zero);
    // Re-check: the user could have toggled the service off
    // between our read and this enqueue.
    if (_service == null) return;
    _service!.enqueue(AddRequest(
      url: link.url,
      source: AddSource.deepLink,
      receivedAt: DateTime.now(),
      referer: link.referer,
      tabTitle: link.tabTitle,
    ));
  }

  /// Broadcast stream that the UI's `PendingAddRequestListener`
  /// subscribes to. Always non-null but empty while the service is
  /// disabled.
  Stream<AddRequest> get addRequestStream =>
      (_passthrough ??= StreamController<AddRequest>.broadcast()).stream;
}
