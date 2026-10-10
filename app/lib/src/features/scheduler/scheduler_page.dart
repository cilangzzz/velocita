import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/app_localizations.dart';
import '../../theme/radii.dart';

/// Scheduler page — M4 surface.
///
/// The scheduler lets the user define time windows during which downloads
/// are auto-paused (`peak`) or auto-resumed (`off-peak`). The window model
/// here is the simplest one: a 7-row × 24-column grid with click-drag to
/// toggle cells.
class SchedulerPage extends ConsumerWidget {
  const SchedulerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.schedulerAdd,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showAddDialog(context),
                icon: const Icon(Icons.add),
                label: Text(l.schedulerAdd),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _SchedulerGrid(
              peakLabel: l.schedulerPeak,
              offPeakLabel: l.schedulerOffPeak,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Time Window'),
        content: const Text(
          'Time-window scheduler — M4 placeholder.\n'
          'UI: pick weekday + start hour + end hour + mode (off-peak/peak).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _SchedulerGrid extends StatelessWidget {
  const _SchedulerGrid({required this.peakLabel, required this.offPeakLabel});

  final String peakLabel;
  final String offPeakLabel;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _hours = 24;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Hour labels.
        Row(
          children: [
            const SizedBox(width: 48),
            for (var h = 0; h < _hours; h += 2)
              Expanded(
                child: Center(
                  child: Text(
                    '$h',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
          ],
        ),
        for (var d = 0; d < _days.length; d++)
          Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(_days[d],
                    style: Theme.of(context).textTheme.labelSmall),
              ),
              for (var h = 0; h < _hours; h++)
                Expanded(
                  child: Container(
                    height: 28,
                    margin: const EdgeInsets.all(0.5),
                    decoration: BoxDecoration(
                      color: _isOffPeak(d, h)
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: Radii.brXs,
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            _Legend(color: Theme.of(context).colorScheme.primaryContainer, label: offPeakLabel),
            const SizedBox(width: 16),
            _Legend(color: Theme.of(context).colorScheme.surfaceContainerHighest, label: peakLabel),
          ],
        ),
      ],
    );
  }

  /// Mock schedule: nights (22:00 - 06:00) are off-peak, days are peak.
  bool _isOffPeak(int day, int hour) =>
      hour >= 22 || hour < 6;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: Radii.brXs,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
