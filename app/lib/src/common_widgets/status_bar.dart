import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../kernel_bridge/kernel_provider.dart';

/// Persistent status bar showing engine state, process pid, and version.
///
/// M1 surface: a static read of the kernel facade. M2 will subscribe to
/// `EngineSupervisor.events` and animate transitions.
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kernel = ref.watch(kernelProvider);
    final version = kernel.engineInfo.version;
    final pid = kernel.processManager.pid;
    final running = kernel.processManager.isRunning;

    final scheme = Theme.of(context).colorScheme;
    final statusColor = running ? scheme.primary : scheme.error;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: scheme.outlineVariant, width: 1)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: statusColor),
          const SizedBox(width: 8),
          Text(
            running ? 'Engine: Connected' : 'Engine: Disconnected',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 12),
          Text(
            'aria2 $version',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Spacer(),
          Text(
            'pid $pid',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
