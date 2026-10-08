import 'dart:io';

import 'category.dart';
import 'classification_rule.dart';

/// Apply the given [rules] in priority order to [filename], returning the
/// matching [Category]'s id, or `null` if no rule fires.
///
/// [rules] is assumed to already be sorted descending by priority; the
/// first match wins. If multiple rules match, the higher-priority one
/// decides.
String? classifyByRules(Iterable<ClassificationRule> rules, String filename) {
  for (final rule in rules) {
    if (rule.matches(filename)) return rule.categoryId;
  }
  return null;
}

/// Pick a save directory based on extension. Used when adding a download.
///
/// Resolution order:
///   1. If the user provided an explicit `saveDir`, use that.
///   2. Otherwise, look at the URL extension and find a matching category;
///      fall back to the user's `defaultDownloadDir`.
String resolveSaveDir({
  required List<Category> categories,
  required String filename,
  required String defaultDownloadDir,
  String? explicit,
}) {
  if (explicit != null && explicit.isNotEmpty) return explicit;
  final ext = _ext(filename);
  for (final cat in categories) {
    if (cat.extensions.contains(ext)) return cat.defaultSaveDir;
  }
  return defaultDownloadDir;
}

String _ext(String filename) {
  var i = filename.length - 1;
  while (i >= 0 && filename[i] != '.') {
    if (filename[i] == '/' || filename[i] == '\\') return '';
    i--;
  }
  return i < 0 ? '' : filename.substring(i).toLowerCase();
}

// ── Tree helpers ─────────────────────────────────────────────────
//
// All helpers take the flat list and work on parent/child relationships
// implied by `Category.parentId`. The list order is the source of
// truth; no separate index is kept.

/// Root-level categories (no parent).
List<Category> rootCategories(List<Category> all) =>
    [for (final c in all) if (c.parentId == null) c];

/// Direct children of [parentId]. `parentId == null` returns roots.
List<Category> childrenOf(List<Category> all, String? parentId) =>
    [for (final c in all) if (c.parentId == parentId) c];

/// Find a category by id. Returns `null` if not present.
Category? categoryById(List<Category> all, String id) {
  for (final c in all) {
    if (c.id == id) return c;
  }
  return null;
}

/// Walk the parentId chain from [id] to the root, returning the
/// ancestors (parents, grandparents, …) in root-first order.
/// Returns an empty list if the id is unknown or is a root.
List<Category> ancestors(List<Category> all, String id) {
  final out = <Category>[];
  var current = categoryById(all, id);
  final seen = <String>{id};
  while (current != null && current.parentId != null) {
    if (!seen.add(current.parentId!)) break; // cycle guard
    final parent = categoryById(all, current.parentId!);
    if (parent == null) break;
    out.insert(0, parent);
    current = parent;
  }
  return out;
}

/// Resolve a category's effective save directory. If the category's own
/// [Category.defaultSaveDir] is empty (e.g. a freshly created child that
/// hasn't been edited yet), walk up the ancestor chain starting from
/// the immediate parent and use the closest non-empty dir; the root
/// falls back to the supplied [defaultDownloadDir].
String resolvedSaveDir({
  required List<Category> all,
  required Category category,
  required String defaultDownloadDir,
}) {
  if (category.defaultSaveDir.isNotEmpty) return category.defaultSaveDir;
  // `ancestors` is root-first; reverse so the immediate parent is
  // checked first, then its parent, etc.
  final chain = ancestors(all, category.id).reversed;
  for (final p in chain) {
    if (p.defaultSaveDir.isNotEmpty) return p.defaultSaveDir;
  }
  return defaultDownloadDir;
}

/// Find the deepest category whose `defaultSaveDir` is [dir] itself or
/// a strict ancestor of [dir] (i.e. the task's `dir` is inside that
/// category's save dir, or equals it). "Deepest" = longest matching
/// `defaultSaveDir` so child categories win over their parents.
///
/// Returns `null` if [dir] is empty or matches no category.
Category? deepestCategoryForDir(List<Category> all, String dir) {
  if (dir.isEmpty) return null;
  final needle = _normDir(dir);
  Category? best;
  var bestLen = -1;
  for (final c in all) {
    if (c.defaultSaveDir.isEmpty) continue;
    final root = _normDir(c.defaultSaveDir);
    if (needle == root ||
        needle.startsWith('$root/') ||
        needle.startsWith('$root\\')) {
      if (root.length > bestLen) {
        best = c;
        bestLen = root.length;
      }
    }
  }
  return best;
}

/// Find the category that should claim [host] based on the per-category
/// [Category.sites] lists. Match is case-insensitive domain-suffix:
/// a site entry of `github.com` matches `github.com` and
/// `www.github.com`. Returns the first matching category (in list
/// order) or `null` if no site declares this host.
Category? classifyBySite(List<Category> all, String host) {
  if (host.isEmpty) return null;
  final needle = _normHost(host);
  if (needle.isEmpty) return null;
  for (final c in all) {
    for (final site in c.sites) {
      final s = _normHost(site);
      if (s.isEmpty) continue;
      if (needle == s || needle.endsWith('.$s')) return c;
    }
  }
  return null;
}

/// True if [dir] is under the save dir of [categoryId] or any of its
/// descendants. Used to make a parent filter aggregate its children.
bool categoryIncludesDir(
  List<Category> all,
  String categoryId,
  String dir,
) {
  if (dir.isEmpty) return false;
  final needle = _normDir(dir);
  // BFS from the selected node — include the node and all descendants.
  final queue = <String>[categoryId];
  final visited = <String>{};
  while (queue.isNotEmpty) {
    final id = queue.removeLast();
    if (!visited.add(id)) continue;
    final cat = categoryById(all, id);
    if (cat == null) continue;
    final root = _normDir(cat.defaultSaveDir);
    if (root.isNotEmpty &&
        (needle == root ||
            needle.startsWith('$root/') ||
            needle.startsWith('$root\\'))) {
      return true;
    }
    queue.addAll([for (final c in childrenOf(all, id)) c.id]);
  }
  return false;
}

/// True if [dir] falls under any category's save dir (used to decide
/// the "Uncategorized" filter: tasks whose dir matches no category).
bool dirMatchesAnyCategory(List<Category> all, String dir) {
  if (dir.isEmpty) return false;
  final needle = _normDir(dir);
  for (final c in all) {
    if (c.defaultSaveDir.isEmpty) continue;
    final root = _normDir(c.defaultSaveDir);
    if (needle == root ||
        needle.startsWith('$root/') ||
        needle.startsWith('$root\\')) {
      return true;
    }
  }
  return false;
}

/// Normalize a directory for comparison: lowercase, forward slashes,
/// no trailing separator. Windows filesystems are case-insensitive
/// and tolerate both separators, so this matches the user's saved
/// path on either side of a comparison.
String _normDir(String s) {
  var v = s.replaceAll(r'\', '/').toLowerCase();
  while (v.length > 1 && v.endsWith('/')) {
    v = v.substring(0, v.length - 1);
  }
  return v;
}

String _normHost(String s) {
  var v = s.trim().toLowerCase();
  // Strip scheme/path/port. Input is the user-typed list, so accept
  // a generous variety: "https://github.com/x", "github.com:443",
  // "www.github.com".
  final schemeEnd = v.indexOf('://');
  if (schemeEnd >= 0) v = v.substring(schemeEnd + 3);
  final slash = v.indexOf('/');
  if (slash >= 0) v = v.substring(0, slash);
  final colon = v.indexOf(':');
  if (colon >= 0) v = v.substring(0, colon);
  if (v.startsWith('www.')) v = v.substring(4);
  return v;
}

// ── System handlers ─────────────────────────────────────────────

/// Try to actually open the file with the OS default handler. Returns a
/// future that completes with `true` on success.
Future<bool> openWithSystemHandler(String path) async {
  try {
    if (!File(path).existsSync()) return false;
    await Process.start('cmd', ['/c', 'start', '', path], mode: ProcessStartMode.detached);
    return true;
  } catch (_) {
    return false;
  }
}

/// Reveal the file's parent folder in the OS file manager. No-op if the
/// file does not exist.
Future<bool> revealInFolder(String path) async {
  try {
    final file = File(path);
    if (!file.existsSync()) return false;
    await Process.start('explorer', ['/select,${file.absolute.path}'], mode: ProcessStartMode.detached);
    return true;
  } catch (_) {
    return false;
  }
}
