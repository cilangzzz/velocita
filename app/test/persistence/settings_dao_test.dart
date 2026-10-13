// Unit tests for the settings + browser-integration DAOs.
import 'package:flutter_test/flutter_test.dart';
import 'package:velocita/src/features/settings/domain/download_settings.dart';
// Drift codegen re-exports the table class under the same name;
// import only the row / DAO types we need here.
import 'package:velocita/src/persistence/database.dart' show AppDatabase;
import 'package:velocita/src/persistence/defaults.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  test('all() is empty on a fresh DB', () async {
    expect(await db.downloadSettingsDao.all(), isEmpty);
  });

  test('put / valueOf round-trip', () async {
    await db.downloadSettingsDao.put('saveDir', 'C:\\d');
    expect(await db.downloadSettingsDao.valueOf('saveDir'), 'C:\\d');
  });

  test('putAll inserts many keys in one transaction', () async {
    await db.downloadSettingsDao.putAll({
      'saveDir': 'D',
      'maxConcurrentDownloads': '8',
      'proxyKind': 'off',
    });
    final all = await db.downloadSettingsDao.all();
    expect(all['saveDir'], 'D');
    expect(all['maxConcurrentDownloads'], '8');
    expect(all['proxyKind'], 'off');
  });

  test('put on an existing key overwrites (no duplicate row)', () async {
    await db.downloadSettingsDao.put('saveDir', 'A');
    await db.downloadSettingsDao.put('saveDir', 'B');
    expect((await db.downloadSettingsDao.all())['saveDir'], 'B');
  });

  test('DownloadSettings round-trip via key/value helpers', () async {
    const original = DownloadSettingsFixture(
      saveDir: 'C:\\d',
      maxConcurrentDownloads: 7,
      proxyKind: 'http',
      proxyHost: 'h',
      proxyPort: 8080,
    );
    await db.downloadSettingsDao.putAll(settingsKeyValue(_from(original)));
    final back = downloadSettingsFromMap(
      await db.downloadSettingsDao.all(),
      fallbackSaveDir: 'fallback',
    );
    expect(back.saveDir, 'C:\\d');
    expect(back.maxConcurrentDownloads, 7);
    expect(back.proxyKind, ProxyKind.http);
    expect(back.proxyHost, 'h');
    expect(back.proxyPort, 8080);
  });

  test('BrowserIntegrationDao.all() empty by default', () async {
    expect(await db.browserIntegrationDao.all(), isEmpty);
  });

  test('BrowserIntegrationDao.put / all round-trip', () async {
    await db.browserIntegrationDao.put('enabled', 'false');
    await db.browserIntegrationDao.put('port', '17000');
    final all = await db.browserIntegrationDao.all();
    expect(all['enabled'], 'false');
    expect(all['port'], '17000');
  });
}

// Minimal local fixtures (avoid pulling the domain types into this
// file just for a value object — the test really only cares about
// the key/value mapping).
class DownloadSettingsFixture {
  const DownloadSettingsFixture({
    required this.saveDir,
    required this.maxConcurrentDownloads,
    required this.proxyKind,
    this.proxyHost = '',
    this.proxyPort = 0,
  });
  final String saveDir;
  final int maxConcurrentDownloads;
  final String proxyKind;
  final String proxyHost;
  final int proxyPort;
}

enum ProxyKindFixture { off, http, socks5 }

dynamic _from(DownloadSettingsFixture f) {
  // Build a real DownloadSettings via the existing constructor,
  // passing the fixture's fields through.
  return DownloadSettings(
    saveDir: f.saveDir,
    maxConcurrentDownloads: f.maxConcurrentDownloads,
    maxOverallDownloadLimitBytesPerSec: 0,
    proxyKind: _toProxy(f.proxyKind),
    proxyHost: f.proxyHost,
    proxyPort: f.proxyPort,
  );
}

ProxyKind _toProxy(String name) {
  for (final k in ProxyKind.values) {
    if (k.name == name) return k;
  }
  return ProxyKind.off;
}
