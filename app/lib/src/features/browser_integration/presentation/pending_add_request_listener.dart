// ignore_for_file: use_build_context_synchronously
// All `BuildContext` instances we use are obtained via
// `widget.navigatorKey.currentContext`, which is a `GlobalKey<NavigatorState>`.
// The async-gap check is therefore a false positive — a global key
// context is not bound to a widget lifecycle. We re-`mounted`-check
// around the showDialog call as a belt-and-suspenders guard.
import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../downloads/downloads.dart';
import '../data/browser_integration_settings_provider.dart';
import '../data/pending_add_requests_provider.dart';
import '../data/window_bridge.dart';
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
  StreamSubscription<AddTaskResult>? _resultSub;

  @override
  void initState() {
    super.initState();
    _providerSub = ref.listenManual<AsyncValue<AddRequest>>(
      pendingAddRequestsProvider,
      (_, next) {
        next.whenData(_onRequest);
      },
      fireImmediately: true,
    );
    _resultSub = onSubWindowAddTaskResult.listen(_onSubWindowResult);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _providerSub?.close();
    _resultSub?.cancel();
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
    final key = '${r.source.name}|${r.url}';
    final now = DateTime.now();
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
      await _spawnSubWindow(r);
    } else {
      await _autoAdd(r);
    }
  }

  /// Spawn an Add-Task sub-window. The sub-window is its own OS
  /// window (independent Flutter engine) — the main app's content
  /// stays in the tray. The sub-window IPCs the result back via
  /// `addTaskResultHandler`, which the listener has subscribed to
  /// in [initState] and dispatches to [_onSubWindowResult].
  ///
  /// Note: deliberately does NOT call `_ensureWindowVisible()` — the
  /// whole point of the sub-window is that the main app stays in
  /// the tray.
  Future<void> _spawnSubWindow(AddRequest r) async {
    if (!mounted) return;
    await spawnAddTaskSubWindow(r);
  }

  Future<void> _onSubWindowResult(AddTaskResult result) async {
    await ipcLog(
      '_onSubWindowResult: cancelled=${result.cancelled} '
      'submit=${result.submit != null}',
    );
    if (result.cancelled || result.submit == null) return;
    await _applyResult(result.submit!);
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
      await _restoreZOrder();
      return;
    }
    _showSnack('Added: ${r.url}');
    await _restoreZOrder();
  }

  Future<void> _ensureWindowVisible() async {
    try {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setAlwaysOnTop(true);
    } catch (_) {}
  }

  Future<void> _restoreZOrder() async {
    try {
      await windowManager.setAlwaysOnTop(false);
    } catch (_) {}
  }

  Future<void> _applyResult(SubmitResult r) async {
    await ipcLog(
      '_applyResult: kind=${r.kind.name} url=${r.url} '
      'magnet=${r.magnet} saveDir=${r.saveDir}',
    );
    final notifier = ref.read(taskListProvider.notifier);
    try {
      switch (r.kind) {
        case SubmitKind.url:
          await notifier.addUri(r.url!, saveDir: r.saveDir);
        case SubmitKind.magnet:
          await notifier.addMagnet(r.magnet!, saveDir: r.saveDir);
        case SubmitKind.torrent:
          await notifier.addTorrent(r.torrentBytes!, saveDir: r.saveDir);
      }
      await ipcLog('_applyResult: added OK');
    } catch (e, st) {
      await ipcLog('_applyResult: FAILED $e\n$st');
      rethrow;
    }
  }

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
