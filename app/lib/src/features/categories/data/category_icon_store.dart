/// Storage for custom user-uploaded category icons.
///
/// When a user picks a local image file in the category editor's
/// icon picker, we copy it into
/// `<appSupport>/velocita/category_icons/<id>.png` and store the
/// sentinel `image:<id>` in the `iconName` column. The render path
/// sees the `image:` prefix and switches from `Icons.<name>` to
/// `Image.file(...)`.
///
/// The sentinel-vs-IconData split keeps the existing `iconName`
/// schema untouched (single TEXT column) while supporting both
/// rendering modes.
library;

import 'dart:io';

import 'package:crypto/crypto.dart' show sha1;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The sentinel prefix that distinguishes a user-uploaded image
/// reference from a Material `Icons` key. Stored as the leading
/// segment of the value in `Category.iconName`.
const String kCustomImagePrefix = 'image:';

/// Allowed source extensions for the picker. SVG is intentionally
/// excluded — Flutter can't render SVG without an extra package and
/// Material icons already cover the vector side.
const Set<String> kSupportedImageExtensions = {
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.bmp',
};

class CategoryIconStore {
  /// Resolve the absolute path of a custom image referenced by
  /// [iconName]. Returns `null` for plain Material icon keys
  /// (anything that doesn't start with [kCustomImagePrefix]).
  static File? resolve(String? iconName) {
    final name = iconName;
    if (name == null || !name.startsWith(kCustomImagePrefix)) return null;
    if (_iconDirCached == null) return null;
    final fileName = name.substring(kCustomImagePrefix.length);
    return File(p.join(_iconDirCached!, fileName));
  }

  /// True if [iconName] refers to a user-uploaded image (vs a
  /// Material icon key).
  static bool isCustom(String? iconName) {
    return iconName != null && iconName.startsWith(kCustomImagePrefix);
  }

  /// Copy [source] into the icon store, returning a new
  /// [kCustomImagePrefix]-prefixed `iconName`. Throws on
  /// unsupported extension. The destination filename is a
  /// SHA-1 of the source path + mtime so re-picking the same
  /// file is idempotent.
  static Future<String> importFrom(File source) async {
    final ext = p.extension(source.path).toLowerCase();
    if (!kSupportedImageExtensions.contains(ext)) {
      throw ArgumentError(
        'Unsupported icon image type "$ext" '
        '(allowed: ${kSupportedImageExtensions.join(", ")})',
      );
    }
    if (!await source.exists()) {
      throw FileSystemException('Source icon file does not exist', source.path);
    }
    // Make sure the dir is initialised — if ensureReady wasn't
    // called (e.g. tests), do it now.
    if (_iconDirCached == null) {
      _iconDirCached = await _resolveIconDir();
    }
    final dir = _iconDirCached!;
    // Idempotent filename: same source path + mtime → same hash.
    final stat = await source.stat();
    final hash = sha1
        .convert('${source.absolute.path}|${stat.modified.millisecondsSinceEpoch}'
            .codeUnits)
        .toString()
        .substring(0, 16);
    final dest = File(p.join(dir, '$hash$ext'));
    if (!await dest.exists()) {
      await source.copy(dest.path);
    }
    return '$kCustomImagePrefix$hash$ext';
  }

  /// Delete a custom image from the store. No-op for plain
  /// Material icon keys.
  static Future<void> delete(String? iconName) async {
    final f = resolve(iconName);
    if (f == null) return;
    if (await f.exists()) {
      try {
        await f.delete();
      } catch (_) {
        // Best-effort. Stale files don't break the UI — the
        // renderer just shows a missing-image icon.
      }
    }
  }

  /// Lazily-resolved icon directory. Cached on first access.
  static String? _iconDirCached;

  /// Synchronous accessor for the icon dir. Returns `null` if
  /// [ensureReady] has not been awaited yet. Callers that need
  /// the path before the user has opened a category editor (e.g.
  /// the icon picker on first render) must `await ensureReady()`
  /// at bootstrap.
  static String? get iconDir => _iconDirCached;

  static Future<String> _resolveIconDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'velocita', 'category_icons'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  /// Pre-warm the icon directory. Call once at bootstrap so the
  /// later [resolve] / [importFrom] / [delete] calls don't pay
  /// the path_provider cost.
  static Future<void> ensureReady() async {
    _iconDirCached = await _resolveIconDir();
  }
}
