import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../kernel_bridge/kernel_provider.dart';
import '../../../localization/app_localizations.dart';
import '../domain/download_task.dart';
import 'add_task_dialog.dart';
import 'task_list_provider.dart';

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
        const _CategorySidebar(),
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

class _CategorySidebar extends ConsumerWidget {
  const _CategorySidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final selected = ref.watch(selectedCategoryProvider);
    return SizedBox(
      width: 180,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l.categories,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.folder_outlined),
            title: Text(l.allDownloads),
            selected: selected == null,
            onTap: () => ref.read(selectedCategoryProvider.notifier).state = null,
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.help_outline),
            title: Text(l.uncategorized),
            selected: selected == '__none__',
            onTap: () =>
                ref.read(selectedCategoryProvider.notifier).state = '__none__',
          ),
          const Divider(),
          _CategoryRow(
            icon: Icons.movie_outlined,
            label: l.movies,
            id: 'video',
            selected: selected == 'video',
            onTap: () =>
                ref.read(selectedCategoryProvider.notifier).state = 'video',
          ),
          _CategoryRow(
            icon: Icons.music_note_outlined,
            label: l.music,
            id: 'music',
            selected: selected == 'music',
            onTap: () =>
                ref.read(selectedCategoryProvider.notifier).state = 'music',
          ),
          _CategoryRow(
            icon: Icons.archive_outlined,
            label: l.archives,
            id: 'archive',
            selected: selected == 'archive',
            onTap: () =>
                ref.read(selectedCategoryProvider.notifier).state = 'archive',
          ),
          _CategoryRow(
            icon: Icons.picture_as_pdf_outlined,
            label: l.documents,
            id: 'document',
            selected: selected == 'document',
            onTap: () =>
                ref.read(selectedCategoryProvider.notifier).state = 'document',
          ),
          _CategoryRow(
            icon: Icons.adb_outlined,
            label: l.programs,
            id: 'program',
            selected: selected == 'program',
            onTap: () =>
                ref.read(selectedCategoryProvider.notifier).state = 'program',
          ),
          _CategoryRow(
            icon: Icons.image_outlined,
            label: l.images,
            id: 'image',
            selected: selected == 'image',
            onTap: () =>
                ref.read(selectedCategoryProvider.notifier).state = 'image',
          ),
          _CategoryRow(
            icon: Icons.folder_off_outlined,
            label: l.other,
            id: 'other',
            selected: selected == 'other',
            onTap: () =>
                ref.read(selectedCategoryProvider.notifier).state = 'other',
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l.settings,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.tune),
            title: Text(l.manageCategories),
            onTap: () => _showCategoriesInfo(context),
          ),
        ],
      ),
    );
  }

  void _showCategoriesInfo(BuildContext context) {
    final l = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.defaultCategoriesTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.defaultCategoriesIntro),
              const SizedBox(height: 12),
              _CategoryInfoRow(
                  icon: Icons.movie_outlined,
                  title: l.movies,
                  extensions: '.mp4 .mkv .avi .mov .webm'),
              _CategoryInfoRow(
                  icon: Icons.music_note_outlined,
                  title: l.music,
                  extensions: '.mp3 .flac .wav .aac'),
              _CategoryInfoRow(
                  icon: Icons.archive_outlined,
                  title: l.archives,
                  extensions: '.zip .rar .7z .tar .gz'),
              _CategoryInfoRow(
                  icon: Icons.picture_as_pdf_outlined,
                  title: l.documents,
                  extensions: '.pdf .doc .docx .txt'),
              _CategoryInfoRow(
                  icon: Icons.adb_outlined,
                  title: l.programs,
                  extensions: '.exe .msi .dmg .deb'),
              _CategoryInfoRow(
                  icon: Icons.image_outlined,
                  title: l.images,
                  extensions: '.jpg .jpeg .png .gif .webp'),
              const SizedBox(height: 12),
              Text(
                l.defaultCategoriesFooter,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.close),
          ),
        ],
      ),
    );
  }
}

class _CategoryInfoRow extends StatelessWidget {
  const _CategoryInfoRow({
    required this.icon,
    required this.title,
    required this.extensions,
  });
  final IconData icon;
  final String title;
  final String extensions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  extensions,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.icon,
    required this.label,
    required this.id,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon),
      title: Text(label),
      selected: selected,
      onTap: onTap,
    );
  }
}

/// Sidebar selection — null means "all", `'__none__'` means "uncategorized",
/// otherwise it's the category id.
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
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
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
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
          const SizedBox(width: 12),
          IconButton(
            tooltip: l.refresh,
            onPressed: () =>
                ref.read(taskListProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
          Text(
            '${tasks.length} task${tasks.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => _openAddDialog(context, ref),
            icon: const Icon(Icons.add),
            label: Text(l.addTask),
          ),
        ],
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
    for (final c in _categorySpecs) {
      // Match the trailing segment; the saveDir we produced always ends
      // with `\${c.dirName}`.
      final needle = '\\${c.dirName}';
      if (saveDir.toLowerCase().endsWith(needle.toLowerCase())) {
        ref.read(selectedCategoryProvider.notifier).state = c.id;
        return;
      }
    }
  }

  /// Resolve the save directory for the given category id. `null` means
  /// "use the default downloads dir" (i.e. no category selected).
  String? _resolveSaveDirFor(WidgetRef ref, String? categoryId) {
    if (categoryId == null || categoryId == '__none__') return null;
    final appSupport = ref.read(kernelProvider).downloadDir;
    for (final c in _categorySpecs) {
      if (c.id == categoryId) return '$appSupport\\${c.dirName}';
    }
    return null;
  }
}

/// Filter state — UI-only, lives here.
enum DownloadFilter { all, active, paused, completed, error }

final taskFilterProvider =
    StateProvider<DownloadFilter>((ref) => DownloadFilter.all);

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

class _DownloadsTable extends ConsumerWidget {
  const _DownloadsTable({required this.tasks});
  final List<TaskSummary> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        // Pick a compact column-spacing based on available width so the
        // table breathes on large screens but stays dense on small ones.
        final wide = constraints.maxWidth > 900;
        final compact = wide ? 24.0 : 12.0;

        // Min width: ensure all columns are wide enough to be readable.
        // Sum of all fixed columns + spacing + filename minimum.
        const fixedCols = 100.0 + 140.0 + 90.0 + 90.0 + 90.0 + 50.0;
        final minWidth = constraints.maxWidth > 720
            ? constraints.maxWidth
            : (fixedCols + 240.0 + compact * 6 + 60); // header cells + filename min + padding

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: minWidth),
              child: DataTable(
                sortColumnIndex: SortColumn.values.indexOf(sort.column),
                sortAscending: sort.ascending,
                columnSpacing: compact,
                headingRowHeight: 36,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 44,
                columns: [
                  DataColumn(
                    label: const _HeaderCell(
                        icon: Icons.text_fields, label: 'Filename'),
                    onSort: (col, asc) {
                      ref.read(sortStateProvider.notifier).state =
                          ref.read(sortStateProvider).toggleTo(SortColumn.filename);
                    },
                  ),
                  _fixedCol(
                    ref,
                    icon: Icons.info_outline,
                    label: 'Status',
                    id: SortColumn.status,
                    width: wide ? 100 : 80,
                  ),
                  _fixedCol(
                    ref,
                    icon: Icons.linear_scale,
                    label: 'Progress',
                    id: SortColumn.progress,
                    width: wide ? 140 : 110,
                  ),
                  _fixedCol(
                    ref,
                    icon: Icons.speed,
                    label: 'Speed',
                    id: SortColumn.speed,
                    width: wide ? 90 : 70,
                  ),
                  _fixedCol(
                    ref,
                    icon: Icons.storage,
                    label: 'Size',
                    id: SortColumn.size,
                    width: wide ? 90 : 70,
                  ),
                  _fixedCol(
                    ref,
                    icon: Icons.schedule,
                    label: 'Added',
                    id: SortColumn.added,
                    width: wide ? 90 : 70,
                  ),
                  DataColumn(
                    label: const SizedBox.shrink(),
                    numeric: false,
                    columnWidth: const IntrinsicColumnWidth(),
                  ),
                ],
                rows: [
                  for (final t in sorted)
                    DataRow(
                      cells: [
                        DataCell(
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: wide ? 180 : 140,
                              maxWidth: wide ? 320 : 200,
                            ),
                            child: Text(
                              t.filename,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(_StatusChip(status: t.status)),
                        DataCell(
                          SizedBox(
                            width: wide ? 140 : 110,
                            child: LinearProgressIndicator(
                              value: t.progress.clamp(0.0, 1.0),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        DataCell(Text(_formatSpeed(t.downloadSpeed))),
                        DataCell(Text(_formatBytes(t.totalLength))),
                        DataCell(Text(_relativeTime(t))),
                        DataCell(_RowActions(task: t)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  DataColumn _fixedCol(
    WidgetRef ref, {
    required IconData icon,
    required String label,
    required SortColumn id,
    required double width,
  }) {
    return DataColumn(
      label: _HeaderCell(icon: icon, label: label),
      numeric: false,
      columnWidth: FixedColumnWidth(width),
      onSort: (col, asc) {
        ref.read(sortStateProvider.notifier).state =
            ref.read(sortStateProvider).toggleTo(id);
      },
    );
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
    switch (f) {
      case DownloadFilter.all:
        return source;
      case DownloadFilter.active:
        return source.where((t) => t.isActive).toList();
      case DownloadFilter.paused:
        return source.where((t) => t.isPaused).toList();
      case DownloadFilter.completed:
        return source.where((t) => t.isComplete).toList();
      case DownloadFilter.error:
        return source.where((t) => t.isError).toList();
    }
  }

  /// Apply category filter on top of the status filter.
  ///
  /// We derive the category from the saved directory name. When a download
  /// is added via `addUri(url, saveDir: categorySaveDir)`, aria2 returns
  /// the resolved path in `task.dir`. We then match by directory name
  /// (e.g. "Videos" / "Music") so users can route retroactively without
  /// needing a `categoryId` field on every TaskSummary.
  List<TaskSummary> _applyCategory(
      List<TaskSummary> source, String? categoryId) {
    if (categoryId == null) return source;
    if (categoryId == '__none__') {
      // Tasks whose dir is NOT one of the six default categories.
      return source
          .where((t) => !_matchesAnyDefaultCategory(t))
          .toList();
    }
    final category = _defaultCategories
        .firstWhere((c) => c.$1 == categoryId, orElse: () => ('', '', ''));
    if (category.$1.isEmpty) return source;
    final dirFragment = category.$2; // e.g. "Videos", "Music"
    return source.where((t) => _belongsTo(t, dirFragment)).toList();
  }

  /// True iff `t.dir`'s last path segment equals [dirFragment] (case-insensitive,
  /// Windows or POSIX separators).
  ///
  /// Matches:
  ///   • `E:\download\Images`         → ends with `Images`
  ///   • `E:\download\Images\`        → ends with `Images\`
  ///   • `Images`                     → equals
  ///   • `/download/Images`           → ends with `Images` / `Images/`
  bool _belongsTo(TaskSummary t, String dirFragment) {
    if (t.dir.isEmpty) return false;
    final d = t.dir.toLowerCase();
    final f = dirFragment.toLowerCase();
    if (d == f) return true;
    return d.endsWith(f) ||
        d.endsWith('\\$f') ||
        d.endsWith('/$f') ||
        d.endsWith('\\$f\\') ||
        d.endsWith('/$f/');
  }

  bool _matchesAnyDefaultCategory(TaskSummary t) {
    for (final c in _defaultCategories) {
      if (_belongsTo(t, c.$2)) return true;
    }
    return false;
  }

  /// (id, dirName, defaultSubDir) — kept tiny for the in-memory filter.
  static const List<(String, String, String)> _defaultCategories = [
    ('video', 'Videos', ''),
    ('music', 'Music', ''),
    ('archive', 'Archives', ''),
    ('document', 'Documents', ''),
    ('program', 'Programs', ''),
    ('image', 'Images', ''),
    ('other', 'Other', ''),
  ];
}

/// Top-level category specs — shared between filter + add-task save-dir.
const List<_CategorySpec> _categorySpecs = [
  _CategorySpec(
    id: 'video',
    dirName: 'Videos',
    extensions: ['.mp4', '.mkv', '.avi', '.mov', '.webm', '.flv', '.wmv', '.m4v'],
  ),
  _CategorySpec(
    id: 'music',
    dirName: 'Music',
    extensions: ['.mp3', '.flac', '.wav', '.aac', '.ogg', '.m4a', '.opus'],
  ),
  _CategorySpec(
    id: 'document',
    dirName: 'Documents',
    extensions: ['.pdf', '.doc', '.docx', '.txt', '.md', '.rtf', '.odt'],
  ),
  _CategorySpec(
    id: 'archive',
    dirName: 'Archives',
    extensions: ['.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz'],
  ),
  _CategorySpec(
    id: 'program',
    dirName: 'Programs',
    extensions: ['.exe', '.msi', '.dmg', '.deb', '.rpm', '.appimage'],
  ),
  _CategorySpec(
    id: 'image',
    dirName: 'Images',
    extensions: ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.bmp'],
  ),
];

class _CategorySpec {
  const _CategorySpec({
    required this.id,
    required this.dirName,
    required this.extensions,
  });
  final String id;
  final String dirName;
  final List<String> extensions;
}

/// Compact icon + label header cell used by every sortable column.
///
/// Uses [MainAxisSize.max] + [Expanded] around the label so the column
/// stays at its declared width even when the label text is long.
class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: fg, fontSize: 12)),
      ],
    );
  }
}

class _RowActions extends ConsumerWidget {
  const _RowActions({required this.task});
  final TaskSummary task;

  String? get _localPath {
    final dir = task.dir;
    final name = task.filename;
    if (dir.isEmpty || name.isEmpty) return null;
    // Normalize path separators on Windows.
    final sep = Platform.pathSeparator;
    final cleanDir = dir.endsWith(sep) ? dir.substring(0, dir.length - 1) : dir;
    return '$cleanDir$sep$name';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(taskListProvider.notifier);
    final path = _localPath;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (task.isActive)
          IconButton(
            tooltip: 'Pause',
            icon: const Icon(Icons.pause, size: 18),
            onPressed: () => notifier.pause(task.gid),
          ),
        if (task.isPaused)
          IconButton(
            tooltip: 'Resume',
            icon: const Icon(Icons.play_arrow, size: 18),
            onPressed: () => notifier.resume(task.gid),
          ),
        if (task.isComplete || task.isPaused || task.isError)
          IconButton(
            tooltip: 'Open folder',
            icon: const Icon(Icons.folder_open, size: 18),
            onPressed: () async {
              if (path == null) return;
              // If the file exists, select it; otherwise just open the
              // containing directory.
              final file = File(path);
              if (await file.exists()) {
                await Process.start(
                  'explorer',
                  ['/select,${file.absolute.path}'],
                  mode: ProcessStartMode.detached,
                );
              } else if (task.dir.isNotEmpty) {
                final dir = Directory(task.dir);
                if (await dir.exists()) {
                  await Process.start(
                    'explorer',
                    [dir.absolute.path],
                    mode: ProcessStartMode.detached,
                  );
                }
              }
            },
          ),
        IconButton(
          tooltip: 'Remove from history',
          icon: const Icon(Icons.delete_outline, size: 18),
          onPressed: () => notifier.removeFromHistory(task.gid),
        ),
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
