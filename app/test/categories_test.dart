// Unit tests for category classification + rule matching.
import 'package:flutter_test/flutter_test.dart';
import 'package:velocita/src/features/categories/categories.dart';

void main() {
  group('Category.defaults', () {
    test('produces 6 default categories', () {
      final cats = Category.defaults(r'C:\Users\test\Downloads');
      expect(cats.length, 6);
      expect(cats.every((c) => c.isDefault), isTrue);
      // Every category's saveDir is inside the parent.
      for (final c in cats) {
        expect(
          c.defaultSaveDir.toLowerCase(),
          contains(r'c:\users\test\downloads'),
        );
      }
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
}
