// ignore_for_file: avoid_relative_lib_imports
// StreamProvider exposing the BrowserIntegrationController's
// AddRequest stream to the UI layer.
//
// Reads from the controller rather than the raw service so the stream
// is always present (never null) — when the service is disabled the
// stream is simply empty.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/add_request.dart';
import 'browser_integration_controller.dart';

/// Broadcast stream of incoming `AddRequest`s — one for each
/// `velocita://add?url=…` deep link, browser-extension toolbar click,
/// context-menu "Download with Velocita" click, or HTTP `POST /api/add`
/// from a non-Native-Messaging client.
///
/// Always emits; empty when the browser-integration feature is
/// disabled via the Settings toggle.
final pendingAddRequestsProvider = StreamProvider<AddRequest>((ref) {
  final controller = ref.watch(browserIntegrationControllerProvider.notifier);
  return controller.addRequestStream;
});
