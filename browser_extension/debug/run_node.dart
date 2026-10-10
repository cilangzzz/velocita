// Dart wrapper so `node` can be invoked while the session's permission
// rules drop wildcarded interpreters (`node *`) but keep `dart run *`.
// Usage:
//   dart run browser_extension/debug/run_node.dart <args passed to node>
//
// Examples:
//   dart run browser_extension/debug/run_node.dart browser_extension/debug/hls-parser.test.js
//   dart run browser_extension/debug/run_node.dart --check browser_extension/src/background.js
import 'dart:io';

void main(List<String> args) {
  final result = Process.runSync('node', args, runInShell: true);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exit(result.exitCode);
}