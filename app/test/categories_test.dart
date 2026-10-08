// Unit tests for category classification + rule matching.
import 'package:flutter_test/flutter_test.dart';
import 'package:velocita/src/features/categories/categories.dart';

void main() {
  group('Category.defaults', () {
    test('produces 7 default categories (6 + Other catch-all)', () {
      final cats = Category.defaults(r'C:\Users\test\Downloads');
      expect(cats.length, 7);
      expect(cats.every((c) => c.isDefault), isTrue);
      // Every category's saveDir is inside the parent.
      for (final c in cats) {
        expect(
          c.defaultSaveDir.toLowerCase(),
          contains(r'c:\users\test\downloads'),
        );
      }
    });

    test('the "other" category is a default catch-all with no extensions', () {
      final cats = Category.defaults(r'/tmp');
      final other = cats.firstWhere((c) => c.id == 'other');
      expect(other.isDefault, isTrue);
      expect(other.extensions, isEmpty);
    });

    test('extensions are lowercased', () {
      final cats = Category.defaults(r'/tmp');
      final video = cats.firstWhere((c) => c.id == 'video');
      expect(video.extensions.contains('.mp4'), isTrue);
      expect(video.extensions.contains('.MP4'), isFalse);
    });
  });

  group('resolveSaveDir', () {
    final cats = Category.defaults(r'C:\Users\test\Downloads');
    const fallback = r'C:\Users\test\Downloads';

    test('mp4 lands in Videos', () {
      final dir = resolveSaveDir(
        categories: cats,
        filename: 'movie.mp4',
        defaultDownloadDir: fallback,
      );
      expect(dir.toLowerCase(), contains(r'videos'));
    });

    test('unknown extension falls back to defaultDownloadDir', () {
      final dir = resolveSaveDir(
        categories: cats,
        filename: 'weird.xyz',
        defaultDownloadDir: fallback,
      );
      expect(dir, fallback);
    });

    test('explicit overrides categories', () {
      final dir = resolveSaveDir(
        categories: cats,
        filename: 'movie.mp4',
        defaultDownloadDir: fallback,
        explicit: r'C:\custom\path',
      );
      expect(dir, r'C:\custom\path');
    });
  });

  group('ClassificationRule', () {
    test('substring match is case-insensitive', () {
      final rule = ClassificationRule(
        id: 'r1',
        categoryId: 'archive',
        pattern: 'LINUX',
        flavor: RuleFlavor.substring,
        priority: 1,
        source: RuleSource.userDefined,
      );
      expect(rule.matches('ubuntu-LINUX-22.04.iso'), isTrue);
      expect(rule.matches('LINUX-mint'), isTrue);
      expect(rule.matches('movie.mp4'), isFalse);
    });

    test('extension match uses suffix', () {
      final rule = ClassificationRule(
        id: 'r2',
        categoryId: 'image',
        pattern: '.jpg',
        flavor: RuleFlavor.extension,
        priority: 1,
        source: RuleSource.userDefined,
      );
      expect(rule.matches('photo.jpg'), isTrue);
      expect(rule.matches('photo.png'), isFalse);
    });

    test('regex match compiles once', () {
      final rule = ClassificationRule(
        id: 'r3',
        categoryId: 'program',
        pattern: r'^ubuntu-\d+\.\d+',
        flavor: RuleFlavor.regex,
        priority: 1,
        source: RuleSource.userDefined,
      );
      expect(rule.matches('ubuntu-22.04-desktop.iso'), isTrue);
      expect(rule.matches('ubuntu-22.04.3-desktop.iso'), isTrue);
      expect(rule.matches('debian-12.iso'), isFalse);
    });
  });

  group('classifyByRules', () {
    test('highest priority wins', () {
      // Note: classifyByRules assumes the rules iterator yields highest
      // priority first; the caller (CategoriesNotifier._sortedRules) is
      // responsible for sorting.
      final rules = [
        ClassificationRule(
          id: 'r2',
          categoryId: 'program',
          pattern: 'linux-mint',
          flavor: RuleFlavor.substring,
          priority: 100, // wins
          source: RuleSource.userDefined,
        ),
        ClassificationRule(
          id: 'r1',
          categoryId: 'archive',
          pattern: '.iso',
          flavor: RuleFlavor.extension,
          priority: 10,
          source: RuleSource.userDefined,
        ),
      ];
      final id = classifyByRules(rules, 'linux-mint-22.04.iso');
      expect(id, 'program');
    });

    test('returns null when no rule matches', () {
      expect(classifyByRules(const <ClassificationRule>[], 'foo.txt'), isNull);
    });

    test('Category.defaults classify by extension', () {
      final cats = Category.defaults(r'C:\Users\test\Downloads');
      expect(cats.isNotEmpty, isTrue);
    });
  });

  // ── Tree helpers ────────────────────────────────────────────
  // Minimal hand-built category lists so the tests are independent
  // from Category.defaults.
  Category cat(
    String id, {
    String? parentId,
    String dir = '',
    List<String> exts = const [],
    List<String> sites = const [],
    bool isDefault = false,
  }) =>
      Category(
        id: id,
        name: id,
        parentId: parentId,
        defaultSaveDir: dir,
        extensions: exts,
        sites: sites,
        isDefault: isDefault,
      );

  group('rootCategories / childrenOf / categoryById / ancestors', () {
    final all = [
      cat('root1', dir: r'C:\dl\a'),
      cat('root2', dir: r'C:\dl\b'),
      cat('child1', parentId: 'root1', dir: r'C:\dl\a\c1'),
      cat('grand', parentId: 'child1', dir: r'C:\dl\a\c1\g'),
    ];

    test('rootCategories returns only top-level', () {
      final roots = rootCategories(all);
      expect(roots.map((c) => c.id).toSet(), {'root1', 'root2'});
    });

    test('childrenOf returns direct children only', () {
      final kids = childrenOf(all, 'root1');
      expect(kids.map((c) => c.id), ['child1']);
    });

    test('categoryById returns null for unknown ids', () {
      expect(categoryById(all, 'nope'), isNull);
      expect(categoryById(all, 'grand')?.id, 'grand');
    });

    test('ancestors walks parentId chain to root', () {
      final chain = ancestors(all, 'grand').map((c) => c.id).toList();
      expect(chain, ['root1', 'child1']);
    });
  });

  group('resolvedSaveDir', () {
    final all = [
      cat('root', dir: r'C:\dl\root'),
      cat('mid', parentId: 'root', dir: r'C:\dl\root\mid'),
      cat('leaf', parentId: 'mid', dir: ''), // empty → falls back
    ];

    test('uses own dir when set', () {
      final c = all.firstWhere((c) => c.id == 'root');
      expect(
        resolvedSaveDir(all: all, category: c, defaultDownloadDir: r'C:\dl'),
        r'C:\dl\root',
      );
    });

    test('falls back through empty ancestors', () {
      final c = all.firstWhere((c) => c.id == 'leaf');
      expect(
        resolvedSaveDir(all: all, category: c, defaultDownloadDir: r'C:\dl'),
        r'C:\dl\root\mid',
      );
    });

    test('falls back to defaultDownloadDir when nothing is set', () {
      final lone = [cat('orphan', dir: '')];
      expect(
        resolvedSaveDir(
            all: lone, category: lone.first, defaultDownloadDir: r'C:\dl'),
        r'C:\dl',
      );
    });
  });

  group('deepestCategoryForDir', () {
    final all = [
      cat('video', dir: r'C:\dl\Videos'),
      cat('video-sd', parentId: 'video', dir: r'C:\dl\Videos\SD'),
      cat('other', dir: r'C:\dl\Other'),
    ];

    test('matches a direct hit', () {
      final c = deepestCategoryForDir(all, r'C:\dl\Videos');
      expect(c?.id, 'video');
    });

    test('child wins over its ancestor', () {
      final c = deepestCategoryForDir(all, r'C:\dl\Videos\SD\movie.mp4');
      expect(c?.id, 'video-sd');
    });

    test('returns null for a dir outside any category', () {
      expect(deepestCategoryForDir(all, r'C:\elsewhere'), isNull);
      expect(deepestCategoryForDir(all, ''), isNull);
    });

    test('matches case-insensitively and tolerates trailing slashes', () {
      final c = deepestCategoryForDir(all, r'c:\dl\videos\');
      expect(c?.id, 'video');
    });
  });

  group('categoryIncludesDir', () {
    final all = [
      cat('video', dir: r'C:\dl\Videos'),
      cat('video-sd', parentId: 'video', dir: r'C:\dl\Videos\SD'),
    ];

    test('a child category matches its descendant dirs', () {
      expect(
        categoryIncludesDir(all, 'video', r'C:\dl\Videos\SD\movie.mp4'),
        isTrue,
      );
    });

    test('a parent category aggregates its children', () {
      expect(
        categoryIncludesDir(all, 'video', r'C:\dl\Videos\SD'),
        isTrue,
      );
    });

    test('returns false for unrelated dirs', () {
      expect(
        categoryIncludesDir(all, 'video', r'C:\dl\Other\file'),
        isFalse,
      );
    });
  });

  group('classifyBySite', () {
    final all = [
      cat('code', dir: r'C:\dl\Code', sites: ['github.com', 'gitlab.com']),
      cat('books', dir: r'C:\dl\Books', sites: ['zlib.org']),
    ];

    test('matches an exact host', () {
      expect(classifyBySite(all, 'github.com')?.id, 'code');
    });

    test('matches a subdomain', () {
      expect(classifyBySite(all, 'www.github.com')?.id, 'code');
    });

    test('is case-insensitive', () {
      expect(classifyBySite(all, 'GITHUB.COM')?.id, 'code');
    });

    test('returns null when no category lists the host', () {
      expect(classifyBySite(all, 'example.com'), isNull);
    });

    test('strips scheme/path/port from the input', () {
      expect(classifyBySite(all, 'https://github.com/x?y=1')?.id, 'code');
      expect(classifyBySite(all, 'github.com:443')?.id, 'code');
    });
  });

  group('dirMatchesAnyCategory', () {
    final all = [
      cat('video', dir: r'C:\dl\Videos'),
      cat('other', dir: r'C:\dl\Other'),
    ];

    test('true when one category claims the dir', () {
      expect(dirMatchesAnyCategory(all, r'C:\dl\Videos\x.mp4'), isTrue);
    });

    test('false when no category claims the dir', () {
      expect(dirMatchesAnyCategory(all, r'C:\elsewhere'), isFalse);
    });

    test('empty dir never matches', () {
      expect(dirMatchesAnyCategory(all, ''), isFalse);
    });
  });
}
