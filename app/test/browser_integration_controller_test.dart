// Unit tests for BrowserIntegrationController — verify the on/off
// toggle starts and stops the underlying HTTP service.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:velocita/src/features/browser_integration/browser_integration.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePathProvider(this.dir);
  final Directory dir;

  @override
  Future<String?> getApplicationSupportPath() async => dir.path;
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('velocita_ctrl_');
    PathProviderPlatform.instance = _FakePathProvider(tmp);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Wait for the controller to flip to [expected] (or fail the test
  /// after [timeout]).
  Future<void> waitFor(
    ProviderContainer container,
    bool expected, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (container.read(browserIntegrationControllerProvider) == expected) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail(
      'controller did not reach state=$expected within $timeout '
      '(last value=${container.read(browserIntegrationControllerProvider)})',
    );
  }

  test('default state is enabled; service starts after the listener fires',
      () async {
    final container = ProviderContainer(overrides: [
      // Ephemeral port so tests can run side-by-side without
      // colliding on 16800.
      browserIntegrationPortProvider.overrideWithValue(0),
    ]);
    addTearDown(container.dispose);

    // Trigger the settings provider to load.
    await container.read(browserIntegrationSettingsProvider.future);
    // Build the controller.
    container.read(browserIntegrationControllerProvider);
    // The controller's listener fires async and calls _start(); poll
    // until the HTTP server is actually running.
    await waitFor(container, true);
  });

  test('toggling enabled=false stops the service', () async {
    final container = ProviderContainer(overrides: [
      browserIntegrationPortProvider.overrideWithValue(0),
    ]);
    addTearDown(container.dispose);

    await container.read(browserIntegrationSettingsProvider.future);
    container.read(browserIntegrationControllerProvider);
    await waitFor(container, true);

    await container
        .read(browserIntegrationSettingsProvider.notifier)
        .apply(enabled: false);
    await waitFor(container, false);
  });

  test('toggling enabled=true after disable re-starts the service',
      () async {
    final container = ProviderContainer(overrides: [
      browserIntegrationPortProvider.overrideWithValue(0),
    ]);
    addTearDown(container.dispose);

    await container.read(browserIntegrationSettingsProvider.future);
    container.read(browserIntegrationControllerProvider);
    await waitFor(container, true);

    await container
        .read(browserIntegrationSettingsProvider.notifier)
        .apply(enabled: false);
    await waitFor(container, false);

    await container
        .read(browserIntegrationSettingsProvider.notifier)
        .apply(enabled: true);
    await waitFor(container, true);
  });
}
