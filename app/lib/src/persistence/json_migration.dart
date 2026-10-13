/// One-time migration from the 5 old JSON files to the new
/// `velocita.db`. Run on app boot, before any provider's `build()`
/// reads from the DB.
///
/// Strategy: for each of the 5 source files, if it exists and
/// parses, insert the rows into the matching tables. Any
/// individual file's failure is logged and skipped — the other
/// features still migrate. After every file is processed
/// (success or fail), the originals are deleted; the user has
/// explicitly asked for no backup.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../features/browser_integration/domain/browser_integration_settings.dart';
import '../features/categories/domain/category.dart' as cat_domain;
import '../features/categories/domain/classification_rule.dart';
import '../features/downloads/domain/download_task.dart';
import '../features/downloads/presentation/columns_provider.dart';
import '../features/settings/domain/download_settings.dart';
import 'database.dart' show AppDatabase, DownloadRow, CategoryRow, ColumnLayoutRow;
import 'defaults.dart';

final _log = Logger('velocita.json_migration');

/// Run the migration. Idempotent: a non-empty DB short-circuits
/// to a no-op so re-running the app doesn't churn the data.
Future<void> migrateJsonToDb(AppDatabase db, Directory dataDir) async {
  // Cheap fast-path: if any of the 3 "user has data" tables has a
  // row, we've already migrated (or the user populated the DB by
  // some other means). Either way, the JSON files would be stale.
  final alreadyMigrated = (await db.downloadsDao.all()).isNotEmpty ||
      (await db.categoriesDao.allCategories()).isNotEmpty ||
      (await db.columnsDao.all()).isNotEmpty;
  if (alreadyMigrated) {
    // Even if we already migrated once, sweep any straggler
    // JSON files left over from a previous partial run.
    await _deleteJsonFiles(dataDir);
    return;
  }

  await _tryFile(dataDir, 'history.json', () => _migrateDownloads(db, dataDir));
  await _tryFile(
      dataDir, 'categories.json', () => _migrateCategories(db, dataDir));
  await _tryFile(dataDir, 'settings.json', () => _migrateSettings(db, dataDir));
  await _tryFile(dataDir, 'columns.json', () => _migrateColumns(db, dataDir));
  await _tryFile(
      dataDir, 'browser-integration.json', () => _migrateBrowserIntegration(db, dataDir));

  await _deleteJsonFiles(dataDir);
}

const _jsonFilesToDelete = [
  'history.json',
  'categories.json',
  'settings.json',
  'columns.json',
  'browser-integration.json',
];

Future<void> _deleteJsonFiles(Directory dataDir) async {
  for (final name in _jsonFilesToDelete) {
    final f = File(p.join(dataDir.path, name));
    if (await f.exists()) {
      try {
        await f.delete();
        _log.info('Deleted migrated JSON: $name');
      } catch (e) {
        _log.warning('Could not delete migrated JSON $name: $e');
      }
    }
  }
}

Future<void> _tryFile(
    Directory dir, String name, Future<void> Function() body) async {
  final file = File(p.join(dir.path, name));
  if (!await file.exists()) return;
  try {
    await body();
    _log.info('Migrated $name');
  } catch (e, st) {
    _log.warning('Failed to migrate $name (continuing): $e\n$st');
  }
}

// ── Per-file importers ────────────────────────────────────────

Future<void> _migrateDownloads(AppDatabase db, Directory dir) async {
  final raw = await File(p.join(dir.path, 'history.json')).readAsString();
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final entries = (decoded['tasks'] as List?) ?? const [];
  if (entries.isEmpty) return;
  final now = DateTime.now();
  await db.downloadsDao.upsertBatch([
    for (final e in entries.cast<Map<String, dynamic>>())
      _downloadRowFromHistoryEntry(e, now),
  ]);
}

/// Read a single history.json entry (one task) and produce a
/// [DownloadRow]. Unknown / malformed fields fall back to safe
/// defaults so a half-broken file doesn't break the whole import.
DownloadRow _downloadRowFromHistoryEntry(
    Map<String, dynamic> e, DateTime updatedAt) {
  String getStr(String k) => (e[k] as String?) ?? '';
  int getInt(String k) => (e[k] as int?) ?? 0;
  DateTime? getDt(String k) {
    final s = e[k] as String?;
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  return DownloadRow(
    gid: getStr('gid'),
    filename: getStr('filename'),
    totalLength: getInt('totalLength'),
    completedLength: getInt('completedLength'),
    status: getStr('status').isEmpty
        ? DownloadStatus.unknown.name
        : getStr('status'),
    downloadSpeed: 0,
    dir: getStr('dir'),
    errorCode: e['errorCode'] as String?,
    errorMessage: e['errorMessage'] as String?,
    addedAt: getDt('addedAt'),
    completedAt: getDt('completedAt'),
    sourceUrl: e['sourceUrl'] as String?,
    updatedAt: updatedAt,
  );
}

Future<void> _migrateCategories(AppDatabase db, Directory dir) async {
  final raw = await File(p.join(dir.path, 'categories.json')).readAsString();
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final catsJson = (decoded['categories'] as List?) ?? const [];
  final rulesJson = (decoded['rules'] as List?) ?? const [];

  if (catsJson.isEmpty && rulesJson.isEmpty) return;

  await db.transaction(() async {
    var order = 0;
    for (final c in catsJson.cast<Map<String, dynamic>>()) {
      final cat = cat_domain.Category.fromJson(c);
      await db.categoriesDao.upsertCategory(CategoryRow(
        id: cat.id,
        name: cat.name,
        parentId: cat.parentId,
        defaultSaveDir: cat.defaultSaveDir,
        isDefault: cat.isDefault,
        iconName: cat.iconName,
        sortOrder: order++,
      ));
      await db.categoriesDao.replaceExtensions(cat.id, cat.extensions);
      await db.categoriesDao.replaceSites(cat.id, cat.sites);
    }
    for (final r in rulesJson.cast<Map<String, dynamic>>()) {
      final rule = ClassificationRule.fromJson(r);
      await db.categoriesDao.upsertRule(
          classificationRuleToRow(rule));
    }
  });
}

Future<void> _migrateSettings(AppDatabase db, Directory dir) async {
  final raw = await File(p.join(dir.path, 'settings.json')).readAsString();
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final s = DownloadSettings.fromJson(decoded);
  await db.downloadSettingsDao.putAll(settingsKeyValue(s));
}

Future<void> _migrateColumns(AppDatabase db, Directory dir) async {
  final raw = await File(p.join(dir.path, 'columns.json')).readAsString();
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final orderRaw = (decoded['order'] as List?)?.cast<String>();
  final hiddenRaw = (decoded['hidden'] as List?)?.cast<String>();
  if (orderRaw == null) return;

  // Reuse the same reconcile logic the in-app notifier used to
  // apply — drop unknowns, append missing defaults, force
  // filename to position 0.
  final known = {for (final s in kTableColumns) s.id.name};
  final cleaned = <ColumnId>[];
  for (final name in orderRaw) {
    if (!known.contains(name)) continue;
    final id = ColumnId.values.byName(name);
    if (id == ColumnId.filename) continue;
    cleaned.add(id);
  }
  for (final s in kTableColumns) {
    if (s.id == ColumnId.filename) continue;
    if (!cleaned.contains(s.id)) cleaned.add(s.id);
  }
  final hidden = <ColumnId>{};
  if (hiddenRaw != null) {
    for (final name in hiddenRaw) {
      if (!known.contains(name)) continue;
      final id = ColumnId.values.byName(name);
      if (id == ColumnId.filename) continue;
      hidden.add(id);
    }
  }
  final ordered = [ColumnId.filename, ...cleaned];
  await db.columnsDao.replaceAll([
    for (var i = 0; i < ordered.length; i++)
      ColumnLayoutRow(
        columnId: ordered[i].name,
        sortOrder: i,
        visible: !hidden.contains(ordered[i]),
      ),
  ]);
}

Future<void> _migrateBrowserIntegration(
    AppDatabase db, Directory dir) async {
  final raw =
      await File(p.join(dir.path, 'browser-integration.json')).readAsString();
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final s = BrowserIntegrationSettings.fromJson(decoded);
  await db.browserIntegrationDao
      .putAll(browserIntegrationKeyValue(s));
}
