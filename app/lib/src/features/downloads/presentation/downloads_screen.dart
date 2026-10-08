import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/categories/categories.dart';
import '../../../features/categories/presentation/category_tree.dart';
import '../../../kernel_bridge/kernel_provider.dart';
import '../../../localization/app_localizations.dart';
import '../domain/download_task.dart';
import 'add_task_dialog.dart';
import 'selected_tasks_provider.dart';
import 'task_list_provider.dart';
import 'task_visibility.dart';

/// The Downloads screen — M5 surface.
///
/// Layout (left to right):
///
///   ┌──────────┬─────────────────────────────────────────────┐
///   │ Sidebar  │ Toolbar: filter dropdown + refresh + Add URL │
///   │ filters  ├─────────────────────────────────────────────┤
///   │ + cats   │ DataTable (sortable columns)               │
///   └──────────┴─────────────────────────────────────────────┘
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskListProvider);
    final tasks = tasksAsync.value ?? const <String, TaskSummary>{};

    return Row(
      children: [
        const CategoryTree(),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Toolbar(tasks: tasks),
              const Divider(height: 1),
              Expanded(
                child: _DownloadsTable(
                  tasks: tasks.values.toList(growable: false),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.tasks});
  final Map<String, TaskSummary> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final filter = ref.watch(taskFilterProvider);
    final counts = <DownloadFilter, int>{
      DownloadFilter.all: tasks.length,
      DownloadFilter.active: tasks.values.where((t) => t.isActive).length,
      DownloadFilter.paused: tasks.values.where((t) => t.isPaused).length,
      DownloadFilter.completed: tasks.values.where((t) => t.isComplete).length,
      DownloadFilter.error: tasks.values.where((t) => t.isError).length,
    };

    final taskList = tasks.values.toList(growable: false);
    final cats = ref
            .watch(categoriesProvider)
            .valueOrNull
            ?.categories ??
        const <Category>[];
    final selectedIds = ref.watch(selectedTaskGidsProvider);
    final selectedCount = selectedIds.length;
    final selectedTasks = [
      for (final t in taskList)
        if (selectedIds.contains(t.gid)) t,
    ];
    final activeCount = selectedTasks.where((t) => t.isActive).length;
    final pausedCount = selectedTasks.where((t) => t.isPaused).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Build the two toolbar clusters once; pick a layout that fits.
          final left = <Widget>[
            // Status filter dropdown (lives in toolbar, not sidebar).
            DropdownButton<DownloadFilter>(
              value: filter,
              items: [
                for (final f in DownloadFilter.values)
                  DropdownMenuItem(
                    value: f,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_filterIcon(f), size: 16),
                        const SizedBox(width: 8),
                        Text(_filterLabel(f, l)),
                        const SizedBox(width: 4),
                        Text(
                          '${counts[f]}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref.read(taskFilterProvider.notifier).state = v;
                }
              },
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: l.refresh,
              onPressed: () =>
                  ref.read(taskListProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 4),
            if (selectedCount > 0)
              Text(
                l.selectedCount.replaceAll('N', '$selectedCount'),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.primary),
              )
            else
              Text(
                '${tasks.length} task${tasks.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ];
          final right = <Widget>[
            FilledButton.icon(
              onPressed: () => _openAddDialog(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l.addTask),
            ),
            const SizedBox(width: 8),
            _BatchOpsMenu(
              selectedCount: selectedCount,
              activeCount: activeCount,
              pausedCount: pausedCount,
              visibleTasks: applyCategoryFilter(
                applyDownloadFilter(taskList, filter),
                ref.read(selectedCategoryProvider),
                cats,
              ),
              onSelectAll: () =>
                  _selectAllVisible(ref, taskList, filter, cats),
              onInvert: () => _invertVisible(ref, taskList, filter, cats),
              onClear: () => _clearSelection(ref),
              onPause: () => _batchPause(ref, selectedIds),
              onResume: () => _batchResume(ref, selectedIds),
              onDelete: () => _batchDelete(ref, selectedIds),
            ),
          ];

          // When there's enough horizontal room, push the right cluster
          // to the trailing edge with a Spacer. When not, fall back to
          // a two-row layout: left cluster on top (start-aligned), right
          // cluster below (end-aligned).
          const breakpoint = 720.0;
          if (constraints.maxWidth >= breakpoint) {
            return Row(
              children: [
                ...left,
                const Spacer(),
                ...right,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: left,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.end,
                children: right,
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _filterIcon(DownloadFilter f) {
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

  String _filterLabel(DownloadFilter f, AppLocalizations l) {
    switch (f) {
      case DownloadFilter.all:
        return l.all;
      case DownloadFilter.active:
        return l.active;
      case DownloadFilter.paused:
        return l.paused;
      case DownloadFilter.completed:
        return l.completed;
      case DownloadFilter.error:
        return l.error;
    }
  }

  Future<void> _openAddDialog(BuildContext context, WidgetRef ref) async {
    // Pass the currently selected category so the dialog can show where the
    // download will land before the user confirms. The dialog also auto-
    // resolves a save dir from URL extension when no category is selected.
    final categoryId = ref.read(selectedCategoryProvider);
    final result = await showDialog<SubmitResult>(
      context: context,
      builder: (_) => AddTaskDialog(categoryId: categoryId),
    );
    if (result == null) return;
    final notifier = ref.read(taskListProvider.notifier);
    // Resolve save dir: explicit category > auto-detect from extension >
    // null (= use repository's default).
    final saveDir = result.saveDir ?? _resolveSaveDirFor(ref, categoryId);
    if (saveDir != null) {
      try {
        Directory(saveDir).createSync(recursive: true);
      } catch (_) {}
    }
    try {
      switch (result.kind) {
        case SubmitKind.url:
          await notifier.addUri(result.url!, saveDir: saveDir);
        case SubmitKind.magnet:
          await notifier.addMagnet(result.magnet!, saveDir: saveDir);
        case SubmitKind.torrent:
          await notifier.addTorrent(result.torrentBytes!, saveDir: saveDir);
      }
      // Auto-select the matched category so the next download of the
      // same kind defaults to it without an extra click. The category is
      // derived from the saveDir we just resolved (suffix = Videos /
      // Images / ...).
      _autoSelectFromSaveDir(ref, saveDir);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add failed: $e')),
      );
    }
  }

  /// After a successful add, set [selectedCategoryProvider] to the
  /// category whose directory matches the just-resolved [saveDir]. This
  /// keeps the sidebar highlight in sync with what the user just used.
  void _autoSelectFromSaveDir(WidgetRef ref, String? saveDir) {
    if (saveDir == null) return;
    final cats = ref
            .read(categoriesProvider)
            .valueOrNull
            ?.categories ??
        const <Category>[];
    final match = deepestCategoryForDir(cats, saveDir);
    if (match != null) {
      ref.read(selectedCategoryProvider.notifier).state = match.id;
    }
  }

  /// Resolve the save directory for the given category id. `null` means
  /// "use the default downloads dir" (i.e. no category selected).
  String? _resolveSaveDirFor(WidgetRef ref, String? categoryId) {
    if (categoryId == null || categoryId == '__none__') return null;
    final cats = ref
            .read(categoriesProvider)
            .valueOrNull
            ?.categories ??
        const <Category>[];
    final cat = categoryById(cats, categoryId);
    if (cat == null) return null;
    final dl = ref.read(kernelProvider).downloadDir;
    return resolvedSaveDir(
      all: cats,
      category: cat,
      defaultDownloadDir: dl,
    );
  }

  // ── Batch operations ──────────────────────────────────────

  void _selectAllVisible(
    WidgetRef ref,
    List<TaskSummary> tasks,
    DownloadFilter filter,
    List<Category> categories,
  ) {
    final cat = ref.read(selectedCategoryProvider);
    final visible = visibleGids(tasks, filter, cat, categories);
    final current = ref.read(selectedTaskGidsProvider);
    ref.read(selectedTaskGidsProvider.notifier).state = current.union(visible);
  }

  void _invertVisible(
    WidgetRef ref,
    List<TaskSummary> tasks,
    DownloadFilter filter,
    List<Category> categories,
  ) {
    final cat = ref.read(selectedCategoryProvider);
    final visible = visibleGids(tasks, filter, cat, categories);
    final current = ref.read(selectedTaskGidsProvider);
    ref.read(selectedTaskGidsProvider.notifier).state = {
      for (final g in current)
        if (!visible.contains(g)) g,
      for (final g in visible)
        if (!current.contains(g)) g,
    };
  }

  void _clearSelection(WidgetRef ref) {
    ref.read(selectedTaskGidsProvider.notifier).state = const <String>{};
  }

  Future<void> _batchPause(WidgetRef ref, Set<String> gids) async {
    final notifier = ref.read(taskListProvider.notifier);
    for (final g in gids) {
      try {
        await notifier.pause(g);
      } catch (_) {
        // Best-effort; surface individual failures via the engine.
      }
    }
  }

  Future<void> _batchResume(WidgetRef ref, Set<String> gids) async {
    final notifier = ref.read(taskListProvider.notifier);
    for (final g in gids) {
      try {
        await notifier.resume(g);
      } catch (_) {}
    }
  }

  Future<void> _batchDelete(WidgetRef ref, Set<String> gids) async {
    final notifier = ref.read(taskListProvider.notifier);
    for (final g in gids) {
      try {
        await notifier.removeFromHistory(g);
      } catch (_) {}
    }
    _clearSelection(ref);
  }
}

/// Sortable column id.
enum SortColumn { filename, status, progress, speed, size, added }

class _SortState {
  const _SortState({required this.column, required this.ascending});
  final SortColumn column;
  final bool ascending;

  _SortState toggleTo(SortColumn c) {
    if (column == c) {
      return _SortState(column: c, ascending: !ascending);
    }
    return _SortState(column: c, ascending: true);
  }
}

final sortStateProvider =
    StateProvider<_SortState>((ref) => const _SortState(
          column: SortColumn.added,
          ascending: false,
        ));

class _DownloadsTable extends ConsumerStatefulWidget {
  const _DownloadsTable({required this.tasks});
  final List<TaskSummary> tasks;

  @override
  ConsumerState<_DownloadsTable> createState() => _DownloadsTableState();
}

class _DownloadsTableState extends ConsumerState<_DownloadsTable> {
  /// Drives the horizontal scrollbar. Kept always visible so the user can
  /// see the table is horizontally scrollable when the window is narrower
  /// than the content.
  final ScrollController _hController = ScrollController();

  @override
  void dispose() {
    _hController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;
    final filter = ref.watch(taskFilterProvider);
    final categoryId = ref.watch(selectedCategoryProvider);
    final byStatus = _applyFilter(tasks, filter);
    final byCategory = _applyCategory(byStatus, categoryId);
    final sort = ref.watch(sortStateProvider);
    final sorted = _applySort(byCategory, sort);

    if (sorted.isEmpty) {
      return _EmptyState(filter: filter);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Column widths. Filename absorbs whatever is left over; the rest
        // are fixed so the table stays consistent as the window resizes.
        const checkboxW = 40.0;
        const statusW = 120.0;
        const progressW = 150.0;
        const speedW = 90.0;
        const sizeW = 90.0;
        const addedW = 110.0;
        const gapW = 16.0;
        // Header + every data row carry 4px of left/right padding, so the
        // columns inside must sum to width - 8 or the Row overflows by 8px
        // (the yellow/black warning stripes on the right edge).
        const sidePad = 8.0;
        const gaps = gapW * 6; // 7 columns → 6 gaps
        const fixed = checkboxW +
            statusW +
            progressW +
            speedW +
            sizeW +
            addedW +
            gaps;
        const filenameMin = 200.0;
        final tableMin = fixed + filenameMin + 16;

        final tableWidth = constraints.maxWidth > tableMin
            ? constraints.maxWidth
            : tableMin;
        final filenameW = tableWidth - fixed - sidePad;

        Widget hGap() => const SizedBox(width: gapW);

        /// A clickable header cell sharing the body's column width.
        Widget headerCell(String label, SortColumn id, double w) {
          final active = sort.column == id;
          return SizedBox(
            width: w,
            child: InkWell(
              onTap: () {
                ref.read(sortStateProvider.notifier).state =
                    ref.read(sortStateProvider).toggleTo(id);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  if (active) ...[
                    const SizedBox(width: 4),
                    Icon(
                      sort.ascending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        final dividerColor = Theme.of(context).dividerColor;
        final scheme = Theme.of(context).colorScheme;

        return Padding(
          padding: const EdgeInsets.all(8),
          child: Scrollbar(
            controller: _hController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _hController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header (stays fixed while rows scroll) ──
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: dividerColor),
                        ),
                      ),
                      child: Row(
                        children: [
                          _HeaderCheckboxCell(
                            width: checkboxW,
                            visible: sorted.map((t) => t.gid).toSet(),
                            selected:
                                ref.watch(selectedTaskGidsProvider),
                            onToggle: () => _toggleSelectAll(sorted),
                          ),
                          hGap(),
                          headerCell('Filename', SortColumn.filename, filenameW),
                          hGap(),
                          headerCell('Status', SortColumn.status, statusW),
                          hGap(),
                          headerCell('Progress', SortColumn.progress, progressW),
                          hGap(),
                          headerCell('Speed', SortColumn.speed, speedW),
                          hGap(),
                          headerCell('Size', SortColumn.size, sizeW),
                          hGap(),
                          headerCell('Added', SortColumn.added, addedW),
                        ],
                      ),
                    ),
                    // ── Rows (scroll vertically under the fixed header) ──
                    Expanded(
                      child: ListView.builder(
                        itemCount: sorted.length,
                        itemExtent: 44,
                        itemBuilder: (context, i) {
                          final t = sorted[i];
                          final isSelected = ref.watch(
                            selectedTaskGidsProvider
                                .select((s) => s.contains(t.gid)),
                          );
                          return Material(
                            color: isSelected
                                ? scheme.primaryContainer
                                    .withValues(alpha: 0.35)
                                : Colors.transparent,
                            child: InkWell(
                              onTap: () => _toggleGid(t.gid),
                              onSecondaryTapDown: (d) {
                                _showRowMenu(
                                    context, d.globalPosition, t);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: dividerColor),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _RowCheckboxCell(
                                      width: checkboxW,
                                      selected: isSelected,
                                      onTap: () => _toggleGid(t.gid),
                                    ),
                                    hGap(),
                                    SizedBox(
                                      width: filenameW,
                                      child: Text(
                                        t.filename,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                      ),
                                    ),
                                    hGap(),
                                    SizedBox(
                                      width: statusW,
                                      child: _StatusChip(status: t.status),
                                    ),
                                    hGap(),
                                    SizedBox(
                                      width: progressW,
                                      child: LinearProgressIndicator(
                                        value: t.progress.clamp(0.0, 1.0),
                                        minHeight: 6,
                                      ),
                                    ),
                                    hGap(),
                                    SizedBox(
                                      width: speedW,
                                      child: _ellipsisText(
                                          _formatSpeed(t.downloadSpeed)),
                                    ),
                                    hGap(),
                                    SizedBox(
                                      width: sizeW,
                                      child: _ellipsisText(
                                          _formatBytes(t.totalLength)),
                                    ),
                                    hGap(),
                                    SizedBox(
                                      width: addedW,
                                      child:
                                          _ellipsisText(_relativeTime(t)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Overflow-safe text cell for narrow columns.
  Widget _ellipsisText(String text) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      );

  /// Toggle [gid]'s membership in the global selection set.
  void _toggleGid(String gid) {
    final notifier = ref.read(selectedTaskGidsProvider.notifier);
    final current = ref.read(selectedTaskGidsProvider);
    final next = {...current};
    if (!next.add(gid)) next.remove(gid);
    notifier.state = next;
  }

  /// Toggle the membership of every currently-visible gid. If every
  /// visible row is already selected, clear all of them; otherwise
  /// select all of them.
  void _toggleSelectAll(List<TaskSummary> visible) {
    final notifier = ref.read(selectedTaskGidsProvider.notifier);
    final current = ref.read(selectedTaskGidsProvider);
    final visibleGids = visible.map((t) => t.gid).toSet();
    final allSelected = visibleGids.every(current.contains);
    final next = allSelected
        ? (current.difference(visibleGids))
        : current.union(visibleGids);
    notifier.state = next;
  }

  /// Right-click menu on the selected row. Only shows actions valid for the
  /// task's current status; "Open folder" and "Remove from history" are
  /// always available.
  Future<void> _showRowMenu(
    BuildContext context,
    Offset globalPosition,
    TaskSummary t,
  ) async {
    final l = AppLocalizations.of(context);
    final notifier = ref.read(taskListProvider.notifier);
    final items = <PopupMenuEntry<String>>[
      if (t.isActive)
        PopupMenuItem(
          value: 'pause',
          child: _MenuItem(icon: Icons.pause, label: l.pauseTask),
        ),
      if (t.isPaused)
        PopupMenuItem(
          value: 'resume',
          child: _MenuItem(icon: Icons.play_arrow, label: l.resumeTask),
        ),
      PopupMenuItem(
        value: 'openFolder',
        child: _MenuItem(icon: Icons.folder_open, label: l.openFolder),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'remove',
        child:
            _MenuItem(icon: Icons.delete_outline, label: l.removeFromHistory),
      ),
    ];
    final choice = await showMenu<String>(
      context: context,
      // A zero-size rect anchored at the pointer position.
      position: RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy,
          globalPosition.dx, globalPosition.dy),
      items: items,
    );
    switch (choice) {
      case 'pause':
        await notifier.pause(t.gid);
      case 'resume':
        await notifier.resume(t.gid);
      case 'openFolder':
        await _openFolder(t);
      case 'remove':
        await notifier.removeFromHistory(t.gid);
    }
  }

  /// Open the task's file (selecting it) or its containing directory in
  /// Explorer. Best-effort: silently returns if the path no longer exists.
  Future<void> _openFolder(TaskSummary t) async {
    final dir = t.dir;
    final name = t.filename;
    if (dir.isEmpty || name.isEmpty) return;
    final sep = Platform.pathSeparator;
    final cleanDir =
        dir.endsWith(sep) ? dir.substring(0, dir.length - 1) : dir;
    final file = File('$cleanDir$sep$name');
    if (await file.exists()) {
      await Process.start(
        'explorer',
        ['/select,${file.absolute.path}'],
        mode: ProcessStartMode.detached,
      );
    } else {
      final d = Directory(dir);
      if (await d.exists()) {
        await Process.start(
          'explorer',
          [d.absolute.path],
          mode: ProcessStartMode.detached,
        );
      }
    }
  }

  List<TaskSummary> _applySort(List<TaskSummary> source, _SortState s) {
    final list = [...source];
    int cmp(TaskSummary a, TaskSummary b) {
      switch (s.column) {
        case SortColumn.filename:
          return a.filename.compareTo(b.filename);
        case SortColumn.status:
          return a.status.index.compareTo(b.status.index);
        case SortColumn.progress:
          return a.progress.compareTo(b.progress);
        case SortColumn.speed:
          return a.downloadSpeed.compareTo(b.downloadSpeed);
        case SortColumn.size:
          return a.totalLength.compareTo(b.totalLength);
        case SortColumn.added:
          return a.gid.compareTo(b.gid);
      }
    }

    list.sort((a, b) {
      final r = cmp(a, b);
      return s.ascending ? r : -r;
    });
    return list;
  }

  List<TaskSummary> _applyFilter(
      List<TaskSummary> source, DownloadFilter f) {
    return applyDownloadFilter(source, f);
  }

  /// Apply category filter on top of the status filter.
  ///
  /// Reads the live [categoriesProvider] (or an empty list while it's
  /// loading) and matches each task against the selected node. Selecting
  /// a parent category aggregates all of its descendants' tasks.
  List<TaskSummary> _applyCategory(
      List<TaskSummary> source, String? categoryId) {
    final cats = ref
            .watch(categoriesProvider)
            .valueOrNull
            ?.categories ??
        const <Category>[];
    return applyCategoryFilter(source, categoryId, cats);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final DownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color fg;
    IconData icon;
    String label;
    switch (status) {
      case DownloadStatus.active:
        fg = scheme.primary;
        icon = Icons.download_outlined;
        label = 'Active';
      case DownloadStatus.waiting:
        fg = scheme.tertiary;
        icon = Icons.hourglass_empty;
        label = 'Waiting';
      case DownloadStatus.paused:
        fg = scheme.secondary;
        icon = Icons.pause_circle_outline;
        label = 'Paused';
      case DownloadStatus.complete:
        fg = scheme.primary;
        icon = Icons.check_circle_outline;
        label = 'Complete';
      case DownloadStatus.error:
        fg = scheme.error;
        icon = Icons.error_outline;
        label = 'Error';
      case DownloadStatus.removed:
        fg = scheme.outline;
        icon = Icons.delete_outline;
        label = 'Removed';
      case DownloadStatus.unknown:
        fg = scheme.outline;
        icon = Icons.help_outline;
        label = 'Unknown';
    }
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(color: fg, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// An icon + label row for a context-menu entry.
class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});
  final DownloadFilter filter;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final msg = switch (filter) {
      DownloadFilter.all => l.noDownloads,
      DownloadFilter.active => l.noActive,
      DownloadFilter.paused => l.noPaused,
      DownloadFilter.completed => l.noCompleted,
      DownloadFilter.error => l.noError,
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

String _formatSpeed(int bytesPerSec) =>
    bytesPerSec == 0 ? '-' : '${_formatBytes(bytesPerSec)}/s';

/// Cheap stand-in: gid is created at task add time; we don't persist the
/// add timestamp in M4 history.json so we show gid suffix as a stand-in.
String _relativeTime(TaskSummary t) {
  final ts = t.addedAt ?? t.completedAt;
  if (ts == null) return '—';
  final delta = DateTime.now().difference(ts);
  if (delta.inSeconds.abs() < 60) return 'just now';
  if (delta.inMinutes.abs() < 60) {
    return '${delta.inMinutes.abs()} min ago';
  }
  if (delta.inHours.abs() < 24) {
    return '${delta.inHours.abs()}h ago';
  }
  if (delta.inDays.abs() < 7) {
    return '${delta.inDays.abs()}d ago';
  }
  final m = ts.month.toString().padLeft(2, '0');
  final d = ts.day.toString().padLeft(2, '0');
  return '${ts.year}-$m-$d';
}

/// Header checkbox that shows the aggregate state of the currently
/// visible rows and toggles all of them on tap.
class _HeaderCheckboxCell extends StatelessWidget {
  const _HeaderCheckboxCell({
    required this.width,
    required this.visible,
    required this.selected,
    required this.onToggle,
  });

  final double width;
  final Set<String> visible;
  final Set<String> selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final selectedVisible = visible.intersection(selected).length;
    final bool allSelected = visible.isNotEmpty &&
        selectedVisible == visible.length;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Checkbox(
            value: allSelected,
            tristate: false,
            // The indeterminate state is implied by the empty-but-
            // not-empty visible set (some selected, not all).
            onChanged: visible.isEmpty
                ? null
                : (_) {
                    onToggle();
                  },
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}

/// Per-row checkbox. A tap on the cell body also toggles — the whole
/// row is a click target, so a tiny 18px checkbox would be too easy to
/// miss. The actual visual state is rendered as a checkbox to keep
/// the header and rows visually consistent.
class _RowCheckboxCell extends StatelessWidget {
  const _RowCheckboxCell({
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Checkbox(
            value: selected,
            tristate: false,
            onChanged: (_) => onTap(),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}

/// "Batch operations" menu shown in the toolbar. Surfaces the
/// select-all / invert / clear actions and the batch pause / resume /
/// delete actions, with each action disabled when not applicable (e.g.
/// pause is disabled when none of the selected tasks is active).
class _BatchOpsMenu extends StatelessWidget {
  const _BatchOpsMenu({
    required this.selectedCount,
    required this.activeCount,
    required this.pausedCount,
    required this.visibleTasks,
    required this.onSelectAll,
    required this.onInvert,
    required this.onClear,
    required this.onPause,
    required this.onResume,
    required this.onDelete,
  });

  final int selectedCount;
  final int activeCount;
  final int pausedCount;
  final List<TaskSummary> visibleTasks;
  final VoidCallback onSelectAll;
  final VoidCallback onInvert;
  final VoidCallback onClear;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasSelection = selectedCount > 0;
    final hasVisible = visibleTasks.isNotEmpty;
    return PopupMenuButton<_BatchAction>(
      tooltip: l.batchOps,
      onSelected: (action) {
        switch (action) {
          case _BatchAction.selectAll:
            onSelectAll();
          case _BatchAction.invert:
            onInvert();
          case _BatchAction.clear:
            onClear();
          case _BatchAction.pause:
            onPause();
          case _BatchAction.resume:
            onResume();
          case _BatchAction.delete:
            onDelete();
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: _BatchAction.selectAll,
          enabled: hasVisible,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.done_all, size: 18),
              const SizedBox(width: 12),
              Text(l.selectAll),
            ],
          ),
        ),
        PopupMenuItem(
          value: _BatchAction.invert,
          enabled: hasVisible,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.swap_vert, size: 18),
              const SizedBox(width: 12),
              Text(l.invertSelection),
            ],
          ),
        ),
        PopupMenuItem(
          value: _BatchAction.clear,
          enabled: hasSelection,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.close, size: 18),
              const SizedBox(width: 12),
              Text(l.clearSelection),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _BatchAction.pause,
          enabled: hasSelection && activeCount > 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pause, size: 18),
              const SizedBox(width: 12),
              Text('${l.pauseTask} ($activeCount)'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _BatchAction.resume,
          enabled: hasSelection && pausedCount > 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow, size: 18),
              const SizedBox(width: 12),
              Text('${l.resumeTask} ($pausedCount)'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _BatchAction.delete,
          enabled: hasSelection,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline,
                  size: 18, color: Theme.of(ctx).colorScheme.error),
              const SizedBox(width: 12),
              Text(l.removeFromHistory),
            ],
          ),
        ),
      ],
      child: FilledButton.tonalIcon(
        onPressed: null,
        icon: const Icon(Icons.checklist),
        label: Text(
          selectedCount > 0 ? '${l.batchOps} ($selectedCount)' : l.batchOps,
        ),
      ),
    );
  }
}

enum _BatchAction {
  selectAll,
  invert,
  clear,
  pause,
  resume,
  delete,
}
