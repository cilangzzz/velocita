import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/categories.dart' as cat_domain;
import '../domain/category.dart';
import '../domain/classification_rule.dart';

/// Provider exposing the live list of categories + classification rules.
///
/// Backed by a single JSON file under the app's support directory so the
/// user's category layout survives app restarts.
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
  late File _file;
  final List<ClassificationRule> _rules = [];
  List<Category> _categories = const [];

  @override
  Future<CategoriesState> build() async {
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}/velocita/categories.json');
    await _file.parent.create(recursive: true);
    if (await _file.exists()) {
      try {
        final raw =
            jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
        _categories = (raw['categories'] as List)
            .map((e) => Category.fromJson(e as Map<String, dynamic>))
            .toList();
        _rules
          ..clear()
          ..addAll((raw['rules'] as List).map((e) =>
              ClassificationRule.fromJson(e as Map<String, dynamic>)));
      } catch (_) {
        // Corrupt file — fall back to defaults.
        _categories = const [];
        _rules.clear();
      }
    }
    final downloads = await getDownloadsDirectory() ??
        Directory('${dir.path}/velocita/downloads');
    if (_categories.isEmpty) {
      _categories = Category.defaults(downloads.path);
    } else {
      // Migrate: fold any seed extensions the user's persisted default
      // categories are missing (e.g. `.m3u8` added after their first
      // run) back in without touching their name / save dir / custom
      // extensions. Idempotent — once present, nothing changes.
      final changed = _mergeDefaultExtensions(downloads.path);
      if (changed) await _persist();
    }
    return _snapshot();
  }

  /// For every `isDefault` category present in BOTH the persisted list
  /// and the current [Category.defaults], append any seed extensions the
  /// persisted one lacks. Returns `true` iff something changed.
  bool _mergeDefaultExtensions(String downloadDir) {
    final seeds = {for (final c in Category.defaults(downloadDir)) c.id: c};
    var changed = false;
    final next = <Category>[];
    for (final cat in _categories) {
      final seed = seeds[cat.id];
      if (seed == null || !cat.isDefault) {
        next.add(cat);
        continue;
      }
      final missing = [
        for (final e in seed.extensions)
          if (!cat.extensions.contains(e)) e,
      ];
      if (missing.isEmpty) {
        next.add(cat);
      } else {
        next.add(cat.copyWith(extensions: [...cat.extensions, ...missing]));
        changed = true;
      }
    }
    if (changed) _categories = next;
    return changed;
  }

  CategoriesState _snapshot() => CategoriesState(
        categories: List.unmodifiable(_categories),
        rules: _sortedRules(),
      );

  List<ClassificationRule> _sortedRules() {
    final sorted = [..._rules];
    sorted.sort((a, b) => b.priority.compareTo(a.priority));
    return List.unmodifiable(sorted);
  }

  Future<void> _persist() async {
    final payload = {
      'categories': _categories.map((c) => c.toJson()).toList(),
      'rules': _sortedRules().map((r) => r.toJson()).toList(),
    };
    await _file.writeAsString(jsonEncode(payload));
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
    return cat_domain.resolveSaveDir(
      categories: _categories,
      filename: filename,
      defaultDownloadDir: defaultDownloadDir,
      explicit: explicit,
    );
  }

  /// Find the category id that matches `filename` via the active rules.
  /// Returns `null` if no rule fires.
  String? classify(String filename) =>
      cat_domain.classifyByRules(_sortedRules(), filename);

  /// Add a new user-defined category.
  Future<void> addCategory(Category c) async {
    _categories = [..._categories, c];
    state = AsyncData(_snapshot());
    await _persist();
  }

  /// Edit an existing category in place.
  Future<void> updateCategory(Category c) async {
    _categories = [
      for (final existing in _categories)
        if (existing.id == c.id) c else existing,
    ];
    state = AsyncData(_snapshot());
    await _persist();
  }

  Future<void> removeCategory(String id) async {
    // Guard: default categories are protected.
    final target = _categories.firstWhere(
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
    // Guard: parents with children must be emptied first. The UI
    // disables the delete menu item in this case, but the notifier
    // enforces the rule as well so a stray call is harmless.
    final hasChildren = _categories.any((c) => c.parentId == id);
    if (hasChildren) return;

    _categories = _categories.where((c) => c.id != id).toList();
    _rules.removeWhere((r) => r.categoryId == id);
    state = AsyncData(_snapshot());
    await _persist();
  }

  /// Convenience wrapper around the domain helper. `null` when the
  /// host matches no category's [Category.sites] list.
  Category? classifyBySite(String host) {
    return cat_domain.classifyBySite(_categories, host);
  }

  Future<void> addRule(ClassificationRule r) async {
    _rules.add(r);
    state = AsyncData(_snapshot());
    await _persist();
  }

  Future<void> removeRule(String id) async {
    _rules.removeWhere((r) => r.id == id);
    state = AsyncData(_snapshot());
    await _persist();
  }

  /// Reset back to the seeded defaults. Rules are wiped, categories
  /// recreated from `Category.defaults(defaultDownloadDir)`.
  Future<void> resetToDefaults(String defaultDownloadDir) async {
    _categories = Category.defaults(defaultDownloadDir);
    _rules.clear();
    state = AsyncData(_snapshot());
    await _persist();
  }
}
