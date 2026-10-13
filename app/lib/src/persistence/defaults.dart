/// Default seed data for each domain. Each function is a pure
/// builder (no IO) so the DAOs can call them on first read, and
/// tests can verify the seed shape without touching the database.
///
/// Convention: every "empty table → defaults" code path lives in
/// the corresponding DAO, not in `onCreate`. That keeps test
/// instances free of pre-populated rows unless they explicitly
/// trigger the seed.
library;

import '../features/browser_integration/domain/browser_integration_settings.dart';
import '../features/categories/domain/category.dart';
import '../features/categories/domain/classification_rule.dart';
import '../features/downloads/domain/download_task.dart';
import '../features/downloads/presentation/columns_provider.dart';
import '../features/settings/domain/download_settings.dart';
// Drift's codegen generates wrapper classes that share the
// domain type names; import only the row/companion types we
// actually need to keep the symbol table unambiguous.
import 'database.dart' show DownloadRow, CategoryRow, ColumnLayoutRow, ClassificationRuleRow;

/// Convert a domain [DownloadTask] snapshot (gid + filename + …)
/// to the DB row that stores it. `updatedAt` is set to the moment
/// of the call so the diff machinery can detect "changed since
/// last batch".
DownloadRow downloadRowFromSummary(TaskSummary t, {DateTime? updatedAt}) {
  return DownloadRow(
    gid: t.gid,
    filename: t.filename,
    totalLength: t.totalLength,
    completedLength: t.completedLength,
    status: t.status.name,
    downloadSpeed: t.downloadSpeed,
    dir: t.dir,
    errorCode: t.errorCode,
    errorMessage: t.errorMessage,
    addedAt: t.addedAt,
    completedAt: t.completedAt,
    sourceUrl: t.sourceUrl,
    updatedAt: updatedAt ?? DateTime.now(),
  );
}

TaskSummary taskSummaryFromRow(DownloadRow r) {
  return TaskSummary(
    gid: r.gid,
    filename: r.filename,
    totalLength: r.totalLength,
    completedLength: r.completedLength,
    status: parseStatus(r.status),
    downloadSpeed: r.downloadSpeed,
    dir: r.dir,
    errorCode: r.errorCode,
    errorMessage: r.errorMessage,
    addedAt: r.addedAt,
    completedAt: r.completedAt,
    sourceUrl: r.sourceUrl,
  );
}

// ── Category seed ─────────────────────────────────────────────

/// The 7 default categories from [Category.defaults], expanded
/// into the 3 related tables (categories + extensions + sites).
/// Caller is responsible for inserting via the DAO (or via
/// [seedDefaultCategories] for a one-shot seed on empty table).
List<({CategoryRow row, List<String> extensions, List<String> sites})>
    defaultCategorySeed(String downloadDir) {
  final cats = Category.defaults(downloadDir);
  return [
    for (var i = 0; i < cats.length; i++)
      (
        row: CategoryRow(
          id: cats[i].id,
          name: cats[i].name,
          parentId: cats[i].parentId,
          defaultSaveDir: cats[i].defaultSaveDir,
          isDefault: cats[i].isDefault,
          iconName: cats[i].iconName,
          sortOrder: i,
        ),
        extensions: cats[i].extensions,
        sites: cats[i].sites,
      ),
  ];
}

// ── Column seed ───────────────────────────────────────────────

/// All 6 default columns from [kTableColumns], in their canonical
/// order. Filename is always first and always visible.
List<ColumnLayoutRow> defaultColumnSeed() {
  return [
    for (var i = 0; i < kTableColumns.length; i++)
      ColumnLayoutRow(
        columnId: kTableColumns[i].id.name,
        sortOrder: i,
        visible: true,
      ),
  ];
}

// ── Settings seed ─────────────────────────────────────────────

/// The 14 scalar fields of [DownloadSettings] flattened to a
/// `key → JSON-encoded value` map. Persisted as individual rows
/// in `download_settings` so partial updates don't have to
/// rewrite the whole snapshot.
Map<String, String> settingsKeyValue(DownloadSettings s) {
  return {
    'saveDir': s.saveDir,
    'maxConcurrentDownloads': '${s.maxConcurrentDownloads}',
    'maxOverallDownloadLimitBytesPerSec':
        '${s.maxOverallDownloadLimitBytesPerSec}',
    'proxyKind': s.proxyKind.name,
    'proxyHost': s.proxyHost,
    'proxyPort': '${s.proxyPort}',
    'proxyUsername': s.proxyUsername,
    'proxyPassword': s.proxyPassword,
    'proxyBypass': s.proxyBypass,
    'split': '${s.split}',
    'maxConnectionPerServer': '${s.maxConnectionPerServer}',
    'autoStart': '${s.autoStart}',
    'silentStart': '${s.silentStart}',
    'startHiddenToTray': '${s.startHiddenToTray}',
  };
}

/// Inverse of [settingsKeyValue]. Missing keys fall back to
/// the existing snapshot's value, then to the default — so a
/// partial DB (older schema missing `autoStart` etc.) upgrades
/// in place without losing user data.
DownloadSettings downloadSettingsFromMap(
  Map<String, String> kv, {
  String fallbackSaveDir = '',
  DownloadSettings? base,
}) {
  String s(String k) => kv[k] ?? (base == null ? '' : _readFromBase(base, k));
  int i(String k) => int.tryParse(kv[k] ?? '') ?? _readIntFromBase(base, k);
  bool b(String k) {
    final raw = kv[k];
    if (raw != null) return raw == 'true';
    return _readBoolFromBase(base, k);
  }

  return DownloadSettings(
    saveDir: s('saveDir').isEmpty ? fallbackSaveDir : s('saveDir'),
    maxConcurrentDownloads: i('maxConcurrentDownloads') == 0
        ? DownloadSettings.defaultMaxConcurrent
        : i('maxConcurrentDownloads'),
    maxOverallDownloadLimitBytesPerSec: i('maxOverallDownloadLimitBytesPerSec'),
    proxyKind: _parseProxyKind(s('proxyKind')),
    proxyHost: s('proxyHost'),
    proxyPort: i('proxyPort'),
    proxyUsername: s('proxyUsername'),
    proxyPassword: s('proxyPassword'),
    proxyBypass: s('proxyBypass'),
    split: i('split') == 0 ? DownloadSettings.defaultSplit : i('split'),
    maxConnectionPerServer: i('maxConnectionPerServer') == 0
        ? DownloadSettings.defaultMaxConnPerServer
        : i('maxConnectionPerServer'),
    autoStart: b('autoStart'),
    silentStart: b('silentStart'),
    startHiddenToTray: b('startHiddenToTray'),
  );
}

String _readFromBase(DownloadSettings b, String k) {
  switch (k) {
    case 'saveDir': return b.saveDir;
    case 'proxyHost': return b.proxyHost;
    case 'proxyUsername': return b.proxyUsername;
    case 'proxyPassword': return b.proxyPassword;
    case 'proxyBypass': return b.proxyBypass;
    case 'proxyKind': return b.proxyKind.name;
  }
  return '';
}

int _readIntFromBase(DownloadSettings? b, String k) {
  if (b == null) return 0;
  switch (k) {
    case 'maxConcurrentDownloads': return b.maxConcurrentDownloads;
    case 'maxOverallDownloadLimitBytesPerSec': return b.maxOverallDownloadLimitBytesPerSec;
    case 'proxyPort': return b.proxyPort;
    case 'split': return b.split;
    case 'maxConnectionPerServer': return b.maxConnectionPerServer;
  }
  return 0;
}

bool _readBoolFromBase(DownloadSettings? b, String k) {
  if (b == null) return false;
  switch (k) {
    case 'autoStart': return b.autoStart;
    case 'silentStart': return b.silentStart;
    case 'startHiddenToTray': return b.startHiddenToTray;
  }
  return false;
}

ProxyKind _parseProxyKind(String raw) {
  for (final k in ProxyKind.values) {
    if (k.name == raw) return k;
  }
  return ProxyKind.off;
}

// ── Browser integration seed ──────────────────────────────────

Map<String, String> browserIntegrationKeyValue(
    BrowserIntegrationSettings s) {
  return {
    'enabled': '${s.enabled}',
    'showConfirmationPopup': '${s.showConfirmationPopup}',
    'port': '${s.port}',
    'installedBrowsers':
        s.installedBrowsers.map((b) => b.name).toList().join(','),
  };
}

BrowserIntegrationSettings browserIntegrationFromMap(
    Map<String, String> kv) {
  String s(String k) => kv[k] ?? '';
  bool b(String k) => (kv[k] ?? 'true') == 'true';
  int i(String k) => int.tryParse(kv[k] ?? '') ?? 0;
  final port = i('port').clamp(
        BrowserIntegrationSettings.minPort,
        BrowserIntegrationSettings.maxPort,
      );
  final installedNames = s('installedBrowsers')
      .split(',')
      .where((n) => n.isNotEmpty)
      .toSet();
  return BrowserIntegrationSettings(
    enabled: b('enabled'),
    showConfirmationPopup: b('showConfirmationPopup'),
    port: port == 0 ? BrowserIntegrationSettings.defaultPort : port,
    installedBrowsers: {
      for (final n in installedNames)
        if (BrowserKind.values.any((k) => k.name == n))
          BrowserKind.values.firstWhere((k) => k.name == n),
    },
  );
}

// ── Classification rules (no seed; users add their own) ───────

ClassificationRule classificationRuleFromRow(ClassificationRuleRow r) {
  return ClassificationRule(
    id: r.id,
    categoryId: r.categoryId,
    pattern: r.pattern,
    flavor: RuleFlavor.values.firstWhere(
      (f) => f.name == r.flavor,
      orElse: () => RuleFlavor.extension,
    ),
    priority: r.priority,
    source: RuleSource.values.firstWhere(
      (s) => s.name == r.source,
      orElse: () => RuleSource.userDefined,
    ),
  );
}

ClassificationRuleRow classificationRuleToRow(ClassificationRule r) {
  return ClassificationRuleRow(
    id: r.id,
    categoryId: r.categoryId,
    pattern: r.pattern,
    flavor: r.flavor.name,
    priority: r.priority,
    source: r.source.name,
  );
}
