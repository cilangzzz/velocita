// Widget tests for the DownloadsScreen + add-task flow.
//
// These tests stub `DownloadsRepository` so we don't need a live aria2.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velocita/src/features/downloads/downloads.dart';
import 'package:velocita/src/features/downloads/data/downloads_repository.dart';

class _FakeRepo implements DownloadsRepository {
  final List<String> addedUris = [];
  @override
  Future<String> addUri(String url) async {
    addedUris.add(url);
    return 'gid-${addedUris.length}';
  }

  @override
  Future<String> addMagnet(String magnet) async => 'gid-m';
  @override
  Future<String> addTorrent(List<int> bytes) async => 'gid-t';
  @override
  Future<void> pause(String gid) async {}
  @override
  Future<void> resume(String gid) async {}
  @override
  Future<void> remove(String gid, {bool force = false}) async {}
  @override
  Future<List<TaskSummary>> activeTasks() async => const [];
  @override
  Future<TaskSummary?> oneTask(String gid) async => null;
}

void main() {
  testWidgets('DownloadsScreen renders empty state with no tasks',
      (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadsRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DownloadsScreen()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('No downloads yet — click "Add URL".'), findsOneWidget);
  });

  testWidgets('Add-task dialog opens and shows tabs', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadsRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DownloadsScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Add URL'));
    await tester.pumpAndSettle();
    expect(find.text('Add Download'), findsOneWidget);
    expect(find.text('URL'), findsWidgets);
    expect(find.text('Magnet'), findsOneWidget);
    expect(find.text('Torrent'), findsOneWidget);
  });
}
