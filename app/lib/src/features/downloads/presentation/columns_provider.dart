import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

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
  late File _file;

  @override
  Future<ColumnsState> build() async {
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}/velocita/columns.json');
    await _file.parent.create(recursive: true);
    if (await _file.exists()) {
      try {
        final raw =
            jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
        final orderRaw = (raw['order'] as List?)?.cast<String>();
        final hiddenRaw = (raw['hidden'] as List?)?.cast<String>();
        if (orderRaw != null) {
          // Reconcile against the canonical set of ids. Drop unknowns,
          // append any new defaults at the end, and always force
          // filename to position 0 (locked, never re-orderable).
          final known = {for (final s in kTableColumns) s.id.name};
          final cleaned = <ColumnId>[];
          for (final name in orderRaw) {
            if (!known.contains(name)) continue;
            final id = ColumnId.values.byName(name);
            if (id == ColumnId.filename) continue; // placed explicitly below
            cleaned.add(id);
          }
          // Remove any ids that were persisted but the user no longer
          // has (defensive against future schema changes).
          for (final s in kTableColumns) {
            if (s.id == ColumnId.filename) continue;
            if (!cleaned.contains(s.id)) cleaned.add(s.id);
          }
          final hidden = <ColumnId>{};
          if (hiddenRaw != null) {
            for (final name in hiddenRaw) {
              if (!known.contains(name)) continue;
              final id = ColumnId.values.byName(name);
              if (id == ColumnId.filename) continue; // never hide filename
              hidden.add(id);
            }
          }
          return ColumnsState(
            order: [ColumnId.filename, ...cleaned],
            hidden: hidden,
          );
        }
      } catch (_) {
        // Corrupt file → fall through to defaults.
      }
    }
    return const ColumnsState(
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
  }

  Future<void> toggle(ColumnId id) async {
    if (id == ColumnId.filename) return; // locked
    final s = state.value;
    if (s == null) return;
    final hidden = {...s.hidden};
    if (!hidden.add(id)) hidden.remove(id);
    state = AsyncData(s.copyWith(hidden: hidden));
    await _persist();
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
    // Can't move past position 1 (above would be filename) or past
    // the end of the list.
    if (newIdx < 1 || newIdx >= s.order.length) return;
    final order = [...s.order];
    final col = order.removeAt(idx);
    order.insert(newIdx, col);
    state = AsyncData(s.copyWith(order: order));
    await _persist();
  }

  /// Reset back to the default order with all columns visible.
  Future<void> resetToDefaults() async {
    state = const AsyncData(ColumnsState(
      order: [
        ColumnId.filename,
        ColumnId.status,
        ColumnId.progress,
        ColumnId.speed,
        ColumnId.size,
        ColumnId.added,
      ],
      hidden: <ColumnId>{},
    ));
    await _persist();
  }

  Future<void> _persist() async {
    final s = state.value;
    if (s == null) return;
    final payload = {
      'order': s.order.map((c) => c.name).toList(),
      'hidden': s.hidden.map((c) => c.name).toList(),
    };
    try {
      await _file.writeAsString(jsonEncode(payload));
    } catch (_) {
      // Best-effort; if the disk is full the user loses the custom
      // layout but the table keeps working.
    }
  }
}
