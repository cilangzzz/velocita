// Unit tests for the download-settings domain + provider.
//
// Covers the JSON round-trip (including backward compatibility with a
// settings.json written before proxy fields existed) and the aria2
// `all-proxy` URL building, which is the piece that encodes the
// HTTP-only limitation of the engine.
import 'package:flutter_test/flutter_test.dart';
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
        'proxyKind': 'socks5',
        'proxyHost': '10.0.0.1',
        'proxyPort': 1080,
      });
      expect(s.proxyKind, ProxyKind.off);
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
}
