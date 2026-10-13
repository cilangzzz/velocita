// Unit tests for the downloads DAO. Uses an in-memory AppDatabase
// so each test starts on a clean schema and tears down cleanly.
import 'package:flutter_test/flutter_test.dart';
import 'package:velocita/src/persistence/database.dart';

DownloadRow _row(String gid,
    {String filename = 'a.zip',
    String status = 'complete',
    String? sourceUrl,
    DateTime? addedAt}) {
  return DownloadRow(
    gid: gid,
    filename: filename,
    totalLength: 1000,
    completedLength: 1000,
    status: status,
    downloadSpeed: 0,
    dir: '/tmp',
    errorCode: null,
    errorMessage: null,
    addedAt: addedAt ?? DateTime(2026, 1, 1),
    completedAt: DateTime(2026, 1, 2),
    sourceUrl: sourceUrl,
    updatedAt: DateTime(2026, 1, 3),
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  test('all() returns empty list on a fresh DB', () async {
    expect(await db.downloadsDao.all(), isEmpty);
  });

  test('upsertOne round-trips fields', () async {
    final r = _row('g1', sourceUrl: 'https://x/y.zip');
    await db.downloadsDao.upsertOne(r);
    final got = await db.downloadsDao.byGid('g1');
    expect(got, isNotNull);
    expect(got!.filename, 'a.zip');
    expect(got.status, 'complete');
    expect(got.sourceUrl, 'https://x/y.zip');
    expect(got.totalLength, 1000);
  });

  test('upsertOne is idempotent (same gid → same row, no duplicates)',
      () async {
    await db.downloadsDao.upsertOne(_row('g1'));
    await db.downloadsDao.upsertOne(_row('g1', filename: 'b.zip'));
    final all = await db.downloadsDao.all();
    expect(all.length, 1);
    expect(all.single.filename, 'b.zip');
  });

  test('upsertBatch writes 1000 rows in one transaction < 200 ms', () async {
    final rows = [for (var i = 0; i < 1000; i++) _row('g$i')];
    final sw = Stopwatch()..start();
    await db.downloadsDao.upsertBatch(rows);
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(200));
    expect((await db.downloadsDao.all()).length, 1000);
  });

  test('byGid returns null for an unknown gid', () async {
    expect(await db.downloadsDao.byGid('nope'), isNull);
  });

  test('deleteByGid removes only the matching row', () async {
    await db.downloadsDao.upsertBatch([_row('a'), _row('b'), _row('c')]);
    await db.downloadsDao.deleteByGid('b');
    final all = (await db.downloadsDao.all()).map((r) => r.gid).toSet();
    expect(all, {'a', 'c'});
  });

  test('clear() drops every row', () async {
    await db.downloadsDao.upsertBatch([_row('a'), _row('b')]);
    await db.downloadsDao.clear();
    expect(await db.downloadsDao.all(), isEmpty);
  });

  test('TaskSummary round-trip preserves all fields', () async {
    final original = const TaskSummaryForTest(
      gid: 'round',
      filename: 'x.zip',
      status: 'complete',
      sourceUrl: 'https://x/x.zip',
    );
    final row = _row(original.gid,
        filename: original.filename,
        status: original.status,
        sourceUrl: original.sourceUrl);
    await db.downloadsDao.upsertOne(row);
    final got = await db.downloadsDao.byGid(original.gid);
    expect(got, isNotNull);
    expect(got!.filename, original.filename);
    expect(got.status, original.status);
    expect(got.sourceUrl, original.sourceUrl);
  });
}

class TaskSummaryForTest {
  const TaskSummaryForTest({
    required this.gid,
    required this.filename,
    required this.status,
    this.sourceUrl,
  });
  final String gid;
  final String filename;
  final String status;
  final String? sourceUrl;
}
