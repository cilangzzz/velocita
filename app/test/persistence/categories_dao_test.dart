// Unit tests for the categories DAO + defaults seed.
import 'package:flutter_test/flutter_test.dart';
import 'package:velocita/src/persistence/database.dart';
import 'package:velocita/src/persistence/defaults.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  test('allCategories returns empty on a fresh DB', () async {
    expect(await db.categoriesDao.allCategories(), isEmpty);
  });

  test('defaultCategorySeed produces 7 categories with extensions',
      () async {
    final seed = defaultCategorySeed(r'C:\fake\downloads');
    expect(seed.length, 7);
    final video = seed.firstWhere((s) => s.row.id == 'video');
    expect(video.extensions, contains('.mp4'));
    expect(video.extensions, contains('.m3u8'));
  });

  test('upsert + replaceExtensions + replaceSites round-trip', () async {
    final seed = defaultCategorySeed(r'C:\fake')[0];
    await db.categoriesDao.upsertCategory(seed.row);
    await db.categoriesDao.replaceExtensions(seed.row.id, seed.extensions);
    await db.categoriesDao.replaceSites(seed.row.id, seed.sites);
    final exts = await db.categoriesDao.allExtensions();
    final sites = await db.categoriesDao.allSites();
    expect(exts.length, seed.extensions.length);
    expect(sites.length, seed.sites.length);
  });

  test('replaceExtensions drops stale entries on re-seed', () async {
    final id = 'cat-x';
    await db.categoriesDao.upsertCategory(CategoryRow(
      id: id,
      name: 'X',
      defaultSaveDir: '/x',
      isDefault: false,
      sortOrder: 0,
    ));
    await db.categoriesDao.replaceExtensions(id, ['.a', '.b']);
    await db.categoriesDao.replaceExtensions(id, ['.c']);
    final exts = (await db.categoriesDao.allExtensions())
        .where((r) => r.categoryId == id)
        .map((r) => r.ext)
        .toList();
    expect(exts, ['.c']);
  });

  test('deleteCategory cascades the children', () async {
    final id = 'cat-y';
    await db.categoriesDao.upsertCategory(CategoryRow(
      id: id,
      name: 'Y',
      defaultSaveDir: '/y',
      isDefault: false,
      sortOrder: 0,
    ));
    await db.categoriesDao.replaceExtensions(id, ['.a']);
    await db.categoriesDao.replaceSites(id, ['example.com']);
    await db.categoriesDao.deleteCategory(id);
    expect(await db.categoriesDao.allCategories(), isEmpty);
    expect((await db.categoriesDao.allExtensions()), isEmpty);
    expect((await db.categoriesDao.allSites()), isEmpty);
  });
}
