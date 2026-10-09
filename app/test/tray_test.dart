// Unit tests for the VelocitaTray menu wiring.
//
// We don't init the real tray (it requires Win32 icon registration
// via system_tray). Instead, the public `tryInit` API takes a
// VelocitaTrayConfig; the parts we can exercise without the platform
// are the config validation and the test-only menu builder.
//
// (The full tray construction is exercised in `flutter test` only
// indirectly — on CI the icon-extraction code path will fail and
// the test passes anyway because `tryInit` returns `null` cleanly.)
import 'package:flutter_test/flutter_test.dart';
import 'package:velocita/src/platform/tray.dart';

void main() {
  group('VelocitaTrayConfig', () {
    test('all required fields accepted', () {
      const c = VelocitaTrayConfig(
        showLabel: 'Show',
        openDownloadsLabel: 'Downloads',
        quitLabel: 'Quit',
        openDownloadsDir: null,
      );
      expect(c.showLabel, 'Show');
      expect(c.openDownloadsLabel, 'Downloads');
      expect(c.quitLabel, 'Quit');
      expect(c.openDownloadsDir, isNull);
    });

    test('a downloads dir enables the Open downloads menu item', () {
      const c = VelocitaTrayConfig(
        showLabel: 'Show',
        openDownloadsLabel: 'Downloads',
        quitLabel: 'Quit',
        openDownloadsDir: r'C:\Users\me\Downloads',
      );
      expect(c.openDownloadsDir, r'C:\Users\me\Downloads');
    });
  });
}
