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
