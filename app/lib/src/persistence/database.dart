/// Single SQLite store for the whole app — replaces the previous
/// per-feature JSON files (history.json, categories.json,
/// settings.json, columns.json, browser-integration.json).
///
/// Tables:
///   • [Downloads]              — task history (5s poll, terminal
///                                states upserted immediately)
///   • [DownloadSettings]       — singleton settings; one row per
///                                scalar field (proxy, dir, limits, …)
///   • [Categories]             — user + seed category tree
///   • [CategoryExtensions]     — per-category file extensions
///   • [CategorySites]          — per-category hostnames
///   • [ClassificationRules]    — per-category filename patterns
///   • [ColumnLayout]           — table column order + visibility
///   • [BrowserIntegrationSettings]
///                              — browser-extension knobs
///
/// The default seed (Category.defaults, kTableColumns, …) is run on
/// first read by each DAO via `readWithDefaults()`; nothing is
/// inserted at `onCreate` so test DBs can opt out.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

// ── Tables ─────────────────────────────────────────────────────

/// One row per aria2 gid. HLS synthetic rows are NOT persisted —
/// they live only in memory (the merged file on disk is the
/// durable artifact).
@DataClassName('DownloadRow')
class Downloads extends Table {
  TextColumn get gid => text()();
  TextColumn get filename => text()();
  IntColumn get totalLength => integer().withDefault(const Constant(0))();
  IntColumn get completedLength => integer().withDefault(const Constant(0))();
  TextColumn get status => text()();
  IntColumn get downloadSpeed => integer().withDefault(const Constant(0))();
  TextColumn get dir => text().withDefault(const Constant(''))();
  TextColumn get errorCode => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get addedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {gid};
}

/// Singleton settings — each scalar field gets its own row keyed by
/// a stable id. Keeps the schema flat; partial-write safety is
/// free (one key change = one row update).
@DataClassName('DownloadSettingRow')
class DownloadSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get defaultSaveDir => text()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  TextColumn get iconName => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CategoryExtensionRow')
class CategoryExtensions extends Table {
  TextColumn get categoryId => text().references(Categories, #id,
      onDelete: KeyAction.cascade)();
  TextColumn get ext => text()();

  @override
  Set<Column<Object>> get primaryKey => {categoryId, ext};
}

@DataClassName('CategorySiteRow')
class CategorySites extends Table {
  TextColumn get categoryId => text().references(Categories, #id,
      onDelete: KeyAction.cascade)();
  TextColumn get site => text()();

  @override
  Set<Column<Object>> get primaryKey => {categoryId, site};
}

@DataClassName('ClassificationRuleRow')
class ClassificationRules extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text()();
  TextColumn get pattern => text()();
  TextColumn get flavor => text()();
  IntColumn get priority => integer()();
  TextColumn get source => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ColumnLayoutRow')
class ColumnLayout extends Table {
  TextColumn get columnId => text()();
  IntColumn get sortOrder => integer()();
  BoolColumn get visible => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {columnId};
}

@DataClassName('BrowserIntegrationSettingRow')
class BrowserIntegrationSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

// ── Database ───────────────────────────────────────────────────

@DriftDatabase(tables: [
  Downloads,
  DownloadSettings,
  Categories,
  CategoryExtensions,
  CategorySites,
  ClassificationRules,
  ColumnLayout,
  BrowserIntegrationSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// In-memory instance for unit tests — drops any pre-existing
  /// schema and starts fresh on every call. Not for production.
  factory AppDatabase.memory() {
    return AppDatabase(NativeDatabase.memory());
  }

  /// Production path: opens (and creates on first run) the
  /// single `<appSupport>/velocita/velocita.db` file. Idempotent.
  static Future<AppDatabase> openAtDefaultPath() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/velocita');
    if (!await dir.exists()) await dir.create(recursive: true);
    final dbFile = File(p.join(dir.path, 'velocita.db'));
    return AppDatabase(NativeDatabase.createInBackground(
      dbFile,
      // The default isolate handles DB I/O off the UI thread. This
      // is what makes the 5s batch upsert safe — no main-thread
      // stall even on a 1000-row write.
      setup: (db) {
        // Workaround for a Windows-specific issue where the bundled
        // sqlite3 lib needs `temp_store` to be MEMORY to avoid
        // creating files in the data dir.
        db.execute('PRAGMA temp_store = MEMORY;');
      },
    ));
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          // Custom onCreate disables drift's default CREATE TABLE
          // generation, so we have to invoke it explicitly.
          await m.createAll();
        },
        beforeOpen: (details) async {
          // The standard set of pragmas for a desktop write-heavy
          // workload: WAL lets readers run alongside the 5s batch
          // upsert, NORMAL is the durability/speed sweet spot,
          // 64 MB cache keeps the working set hot. Per-connection
          // foreign-key enforcement is required for the cascade
          // deletes on `category_extensions` / `category_sites`
          // to actually fire — SQLite ships with FKs off by
          // default.
          await customStatement('PRAGMA journal_mode = WAL;');
          await customStatement('PRAGMA synchronous = NORMAL;');
          await customStatement('PRAGMA cache_size = -64000;');
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );

  // DAOs as public fields. Constructed once per AppDatabase
  // instance; all providers share the same AppDatabase, so the
  // DAOs are effectively singletons within the app.
  late final downloadsDao = DownloadsDao(this);
  late final downloadSettingsDao = DownloadSettingsDao(this);
  late final categoriesDao = CategoriesDao(this);
  late final columnsDao = ColumnsDao(this);
  late final browserIntegrationDao = BrowserIntegrationDao(this);
}

// ── DAOs ───────────────────────────────────────────────────────

@DriftAccessor(tables: [Downloads])
class DownloadsDao extends DatabaseAccessor<AppDatabase>
    with _$DownloadsDaoMixin {
  DownloadsDao(super.db);

  /// All rows, ordered by addedAt desc (most recent first). Returns
  /// an empty list when the table is empty — the [TaskListNotifier]
  /// merges this with aria2's live `tellActive`/`tellStopped` so an
  /// empty table is not an error.
  Future<List<DownloadRow>> all() => (select(db.downloads)
        ..orderBy([(t) => OrderingTerm.desc(t.addedAt)]))
      .get();

  /// Single-gid lookup. Returns `null` if the gid has never been
  /// persisted (or has been pruned).
  Future<DownloadRow?> byGid(String gid) =>
      (select(db.downloads)..where((t) => t.gid.equals(gid)))
          .getSingleOrNull();

  /// Upsert a single row. Used for terminal states (complete /
  /// error / removed) that need an immediate write so they
  /// survive a crash, and for the per-gid `_refreshOne` path.
  Future<void> upsertOne(DownloadRow row) {
    return into(db.downloads).insertOnConflictUpdate(row);
  }

  /// Batch upsert. Single transaction — the 1000-row rewrite is
  /// ~10 ms with WAL + NORMAL synchronous on an SSD, vs ~30 ms
  /// for 1000 individual transactions.
  Future<void> upsertBatch(List<DownloadRow> rows) async {
    if (rows.isEmpty) return;
    await db.batch((b) {
      for (final row in rows) {
        b.insert(
          db.downloads,
          row,
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Drop everything — used by tests and the JSON migration
  /// fallback.
  Future<void> clear() => delete(db.downloads).go();

  /// Drop a single gid. Used by the UI's "remove from history"
  /// action.
  Future<void> deleteByGid(String gid) async {
    await (delete(db.downloads)..where((t) => t.gid.equals(gid))).go();
  }
}

@DriftAccessor(tables: [DownloadSettings])
class DownloadSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$DownloadSettingsDaoMixin {
  DownloadSettingsDao(super.db);

  Future<String?> valueOf(String key) =>
      (select(db.downloadSettings)..where((t) => t.key.equals(key)))
          .getSingleOrNull()
          .then((r) => r?.value);

  /// Patch one key. Inserts if missing.
  Future<void> put(String key, String value) async {
    await into(db.downloadSettings).insertOnConflictUpdate(
          DownloadSettingRow(key: key, value: value),
        );
  }

  /// Patch many keys in one transaction. The caller must split
  /// the [DownloadSettings] into individual scalar rows first
  /// (see [DownloadSettingsMapper]).
  Future<void> putAll(Map<String, String> kvs) async {
    if (kvs.isEmpty) return;
    await batch((b) {
      b.insertAll(
        db.downloadSettings,
        [for (final e in kvs.entries) DownloadSettingRow(key: e.key, value: e.value)],
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<Map<String, String>> all() async {
    final rows = await select(db.downloadSettings).get();
    return {for (final r in rows) r.key: r.value};
  }
}

@DriftAccessor(tables: [Categories, CategoryExtensions, CategorySites, ClassificationRules])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(super.db);

  Future<List<CategoryRow>> allCategories() =>
      (select(db.categories)..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

  Future<List<CategoryExtensionRow>> allExtensions() =>
      select(db.categoryExtensions).get();

  Future<List<CategorySiteRow>> allSites() =>
      select(db.categorySites).get();

  Future<List<ClassificationRuleRow>> allRules() =>
      (select(db.classificationRules)
            ..orderBy([(t) => OrderingTerm.desc(t.priority)]))
          .get();

  Future<void> upsertCategory(CategoryRow c) =>
      into(db.categories).insertOnConflictUpdate(c);

  Future<void> replaceExtensions(
      String categoryId, List<String> exts) async {
    await (delete(db.categoryExtensions)
          ..where((t) => t.categoryId.equals(categoryId)))
        .go();
    if (exts.isEmpty) return;
    await batch((b) {
      b.insertAll(
        db.categoryExtensions,
        [for (final e in exts) CategoryExtensionRow(categoryId: categoryId, ext: e)],
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<void> replaceSites(String categoryId, List<String> sites) async {
    await (delete(db.categorySites)
          ..where((t) => t.categoryId.equals(categoryId)))
        .go();
    if (sites.isEmpty) return;
    await batch((b) {
      b.insertAll(
        db.categorySites,
        [for (final s in sites) CategorySiteRow(categoryId: categoryId, site: s)],
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<void> upsertRule(ClassificationRuleRow r) =>
      into(db.classificationRules).insertOnConflictUpdate(r);

  Future<void> deleteCategory(String id) async {
    await (delete(db.classificationRules)
          ..where((t) => t.categoryId.equals(id)))
        .go();
    // cascade on categoryExtensions and categorySites is set at the
    // SQL level; nothing extra to do here for the children.
    await (delete(db.categories)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteRule(String id) async {
    await (delete(db.classificationRules)..where((t) => t.id.equals(id)))
        .go();
  }
}

@DriftAccessor(tables: [ColumnLayout])
class ColumnsDao extends DatabaseAccessor<AppDatabase>
    with _$ColumnsDaoMixin {
  ColumnsDao(super.db);

  Future<List<ColumnLayoutRow>> all() =>
      (select(db.columnLayout)..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

  Future<void> replaceAll(List<ColumnLayoutRow> rows) async {
    await db.batch((b) {
      b.deleteAll(db.columnLayout);
      b.insertAll(db.columnLayout, rows, mode: InsertMode.insertOrReplace);
    });
  }

  Future<void> setVisible(String id, bool visible) async {
    await (update(db.columnLayout)..where((t) => t.columnId.equals(id)))
        .write(ColumnLayoutCompanion(visible: Value(visible)));
  }

  Future<void> setOrder(List<String> orderedIds) async {
    await db.batch((b) {
      for (var i = 0; i < orderedIds.length; i++) {
        b.update(
          db.columnLayout,
          ColumnLayoutCompanion(sortOrder: Value(i)),
          where: (t) => t.columnId.equals(orderedIds[i]),
        );
      }
    });
  }
}

@DriftAccessor(tables: [BrowserIntegrationSettings])
class BrowserIntegrationDao extends DatabaseAccessor<AppDatabase>
    with _$BrowserIntegrationDaoMixin {
  BrowserIntegrationDao(super.db);

  Future<String?> valueOf(String key) =>
      (select(db.browserIntegrationSettings)..where((t) => t.key.equals(key)))
          .getSingleOrNull()
          .then((r) => r?.value);

  Future<Map<String, String>> all() async {
    final rows = await select(db.browserIntegrationSettings).get();
    return {for (final r in rows) r.key: r.value};
  }

  Future<void> put(String key, String value) async {
    await into(db.browserIntegrationSettings).insertOnConflictUpdate(
          BrowserIntegrationSettingRow(key: key, value: value),
        );
  }

  Future<void> putAll(Map<String, String> kvs) async {
    if (kvs.isEmpty) return;
    await batch((b) {
      b.insertAll(
        db.browserIntegrationSettings,
        [for (final e in kvs.entries) BrowserIntegrationSettingRow(key: e.key, value: e.value)],
        mode: InsertMode.insertOrReplace,
      );
    });
  }
}
