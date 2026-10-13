import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../kernel_bridge/kernel_provider.dart';
import '../../../persistence/database.dart' show ColumnsDao, ColumnLayoutRow;
import '../../../persistence/defaults.dart';

/// Stable identifier for a column in the downloads table. The order of
/// values here is the default rendering order; the persisted config
/// stores a re-arranged version of this list.
enum ColumnId { filename, status, progress, speed, size, added }

/// Display metadata for a column. The width of the [ColumnId.filename]
/// column is variable (it absorbs the remaining horizontal space); all
/// others are fixed.
class ColumnSpec {
  const ColumnSpec({
    required this.id,
    required this.label,
    required this.width,
    this.variable = false,
    this.locked = false,
  });

  final ColumnId id;
  final String label;
  final double width;
  final bool variable;
  final bool locked;
}

/// Master list of table columns, in their default order.
const List<ColumnSpec> kTableColumns = [
  ColumnSpec(
    id: ColumnId.filename,
    label: 'Filename',
    width: 0,
    variable: true,
    locked: true,
  ),
  ColumnSpec(id: ColumnId.status, label: 'Status', width: 120),
  ColumnSpec(id: ColumnId.progress, label: 'Progress', width: 150),
  ColumnSpec(id: ColumnId.speed, label: 'Speed', width: 90),
  ColumnSpec(id: ColumnId.size, label: 'Size', width: 90),
  ColumnSpec(id: ColumnId.added, label: 'Added', width: 110),
];

/// Look up a column's spec by id. Returns a fallback of width=120 if
/// the id is unknown (defensive — shouldn't happen).
ColumnSpec specOf(ColumnId id) {
  for (final s in kTableColumns) {
    if (s.id == id) return s;
  }
  return const ColumnSpec(
    id: ColumnId.status,
    label: 'Status',
    width: 120,
  );
}

class ColumnsState {
  const ColumnsState({required this.order, required this.hidden});
  final List<ColumnId> order;
  final Set<ColumnId> hidden;

  bool isVisible(ColumnId id) => !hidden.contains(id);

  /// Ordered list of [ColumnSpec]s that should be rendered. Filename
  /// (if it somehow got hidden — it can't be via the UI, but defensive)
  /// is always included to keep the table useful.
  List<ColumnSpec> get visibleSpecs {
    final out = <ColumnSpec>[];
    for (final id in order) {
      if (id == ColumnId.filename) {
        out.add(specOf(id));
      } else if (isVisible(id)) {
        out.add(specOf(id));
      }
    }
    // Belt-and-suspenders: if everything except filename is hidden,
    // we still want filename to render.
    if (out.isEmpty) out.add(specOf(ColumnId.filename));
    return out;
  }

  ColumnsState copyWith({
    List<ColumnId>? order,
    Set<ColumnId>? hidden,
  }) =>
      ColumnsState(
        order: order ?? this.order,
        hidden: hidden ?? this.hidden,
      );
}

final columnsProvider =
    AsyncNotifierProvider<ColumnsNotifier, ColumnsState>(
  ColumnsNotifier.new,
);

class ColumnsNotifier extends AsyncNotifier<ColumnsState> {
  late final ColumnsDao _dao;

  @override
  Future<ColumnsState> build() async {
    _dao = ref.read(appDatabaseProvider).columnsDao;
    // First-run / empty table: seed the default 6 columns, then read.
    if ((await _dao.all()).isEmpty) {
      await _dao.replaceAll(defaultColumnSeed());
    }
    final rows = await _dao.all();
    return _stateFromRows(rows);
  }

  ColumnsState _stateFromRows(List<ColumnLayoutRow> rows) {
    // Reconcile against the canonical set: drop unknown ids, append
    // any new defaults at the end, and always force filename to
    // position 0 (locked, never re-orderable). Same logic the
    // pre-Drift code path used to apply on load.
    final known = {for (final s in kTableColumns) s.id.name};
    final sorted = [...rows]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final cleaned = <ColumnId>[];
    for (final r in sorted) {
      if (!known.contains(r.columnId)) continue;
      final id = ColumnId.values.byName(r.columnId);
      if (id == ColumnId.filename) continue;
      cleaned.add(id);
    }
    for (final s in kTableColumns) {
      if (s.id == ColumnId.filename) continue;
      if (!cleaned.contains(s.id)) cleaned.add(s.id);
    }
    final hidden = <ColumnId>{
      for (final r in sorted)
        if (!r.visible && known.contains(r.columnId))
          ColumnId.values.byName(r.columnId),
    };
    hidden.remove(ColumnId.filename); // never hide filename
    return ColumnsState(
      order: [ColumnId.filename, ...cleaned],
      hidden: hidden,
    );
  }

  Future<void> toggle(ColumnId id) async {
    if (id == ColumnId.filename) return; // locked
    final s = state.value;
    if (s == null) return;
    final hidden = {...s.hidden};
    if (!hidden.add(id)) hidden.remove(id);
    state = AsyncData(s.copyWith(hidden: hidden));
    await _dao.setVisible(id.name, !hidden.contains(id));
  }

  /// Move [id] one step in [direction] (-1 = up, +1 = down). Filename
  /// (position 0) and the locked filename row can't be moved; the row
  /// above the filename is the lowest valid position for any other
  /// column.
  Future<void> move(ColumnId id, int direction) async {
    if (id == ColumnId.filename) return;
    final s = state.value;
    if (s == null) return;
    final idx = s.order.indexOf(id);
    if (idx < 0) return;
    final newIdx = idx + direction;
    if (newIdx < 1 || newIdx >= s.order.length) return;
    final order = [...s.order];
    final col = order.removeAt(idx);
    order.insert(newIdx, col);
    state = AsyncData(s.copyWith(order: order));
    await _dao.setOrder([for (final c in order) c.name]);
  }

  /// Reset back to the default order with all columns visible.
  Future<void> resetToDefaults() async {
    const fresh = ColumnsState(
      order: [
        ColumnId.filename,
        ColumnId.status,
        ColumnId.progress,
        ColumnId.speed,
        ColumnId.size,
        ColumnId.added,
      ],
      hidden: <ColumnId>{},
    );
    state = const AsyncData(fresh);
    await _dao.replaceAll(defaultColumnSeed());
  }
}
