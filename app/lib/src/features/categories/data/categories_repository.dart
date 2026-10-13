import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../kernel_bridge/kernel_provider.dart';
import '../../../persistence/database.dart' show AppDatabase, CategoriesDao, CategoryRow;
import '../../../persistence/defaults.dart';
import '../domain/categories.dart' as cat_domain;
import '../domain/category.dart';
import '../domain/classification_rule.dart';

/// Provider exposing the live list of categories + classification rules.
///
/// Backed by the `categories` / `category_extensions` / `category_sites`
/// / `classification_rules` tables of the shared `velocita.db` (replaces
/// the previous categories.json).
final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, CategoriesState>(
  CategoriesNotifier.new,
);

class CategoriesState {
  const CategoriesState({
    required this.categories,
    required this.rules,
  });

  final List<Category> categories;
  final List<ClassificationRule> rules;

  CategoriesState copyWith({
    List<Category>? categories,
    List<ClassificationRule>? rules,
  }) {
    return CategoriesState(
      categories: categories ?? this.categories,
      rules: rules ?? this.rules,
    );
  }
}

class CategoriesNotifier extends AsyncNotifier<CategoriesState> {
  late final AppDatabase _db;
  late final CategoriesDao _dao;
  late final String _downloadsPath;

  @override
  Future<CategoriesState> build() async {
    _db = ref.read(appDatabaseProvider);
    _dao = _db.categoriesDao;
    final support = await getApplicationSupportDirectory();
    final downloads = await getDownloadsDirectory() ??
        Directory('${support.path}/velocita/downloads');
    _downloadsPath = downloads.path;

    // First-run / empty table: seed the 7 default categories
    // (with their extensions + sites) so the UI immediately has
    // something to render.
    if ((await _dao.allCategories()).isEmpty) {
      await _seedDefaultCategories();
    }
    return _snapshot();
  }

  Future<void> _seedDefaultCategories() async {
    final seed = defaultCategorySeed(_downloadsPath);
    await _db.transaction(() async {
      for (final s in seed) {
        await _dao.upsertCategory(s.row);
        await _dao.replaceExtensions(s.row.id, s.extensions);
        await _dao.replaceSites(s.row.id, s.sites);
      }
    });
  }

  Future<CategoriesState> _snapshot() async {
    final cats = await _dao.allCategories();
    final extRows = await _dao.allExtensions();
    final siteRows = await _dao.allSites();
    final ruleRows = await _dao.allRules();

    final extsByCat = <String, List<String>>{};
    for (final r in extRows) {
      (extsByCat[r.categoryId] ??= <String>[]).add(r.ext);
    }
    final sitesByCat = <String, List<String>>{};
    for (final r in siteRows) {
      (sitesByCat[r.categoryId] ??= <String>[]).add(r.site);
    }

    final categories = [
      for (final c in cats)
        Category(
          id: c.id,
          name: c.name,
          parentId: c.parentId,
          defaultSaveDir: c.defaultSaveDir,
          extensions: List.unmodifiable(extsByCat[c.id] ?? const []),
          sites: List.unmodifiable(sitesByCat[c.id] ?? const []),
          iconName: c.iconName,
          isDefault: c.isDefault,
        ),
    ];
    final rules = [for (final r in ruleRows) classificationRuleFromRow(r)];
    return CategoriesState(
      categories: List.unmodifiable(categories),
      rules: _sortedRules(rules),
    );
  }

  List<ClassificationRule> _sortedRules(List<ClassificationRule> rules) {
    final sorted = [...rules];
    sorted.sort((a, b) => b.priority.compareTo(a.priority));
    return List.unmodifiable(sorted);
  }

  /// Resolve the save directory for a new download. Order:
  ///   1. user-provided `explicit`
  ///   2. matching category's `defaultSaveDir`
  ///   3. plain `defaultDownloadDir`
  String resolveSaveDir({
    required String filename,
    required String defaultDownloadDir,
    String? explicit,
  }) {
    final current = state.value;
    return cat_domain.resolveSaveDir(
      categories: current?.categories ?? const [],
      filename: filename,
      defaultDownloadDir: defaultDownloadDir,
      explicit: explicit,
    );
  }

  /// Find the category id that matches `filename` via the active
  /// rules. Returns `null` if no rule fires.
  String? classify(String filename) {
    final rules = state.value?.rules ?? const [];
    return cat_domain.classifyByRules(rules, filename);
  }

  /// Add a new user-defined category.
  Future<void> addCategory(Category c) async {
    final current = state.value;
    final next = [...?current?.categories, c];
    state = AsyncData(CategoriesState(
      categories: List.unmodifiable(next),
      rules: current?.rules ?? const [],
    ));
    final row = CategoryRow(
      id: c.id,
      name: c.name,
      parentId: c.parentId,
      defaultSaveDir: c.defaultSaveDir,
      isDefault: c.isDefault,
      iconName: c.iconName,
      sortOrder: next.length - 1,
    );
    await _db.transaction(() async {
      await _dao.upsertCategory(row);
      await _dao.replaceExtensions(c.id, c.extensions);
      await _dao.replaceSites(c.id, c.sites);
    });
  }

  /// Edit an existing category in place.
  Future<void> updateCategory(Category c) async {
    final current = state.value;
    if (current == null) return;
    final next = [
      for (final existing in current.categories)
        if (existing.id == c.id) c else existing,
    ];
    state = AsyncData(current.copyWith(categories: List.unmodifiable(next)));
    final row = CategoryRow(
      id: c.id,
      name: c.name,
      parentId: c.parentId,
      defaultSaveDir: c.defaultSaveDir,
      isDefault: c.isDefault,
      iconName: c.iconName,
      sortOrder: next.indexOf(c),
    );
    await _db.transaction(() async {
      await _dao.upsertCategory(row);
      await _dao.replaceExtensions(c.id, c.extensions);
      await _dao.replaceSites(c.id, c.sites);
    });
  }

  Future<void> removeCategory(String id) async {
    final current = state.value;
    if (current == null) return;
    final target = current.categories.firstWhere(
      (c) => c.id == id,
      orElse: () => const Category(
        id: '',
        name: '',
        defaultSaveDir: '',
        extensions: [],
      ),
    );
    if (target.id.isEmpty) return;
    if (target.isDefault) return;
    // Guard: parents with children must be emptied first.
    final hasChildren = current.categories.any((c) => c.parentId == id);
    if (hasChildren) return;

    final nextCats = current.categories.where((c) => c.id != id).toList();
    final nextRules = current.rules.where((r) => r.categoryId != id).toList();
    state = AsyncData(CategoriesState(
      categories: List.unmodifiable(nextCats),
      rules: List.unmodifiable(nextRules),
    ));
    // ON DELETE CASCADE on the children tables cleans up the
    // extensions / sites / rules automatically.
    await _dao.deleteCategory(id);
  }

  /// Convenience wrapper around the domain helper. `null` when the
  /// host matches no category's [Category.sites] list.
  Category? classifyBySite(String host) {
    final cats = state.value?.categories ?? const [];
    return cat_domain.classifyBySite(cats, host);
  }

  Future<void> addRule(ClassificationRule r) async {
    final current = state.value;
    if (current == null) return;
    final next = [...current.rules, r];
    state = AsyncData(current.copyWith(rules: _sortedRules(next)));
    await _dao.upsertRule(classificationRuleToRow(r));
  }

  Future<void> removeRule(String id) async {
    final current = state.value;
    if (current == null) return;
    final next = current.rules.where((r) => r.id != id).toList();
    state = AsyncData(current.copyWith(rules: List.unmodifiable(next)));
    await _dao.deleteRule(id);
  }

  /// Reset back to the seeded defaults. Rules are wiped, categories
  /// recreated from `Category.defaults(_downloadsPath)`.
  Future<void> resetToDefaults(String defaultDownloadDir) async {
    await _db.transaction(() async {
      // Drop every row from the four tables — the cascade on
      // children cleans up extensions / sites / rules.
      for (final c in (await _dao.allCategories())) {
        await _dao.deleteCategory(c.id);
      }
      for (final r in (await _dao.allRules())) {
        await _dao.deleteRule(r.id);
      }
      final seed = defaultCategorySeed(defaultDownloadDir);
      for (final s in seed) {
        await _dao.upsertCategory(s.row);
        await _dao.replaceExtensions(s.row.id, s.extensions);
        await _dao.replaceSites(s.row.id, s.sites);
      }
    });
    state = AsyncData(await _snapshot());
  }
}
