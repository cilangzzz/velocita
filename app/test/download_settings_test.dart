// Unit tests for the download-settings domain + provider.
//
// Covers the JSON round-trip (including backward compatibility with a
// settings.json written before proxy fields existed), the aria2
// `all-proxy` URL building (HTTP-only limitation of the engine), and
// the `changeGlobalOption` patch builder (must send numerics as
// strings — aria2 silently drops integer values).
import 'package:flutter_test/flutter_test.dart';
import 'package:velocita/src/features/settings/data/download_settings_provider.dart';
import 'package:velocita/src/features/settings/domain/download_settings.dart';

void main() {
  group('DownloadSettings JSON round-trip', () {
    test('persists every field', () {
      const s = DownloadSettings(
        saveDir: r'E:\download',
        maxConcurrentDownloads: 7,
        maxOverallDownloadLimitBytesPerSec: 512000,
        proxyKind: ProxyKind.http,
        proxyHost: '127.0.0.1',
        proxyPort: 8080,
        proxyUsername: 'alice',
        proxyPassword: 's3cret',
        proxyBypass: 'localhost,127.0.0.1',
      );
      final back = DownloadSettings.fromJson(s.toJson());
      expect(back.saveDir, r'E:\download');
      expect(back.maxConcurrentDownloads, 7);
      expect(back.maxOverallDownloadLimitBytesPerSec, 512000);
      expect(back.proxyKind, ProxyKind.http);
      expect(back.proxyHost, '127.0.0.1');
      expect(back.proxyPort, 8080);
      expect(back.proxyUsername, 'alice');
      expect(back.proxyPassword, 's3cret');
      expect(back.proxyBypass, 'localhost,127.0.0.1');
    });

    test('round-trips off as default', () {
      const s = DownloadSettings(
        saveDir: '/tmp',
        maxConcurrentDownloads: 5,
        maxOverallDownloadLimitBytesPerSec: 0,
      );
      final back = DownloadSettings.fromJson(s.toJson());
      expect(back.proxyKind, ProxyKind.off);
      expect(back.proxyHost, '');
      expect(back.proxyBypass, '');
    });

    test('reads a pre-proxy settings.json without crashing', () {
      final legacy = <String, Object?>{
        'saveDir': 'C:/dl',
        'maxConcurrentDownloads': 3,
        'maxOverallDownloadLimitBytesPerSec': 0,
      };
      final s = DownloadSettings.fromJson(legacy);
      expect(s.saveDir, 'C:/dl');
      expect(s.proxyKind, ProxyKind.off);
    });

    test('unknown proxyKind falls back to off', () {
      final s = DownloadSettings.fromJson({
        'saveDir': 'C:/dl',
        'maxConcurrentDownloads': 3,
        'maxOverallDownloadLimitBytesPerSec': 0,
        'proxyKind': 'ftp',
      });
      expect(s.proxyKind, ProxyKind.off);
    });

    test('legacy socks5 config loads but degrades to no proxy at the engine',
        () {
      final s = DownloadSettings.fromJson({
        'saveDir': 'C:/dl',
        'maxConcurrentDownloads': 3,
        'maxOverallDownloadLimitBytesPerSec': 0,
        'proxyKind': 'socks5',
        'proxyHost': '10.0.0.1',
        'proxyPort': 1080,
      });
      expect(s.proxyKind, ProxyKind.socks5);
      expect(s.buildAllProxy(), '', reason: 'engine cannot honour SOCKS5');
    });
  });

  group('buildAllProxy', () {
    test('http with auth', () {
      const s = DownloadSettings(
        saveDir: '/tmp',
        maxConcurrentDownloads: 5,
        maxOverallDownloadLimitBytesPerSec: 0,
        proxyKind: ProxyKind.http,
        proxyHost: '127.0.0.1',
        proxyPort: 8080,
        proxyUsername: 'alice',
        proxyPassword: 's3cret',
      );
      expect(s.buildAllProxy(), 'http://alice:s3cret@127.0.0.1:8080');
    });

    test('http no auth', () {
      const s = DownloadSettings(
        saveDir: '/tmp',
        maxConcurrentDownloads: 5,
        maxOverallDownloadLimitBytesPerSec: 0,
        proxyKind: ProxyKind.http,
        proxyHost: 'proxy.corp',
        proxyPort: 3128,
      );
      expect(s.buildAllProxy(), 'http://proxy.corp:3128');
    });

    test('off produces empty (no proxy)', () {
      const s = DownloadSettings(
        saveDir: '/tmp',
        maxConcurrentDownloads: 5,
        maxOverallDownloadLimitBytesPerSec: 0,
      );
      expect(s.buildAllProxy(), '');
    });

    test('socks5 is unsupported by the engine — produces empty', () {
      const s = DownloadSettings(
        saveDir: '/tmp',
        maxConcurrentDownloads: 5,
        maxOverallDownloadLimitBytesPerSec: 0,
        proxyKind: ProxyKind.socks5,
        proxyHost: '127.0.0.1',
        proxyPort: 1080,
      );
      expect(s.buildAllProxy(), '');
    });

    test('incomplete host is dropped', () {
      const s = DownloadSettings(
        saveDir: '/tmp',
        maxConcurrentDownloads: 5,
        maxOverallDownloadLimitBytesPerSec: 0,
        proxyKind: ProxyKind.http,
        proxyHost: '',
        proxyPort: 8080,
      );
      expect(s.buildAllProxy(), '');
    });

    test('invalid port is dropped', () {
      const s = DownloadSettings(
        saveDir: '/tmp',
        maxConcurrentDownloads: 5,
        maxOverallDownloadLimitBytesPerSec: 0,
        proxyKind: ProxyKind.http,
        proxyHost: '127.0.0.1',
        proxyPort: 70000,
      );
      expect(s.buildAllProxy(), '');
    });
  });

  group('buildGlobalOptionPatches', () {
    const base = DownloadSettings(
      saveDir: '/tmp',
      maxConcurrentDownloads: 5,
      maxOverallDownloadLimitBytesPerSec: 0,
    );

    test('numeric options are sent as STRINGS (aria2 drops ints)', () {
      final to = base.copyWith(
        maxConcurrentDownloads: 9,
        maxOverallDownloadLimitBytesPerSec: 1024,
        split: 8,
        maxConnectionPerServer: 8,
      );
      final patch = buildGlobalOptionPatches(base, to);
      expect(patch['max-concurrent-downloads'], '9',
          reason: 'int would be silently ignored by aria2');
      expect(patch['max-overall-download-limit'], '1024',
          reason: 'int would be silently ignored by aria2');
      expect(patch['split'], '8',
          reason: 'int would be silently ignored by aria2');
      expect(patch['max-connection-per-server'], '8',
          reason: 'int would be silently ignored by aria2');
    });

    test('split change is patched', () {
      final to = base.copyWith(split: 8);
      final patch = buildGlobalOptionPatches(base, to);
      expect(patch['split'], '8');
      expect(patch.containsKey('max-connection-per-server'), isFalse,
          reason: 'unchanged fields must not be in the patch');
    });

    test('max-connection-per-server change is patched', () {
      final to = base.copyWith(maxConnectionPerServer: 4);
      final patch = buildGlobalOptionPatches(base, to);
      expect(patch['max-connection-per-server'], '4');
      expect(patch.containsKey('split'), isFalse);
    });

    test('default split / max-conn values round-trip through JSON', () {
      // Verify a settings.json without the new fields still loads with
      // sensible defaults (5 / 5) — backward compatibility.
      final legacy = <String, Object?>{
        'saveDir': '/tmp',
        'maxConcurrentDownloads': 5,
        'maxOverallDownloadLimitBytesPerSec': 0,
      };
      final s = DownloadSettings.fromJson(legacy);
      expect(s.split, 5);
      expect(s.maxConnectionPerServer, 5);
    });

    test('autoStart + silentStart round-trip through JSON', () {
      const s = DownloadSettings(
        saveDir: '/tmp',
        maxConcurrentDownloads: 5,
        maxOverallDownloadLimitBytesPerSec: 0,
        autoStart: true,
        silentStart: true,
      );
      final back = DownloadSettings.fromJson(s.toJson());
      expect(back.autoStart, isTrue);
      expect(back.silentStart, isTrue);
    });

    test('legacy settings.json without autoStart defaults to false', () {
      // Old files written before the autostart feature must not start
      // the app at sign-in just because the field is absent.
      final s = DownloadSettings.fromJson({
        'saveDir': '/tmp',
        'maxConcurrentDownloads': 5,
        'maxOverallDownloadLimitBytesPerSec': 0,
      });
      expect(s.autoStart, isFalse);
      expect(s.silentStart, isFalse);
    });

    test('no patch when nothing changed', () {
      expect(buildGlobalOptionPatches(base, base), isEmpty);
    });

    test('dir patch is a plain string path', () {
      final to = base.copyWith(saveDir: r'E:\download');
      final patch = buildGlobalOptionPatches(base, to);
      expect(patch['dir'], r'E:\download');
    });

    test('enabling an HTTP proxy pushes all-proxy', () {
      final to = base.copyWith(
        proxyKind: ProxyKind.http,
        proxyHost: '127.0.0.1',
        proxyPort: 8080,
      );
      final patch = buildGlobalOptionPatches(base, to);
      expect(patch['all-proxy'], 'http://127.0.0.1:8080');
    });

    test('disabling a proxy clears all-proxy', () {
      final withProxy = base.copyWith(
        proxyKind: ProxyKind.http,
        proxyHost: '127.0.0.1',
        proxyPort: 8080,
        proxyBypass: 'localhost',
      );
      final patch = buildGlobalOptionPatches(withProxy, base);
      expect(patch['all-proxy'], '');
      expect(patch['no-proxy'], '');
    });

    test('socks5 produces no all-proxy patch', () {
      final to = base.copyWith(
        proxyKind: ProxyKind.socks5,
        proxyHost: '127.0.0.1',
        proxyPort: 1080,
      );
      final patch = buildGlobalOptionPatches(base, to);
      expect(patch.containsKey('all-proxy'), isFalse,
          reason: 'aria2 cannot honour SOCKS5; do not push it');
    });
  });
}
