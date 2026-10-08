import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../localization/app_localizations.dart';
import 'columns_provider.dart';

/// Modal dialog for showing/hiding and reordering the table columns.
///
/// Filename is locked (always first, always visible). The dialog
/// reflects that — its checkbox is disabled, its move-up button is
/// disabled, and `ColumnsNotifier.toggle/move` short-circuit on it
/// anyway as a defense-in-depth measure.
class ColumnsDialog extends ConsumerWidget {
  const ColumnsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final asyncState = ref.watch(columnsProvider);
    return AlertDialog(
      title: Text(l.customizeColumns),
      content: SizedBox(
        width: 360,
        child: asyncState.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Failed to load column config: $e'),
          ),
          data: (s) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final id in s.order)
                _ColumnRow(
                  id: id,
                  isFirst: s.order.indexOf(id) == 0,
                  isLast: s.order.indexOf(id) == s.order.length - 1,
                  visible: s.isVisible(id),
                  onToggle: () => ref
                      .read(columnsProvider.notifier)
                      .toggle(id),
                  onMove: (direction) => ref
                      .read(columnsProvider.notifier)
                      .move(id, direction),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              ref.read(columnsProvider.notifier).resetToDefaults(),
          child: Text(l.resetColumns),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.close),
        ),
      ],
    );
  }
}

class _ColumnRow extends StatelessWidget {
  const _ColumnRow({
    required this.id,
    required this.isFirst,
    required this.isLast,
    required this.visible,
    required this.onToggle,
    required this.onMove,
  });

  final ColumnId id;
  final bool isFirst;
  final bool isLast;
  final bool visible;
  final VoidCallback onToggle;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final spec = specOf(id);
    final locked = spec.locked;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Checkbox(
            value: visible || locked,
            tristate: false,
            // Filename is locked: checkbox always on, can't be toggled.
            onChanged: locked ? null : (_) => onToggle(),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _labelFor(l, id),
              style: TextStyle(
                fontWeight: locked ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (locked)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: l.columnLocked,
                child: const Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: Colors.grey,
                ),
              ),
            ),
          IconButton(
            tooltip: l.moveUp,
            // Filename is at position 0 and is the head of the list —
            // the row above it doesn't exist.
            onPressed: isFirst || locked ? null : () => onMove(-1),
            icon: const Icon(Icons.arrow_upward, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: l.moveDown,
            onPressed: isLast ? null : () => onMove(1),
            icon: const Icon(Icons.arrow_downward, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

String _labelFor(AppLocalizations l, ColumnId id) {
  switch (id) {
    case ColumnId.filename:
      return l.columnFilename;
    case ColumnId.status:
      return l.columnStatus;
    case ColumnId.progress:
      return l.columnProgress;
    case ColumnId.speed:
      return l.columnSpeed;
    case ColumnId.size:
      return l.columnSize;
    case ColumnId.added:
      return l.columnAdded;
  }
}
