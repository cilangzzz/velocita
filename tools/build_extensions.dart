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
// The three targets share background.js, popup.html/js, options.html/js,
// and icons/. The only thing that varies is the manifest.
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

    for (final entity in src.listSync()) {
      if (entity is! File) continue;
      final name = _basename(entity.path);
      if (name == target.manifestName) {
        // Rename to manifest.json in the target folder.
        File('${dst.path}/manifest.json')
            .writeAsStringSync(entity.readAsStringSync());
      } else if (name.startsWith('manifest.')) {
        // Skip other browsers' manifest templates.
        continue;
      } else {
        // Copy as bytes — JS / HTML are UTF-8 text but reading them
        // as bytes handles icons and any future binary asset too.
        File('${dst.path}/$name')
            .writeAsBytesSync(entity.readAsBytesSync());
      }
    }
    // Copy the icons subdir verbatim.
    final srcIcons = Directory('${src.path}/icons');
    if (srcIcons.existsSync()) {
      final dstIcons = Directory('${dst.path}/icons')..createSync(recursive: true);
      for (final f in srcIcons.listSync()) {
        if (f is File) {
          File('${dstIcons.path}/${_basename(f.path)}')
              .writeAsBytesSync(f.readAsBytesSync());
        }
      }
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
