import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/download_task.dart';
import 'add_task_dialog.dart';
import 'task_list_provider.dart';

/// The Downloads screen — M3 surface.
///
/// Layout: sidebar (filters) | task list | toolbar
///
/// Per `docs/rule/flutter_rule/06-performance.md`, the list uses
/// `ListView.builder` (not `ListView.separated`) because the divider
/// separator is a minor visual concern; we get better scroll perf by
/// inlining the divider into the row.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskListProvider);
    final tasks = tasksAsync.value ?? <String, TaskSummary>{};
    final filter = ref.watch(taskFilterProvider);
    final entries = _applyFilter(tasks.values, filter).toList(growable: false);

    return Row(
      children: [
        const _CategorySidebar(),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              _Toolbar(
                onAdd: () => _openAddDialog(context, ref),
                onRefresh: () =>
                    ref.read(taskListProvider.notifier).refresh(),
              ),
              const Divider(height: 1),
              Expanded(
                child: entries.isEmpty
                    ? _EmptyState(filter: filter)
                    : ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, i) =>
                            _TaskRow(task: entries[i]),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Iterable<TaskSummary> _applyFilter(
      Iterable<TaskSummary> source, DownloadFilter f) {
    switch (f) {
      case DownloadFilter.all:
        return source;
      case DownloadFilter.active:
        return source.where((t) => t.isActive);
      case DownloadFilter.paused:
        return source.where((t) => t.isPaused);
      case DownloadFilter.completed:
        return source.where((t) => t.isComplete);
      case DownloadFilter.error:
        return source.where((t) => t.isError);
    }
  }

  Future<void> _openAddDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<SubmitResult>(
      context: context,
      builder: (_) => const AddTaskDialog(),
    );
    if (result == null) return;
    final notifier = ref.read(taskListProvider.notifier);
    try {
      switch (result.kind) {
        case SubmitKind.url:
          await notifier.addUri(result.url!);
        case SubmitKind.magnet:
          await notifier.addMagnet(result.magnet!);
        case SubmitKind.torrent:
          await notifier.addTorrent(result.torrentBytes!);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add failed: $e')),
      );
    }
  }
}

/// Filter state — UI-only, lives here.
enum DownloadFilter { all, active, paused, completed, error }

final taskFilterProvider = StateProvider<DownloadFilter>((ref) => DownloadFilter.all);

class _CategorySidebar extends ConsumerWidget {
  const _CategorySidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskListProvider).value ?? <String, TaskSummary>{};
    final selected = ref.watch(taskFilterProvider);
    final counts = <DownloadFilter, int>{
      DownloadFilter.all: tasks.values.length,
      DownloadFilter.active: tasks.values.where((t) => t.isActive).length,
      DownloadFilter.paused: tasks.values.where((t) => t.isPaused).length,
      DownloadFilter.completed: tasks.values.where((t) => t.isComplete).length,
      DownloadFilter.error: tasks.values.where((t) => t.isError).length,
    };

    return SizedBox(
      width: 200,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final f in DownloadFilter.values)
            ListTile(
              dense: true,
              selected: selected == f,
              leading: Icon(_iconFor(f)),
              title: Text(_labelFor(f)),
              trailing: Text('${counts[f] ?? 0}'),
              onTap: () =>
                  ref.read(taskFilterProvider.notifier).state = f,
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'CATEGORIES',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const ListTile(
            dense: true,
            leading: Icon(Icons.movie_outlined),
            title: Text('Movies'),
          ),
          const ListTile(
            dense: true,
            leading: Icon(Icons.music_note_outlined),
            title: Text('Music'),
          ),
          const ListTile(
            dense: true,
            leading: Icon(Icons.archive_outlined),
            title: Text('Archives'),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(DownloadFilter f) {
    switch (f) {
      case DownloadFilter.all:
        return Icons.list_alt;
      case DownloadFilter.active:
        return Icons.download_outlined;
      case DownloadFilter.paused:
        return Icons.pause_circle_outline;
      case DownloadFilter.completed:
        return Icons.check_circle_outline;
      case DownloadFilter.error:
        return Icons.error_outline;
    }
  }

  String _labelFor(DownloadFilter f) {
    switch (f) {
      case DownloadFilter.all:
        return 'All';
      case DownloadFilter.active:
        return 'Active';
      case DownloadFilter.paused:
        return 'Paused';
      case DownloadFilter.completed:
        return 'Completed';
      case DownloadFilter.error:
        return 'Error';
    }
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.onAdd, required this.onRefresh});

  final VoidCallback onAdd;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add URL'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});
  final DownloadFilter filter;

  @override
  Widget build(BuildContext context) {
    final msg = switch (filter) {
      DownloadFilter.all => 'No downloads yet — click "Add URL".',
      DownloadFilter.active => 'No active downloads.',
      DownloadFilter.paused => 'No paused downloads.',
      DownloadFilter.completed => 'No completed downloads.',
      DownloadFilter.error => 'No failed downloads.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_download_outlined,
              size: 96,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              msg,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task});

  final TaskSummary task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final progress = task.progress.clamp(0.0, 1.0);
    final percent = (progress * 100).toStringAsFixed(1);
    final speed = _formatSpeed(task.downloadSpeed);

    return ListTile(
      leading: Icon(
        task.isError
            ? Icons.error_outline
            : task.isComplete
                ? Icons.check_circle_outline
                : task.isPaused
                    ? Icons.pause_circle_outline
                    : Icons.download_outlined,
        color: task.isError
            ? scheme.error
            : task.isComplete
                ? scheme.primary
                : scheme.onSurface,
      ),
      title: Text(
        task.filename,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 4),
          Text(
            '${_formatBytes(task.completedLength)} / ${_formatBytes(task.totalLength)}  •  $percent%  •  $speed  •  ${task.status.name}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.isActive)
            IconButton(
              tooltip: 'Pause',
              icon: const Icon(Icons.pause),
              onPressed: () =>
                  ref.read(taskListProvider.notifier).pause(task.gid),
            ),
          if (task.isPaused)
            IconButton(
              tooltip: 'Resume',
              icon: const Icon(Icons.play_arrow),
              onPressed: () =>
                  ref.read(taskListProvider.notifier).resume(task.gid),
            ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline),
            onPressed: () =>
                ref.read(taskListProvider.notifier).remove(task.gid),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var size = bytes / 1024.0;
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${size.toStringAsFixed(1)} ${units[unit]}';
}

String _formatSpeed(int bytesPerSec) => '${_formatBytes(bytesPerSec)}/s';

