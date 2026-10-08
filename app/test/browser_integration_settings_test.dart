// Unit tests for BrowserIntegrationSettings JSON round-trip + defaults.
import 'package:flutter_test/flutter_test.dart';
import 'package:velocita/src/features/browser_integration/domain/browser_integration_settings.dart';

void main() {
  group('BrowserIntegrationSettings', () {
    test('defaults', () {
      const s = BrowserIntegrationSettings();
      expect(s.enabled, true);
      expect(s.showConfirmationPopup, true);
      expect(s.port, BrowserIntegrationSettings.defaultPort);
      expect(s.installedBrowsers, isEmpty);
    });

    test('toJson round-trips through fromJson', () {
      const original = BrowserIntegrationSettings(
        enabled: false,
        showConfirmationPopup: false,
        port: 17000,
        installedBrowsers: {BrowserKind.chrome, BrowserKind.firefox},
      );
      final j = original.toJson();
      final copy = BrowserIntegrationSettings.fromJson(j);
      expect(copy.enabled, false);
      expect(copy.showConfirmationPopup, false);
      expect(copy.port, 17000);
      expect(copy.installedBrowsers,
          {BrowserKind.chrome, BrowserKind.firefox});
    });

    test('fromJson defaults enabled to true when the key is missing', () {
      final s = BrowserIntegrationSettings.fromJson({});
      expect(s.enabled, true);
    });

    test('fromJson clamps an out-of-range port', () {
      final s = BrowserIntegrationSettings.fromJson({'port': 99});
      expect(s.port, BrowserIntegrationSettings.minPort);
      final tooHigh =
          BrowserIntegrationSettings.fromJson({'port': 99999999});
      expect(tooHigh.port, BrowserIntegrationSettings.maxPort);
    });

    test('fromJson drops unknown BrowserKind names', () {
      final s = BrowserIntegrationSettings.fromJson({
        'installedBrowsers': ['chrome', 'brave', 'firefox'],
      });
      expect(s.installedBrowsers, {BrowserKind.chrome, BrowserKind.firefox});
    });

    test('fromJson tolerates a missing installedBrowsers field', () {
      final s = BrowserIntegrationSettings.fromJson({'port': 16800});
      expect(s.installedBrowsers, isEmpty);
    });

    test('copyWith preserves unspecified fields', () {
      const original = BrowserIntegrationSettings(
        enabled: false,
        showConfirmationPopup: false,
        port: 17000,
        installedBrowsers: {BrowserKind.edge},
      );
      final next = original.copyWith(port: 17500);
      expect(next.enabled, false);
      expect(next.showConfirmationPopup, false);
      expect(next.port, 17500);
      expect(next.installedBrowsers, {BrowserKind.edge});
    });

    test('copyWith enabled=true flips a previously-disabled setting', () {
      const original = BrowserIntegrationSettings(enabled: false);
      expect(original.copyWith(enabled: true).enabled, true);
    });
  });
}
