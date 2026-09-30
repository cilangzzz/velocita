// ignore_for_file: avoid_relative_lib_imports
// Deep-link registry: velocita://add?url=... and velocita://open/<id>
//
// app_links package gives us a single Stream<Uri> for the platform's
// deep-link events (Windows: registry + protocol handlers; macOS:
// Info.plist URL scheme; Linux: .desktop file).
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:logging/logging.dart';

class DeepLinkHandler {
  DeepLinkHandler._(this._appLinks);

  final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;

  static Future<DeepLinkHandler> init({
    required void Function(Uri uri) onLink,
  }) async {
    final handler = DeepLinkHandler._(AppLinks());
    handler._sub = handler._appLinks.uriLinkStream.listen((uri) {
      Logger('Velocita.DeepLink').info('received $uri');
      onLink(uri);
    });
    return handler;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
  }
}

/// Returns true for `velocita://add?url=...` style links.
bool isAddTaskLink(Uri uri) =>
    uri.scheme == 'velocita' &&
    (uri.host == 'add' || uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'add');

String? extractUrl(Uri uri) {
  if (!isAddTaskLink(uri)) return null;
  return uri.queryParameters['url'];
}
