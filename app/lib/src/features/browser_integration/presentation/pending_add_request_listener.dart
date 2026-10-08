// ignore_for_file: use_build_context_synchronously
// All `BuildContext` instances we use are obtained via
// `widget.navigatorKey.currentContext`, which is a `GlobalKey<NavigatorState>`.
// The async-gap check is therefore a false positive — a global key's
// context is not bound to a widget's lifecycle. We re-`mounted`-check
// around the showDialog call as a belt-and-suspenders guard.
import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../downloads/downloads.dart';
import '../data/browser_integration_settings_provider.dart';
import '../data/pending_add_requests_provider.dart';
import '../domain/add_request.dart';
import '../domain/browser_integration_settings.dart';

class PendingAddRequestListener extends ConsumerStatefulWidget {
  const PendingAddRequestListener({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  ConsumerState<PendingAddRequestListener> createState() =>
      _PendingAddRequestListenerState();
}

class _PendingAddRequestListenerState
    extends ConsumerState<PendingAddRequestListener> {
  final Queue<_PendingItem> _queue = Queue<_PendingItem>();
  final Map<String, DateTime> _recentlySeen = <String, DateTime>{};
  bool _busy = false;
  StreamSubscription<AddRequest>? _sub;
  ProviderSubscription<AsyncValue<AddRequest>>? _providerSub;

  @override
  void initState() {
    super.initState();
    // We use a provider subscription instead of `.stream` so we get
    // AsyncValue semantics (loading/error) and the deprecation warning
    // goes away.
    _providerSub = ref.listenManual<AsyncValue<AddRequest>>(
      pendingAddRequestsProvider,
      (_, next) {
        next.whenData(_onRequest);
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _providerSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _onRequest(AddRequest r) {
    if (!_isRecentDuplicate(r)) {
      _queue.add(_PendingItem(r, DateTime.now()));
      _drain();
    }
  }

  bool _isRecentDuplicate(AddRequest r) {
    // Fingerprint = (source, url). We don't have a `dedupKey` on the
    // wire in v1, so this is the next-best thing — it collapses
    // double-clicks of the toolbar icon on the same link.
    final key = '${r.source.name}|${r.url}';
    final now = DateTime.now();
    // Garbage-collect stale entries.
    _recentlySeen.removeWhere(
      (_, t) => now.difference(t) > AddRequest.dedupWindow,
    );
    final last = _recentlySeen[key];
    if (last != null && now.difference(last) <= AddRequest.dedupWindow) {
      return true;
    }
    _recentlySeen[key] = now;
    return false;
  }

  Future<void> _drain() async {
    if (_busy) return;
    _busy = true;
    try {
      while (_queue.isNotEmpty && mounted) {
        final item = _queue.removeFirst();
        await _processOne(item.request);
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _processOne(AddRequest r) async {
    final settings = ref.read(browserIntegrationSettingsProvider).value ??
        const BrowserIntegrationSettings();
    if (settings.showConfirmationPopup) {
      await _showConfirmDialog(r);
    } else {
      await _autoAdd(r);
    }
  }

  Future<void> _showConfirmDialog(AddRequest r) async {
    // If the window is hidden (the user closed it earlier but the
    // process is still alive in the tray, serving browser deep
    // links), bring it forward. The dialog can be scheduled into
    // a hidden window but the user can't see it, so we MUST show +
    // focus first.
    final ctx = widget.navigatorKey.currentContext;
    if (ctx == null) return;
    await _ensureWindowVisible();
    if (!mounted) return;
    // `ctx` is a global navigator key's currentContext, not a widget
    // BuildContext; the async gap (`_ensureWindowVisible()`) does
    // not invalidate it, and `mounted` was rechecked above.
    final result = await showDialog<SubmitResult>(
      context: ctx,
      barrierDismissible: true,
      builder: (_) => AddTaskDialog(initialUrl: r.url),
    );
    if (result == null) return; // user dismissed
    await _applyResult(result);
  }

  Future<void> _autoAdd(AddRequest r) async {
    final ctx = widget.navigatorKey.currentContext;
    if (ctx == null) return;
    await _ensureWindowVisible();
    if (!mounted) return;
    try {
      await ref.read(taskListProvider.notifier).addUri(
            r.url,
            aria2Options: _toAria2Options(r),
          );
    } catch (e) {
      _showSnack('Failed to add: $e');
      return;
    }
    _showSnack('Added: ${r.url}');
  }

  Future<void> _ensureWindowVisible() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {
      // Window manager isn't always available (tests, hot reload).
      // Silently no-op; the dialog can still be scheduled.
    }
  }

  Future<void> _applyResult(SubmitResult r) async {
    final notifier = ref.read(taskListProvider.notifier);
    switch (r.kind) {
      case SubmitKind.url:
        await notifier.addUri(r.url!, saveDir: r.saveDir);
      case SubmitKind.magnet:
        await notifier.addMagnet(r.magnet!, saveDir: r.saveDir);
      case SubmitKind.torrent:
        await notifier.addTorrent(r.torrentBytes!, saveDir: r.saveDir);
    }
  }

  /// Translate an [AddRequest] (extension-side wire shape) into the
  /// aria2 options map expected by `Aria2RpcClient.addUri`:
  ///   * `referer` — only when the request carried a non-empty referer.
  ///   * `header` — array form so multiple overrides stack cleanly.
  ///     Cookie comes first (folded from [AddRequest.cookieHeader]),
  ///     followed by any explicit [AddRequest.requestHeaders].
  ///
  /// Returns `null` when no overrides are needed — the caller can detect
  /// that and skip merging.
  Map<String, Object?>? _toAria2Options(AddRequest r) {
    final m = <String, Object?>{};
    if (r.referer != null && r.referer!.isNotEmpty) {
      m['referer'] = r.referer;
    }
    final headers = <String>[];
    if (r.cookieHeader != null && r.cookieHeader!.isNotEmpty) {
      headers.add('Cookie: ${r.cookieHeader}');
    }
    if (r.requestHeaders != null) headers.addAll(r.requestHeaders!);
    if (headers.isNotEmpty) m['header'] = headers;
    return m.isEmpty ? null : m;
  }

  void _showSnack(String text) {
    final ctx = widget.navigatorKey.currentContext;
    if (ctx == null) return;
    final messenger = ScaffoldMessenger.maybeOf(ctx);
    messenger?.showSnackBar(SnackBar(content: Text(text)));
  }
}

class _PendingItem {
  _PendingItem(this.request, this.enqueuedAt);
  final AddRequest request;
  final DateTime enqueuedAt;
}
