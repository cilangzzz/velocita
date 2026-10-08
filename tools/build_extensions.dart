// ignore_for_file: avoid_print
// Stage the browser extension source into the three target folders the
// Flutter app can bundle as assets.
//
// Usage (from the velocita/ monorepo root):
//   dart run tools/build_extensions.dart
//
// Output:
//   app/assets/extensions/chrome/    — manifest.chrome.json renamed
//   app/assets/extensions/edge/      — manifest.edge.json renamed
//   app/assets/extensions/firefox/   — manifest.firefox.json renamed
//
// The three targets share background.js, content/, icons/, popup.*,
// options.*. The only thing that varies is the manifest.
//
// This script uses only dart:io so it has no package deps and can be
// invoked from any cwd.
import 'dart:io';

void main(List<String> args) {
  final repoRoot = _repoRoot();
  final src = Directory('$repoRoot/browser_extension/src');
  final assetsRoot = Directory('$repoRoot/app/assets/extensions');

  if (!src.existsSync()) {
    stderr.writeln('Source not found: ${src.path}');
    exit(1);
  }

  for (final target in const [
    _Target('chrome', 'manifest.chrome.json'),
    _Target('edge', 'manifest.edge.json'),
    _Target('firefox', 'manifest.firefox.json'),
  ]) {
    final dst = Directory('${assetsRoot.path}/${target.folder}');
    if (dst.existsSync()) dst.deleteSync(recursive: true);
    dst.createSync(recursive: true);

    for (final entity in src.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      // Skip the original manifest templates — the matching one for this
      // target is renamed to manifest.json below; the other two are
      // discarded.
      final rel = _relative(entity.path, src.path);
      if (rel.startsWith('manifest.') && rel.endsWith('.json') &&
          !rel.contains('/') /* only top-level manifests */) {
        if (rel == target.manifestName) {
          File('${dst.path}/manifest.json')
              .writeAsStringSync(entity.readAsStringSync());
        }
        continue;
      }
      // Files inside `content/` or any future subdirectory land at
      // their original relative path inside dst.
      final dstPath = '${dst.path}/$rel';
      File(dstPath).parent.createSync(recursive: true);
      File(dstPath).writeAsBytesSync(entity.readAsBytesSync());
    }
    print('wrote ${dst.path}');
  }
}

class _Target {
  const _Target(this.folder, this.manifestName);
  final String folder;
  final String manifestName;
}

String _repoRoot() {
  // tools/build_extensions.dart is one level under the velocita/
  // monorepo root. When invoked as `dart run tools/build_extensions.dart`
  // from velocita/, cwd == velocita/. We accept both that case and
  // `dart` being run from inside tools/.
  final here = Directory.current.path;
  if (Directory('$here/browser_extension/src').existsSync()) return here;
  final parent = File('$here/../browser_extension/src').absolute.path;
  if (Directory(parent).existsSync()) {
    return File('$here/../pubspec.yaml').absolute.parent.path;
  }
  stderr.writeln('Could not locate velocita/ repo root from $here');
  exit(1);
}

String _basename(String path) {
  final i = path.lastIndexOf(RegExp(r'[/\\]'));
  return i < 0 ? path : path.substring(i + 1);
}

String _relative(String path, String root) {
  // Make path absolute then strip the root + separator.
  final abs = File(path).absolute.path;
  final rootAbs = Directory(root).absolute.path;
  var prefix = rootAbs;
  if (!prefix.endsWith(Platform.pathSeparator)) {
    prefix = '$prefix${Platform.pathSeparator}';
  }
  if (abs.startsWith(prefix)) return abs.substring(prefix.length);
  // Fallback: best-effort basename only.
  return _basename(path);
}