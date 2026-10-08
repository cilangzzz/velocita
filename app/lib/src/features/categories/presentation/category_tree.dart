import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../categories.dart';
import '../../../localization/app_localizations.dart';
import '../../../kernel_bridge/kernel_provider.dart';
import 'category_editor_dialog.dart';

/// Sidebar selection:
///   • `null`         → "All Downloads"
///   • `'__none__'`   → "Uncategorized" (tasks not under any category dir)
///   • other string  → the [Category.id]
///
/// Defined here (instead of `downloads_screen.dart`) so the tree and
/// its callers don't form an import cycle.
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

/// Self-contained sidebar tree of categories. Renders a header section
/// (All / Uncategorized), a recursive tree of [Category]s with
/// expand/collapse + right-click context menu, and a "+ New category"
/// action at the bottom.
class CategoryTree extends ConsumerStatefulWidget {
  const CategoryTree({super.key});

  @override
  ConsumerState<CategoryTree> createState() => _CategoryTreeState();
}

class _CategoryTreeState extends ConsumerState<CategoryTree> {
  /// Set of expanded category ids. Persisted in widget state only;
  /// collapses on app restart (intentional — keeps the sidebar tidy).
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final asyncCats = ref.watch(categoriesProvider);
    final all = asyncCats.valueOrNull?.categories ?? const <Category>[];
    final selected = ref.watch(selectedCategoryProvider);

    return SizedBox(
      width: 210,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _Header(label: l.categories),
          _LeafRow(
            icon: Icons.folder_outlined,
            label: l.allDownloads,
            selected: selected == null,
            onTap: () => ref.read(selectedCategoryProvider.notifier).state =
                null,
          ),
          _LeafRow(
            icon: Icons.help_outline,
            label: l.uncategorized,
            selected: selected == '__none__',
            onTap: () => ref.read(selectedCategoryProvider.notifier).state =
                '__none__',
          ),
          const Divider(),
          if (asyncCats.isLoading)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: LinearProgressIndicator(),
            )
          else if (asyncCats.hasError)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                l.categories,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else ...[
            for (final c in rootCategories(all))
              _buildSubtree(
                c,
                all: all,
                depth: 0,
                selected: selected,
              ),
          ],
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: FilledButton.tonalIcon(
              onPressed: () => _addRoot(all),
              icon: const Icon(Icons.add),
              label: Text(l.newCategory),
            ),
          ),
        ],
      ),
    );
  }

  /// Recursive builder. Returns a single [_CategoryNodeRow] wrapped in
  /// its subtree of children (rendered when expanded).
  Widget _buildSubtree(
    Category cat, {
    required List<Category> all,
    required int depth,
    required String? selected,
  }) {
    final kids = childrenOf(all, cat.id);
    final hasKids = kids.isNotEmpty;
    final expanded = _expanded.contains(cat.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryNodeRow(
          category: cat,
          depth: depth,
          hasChildren: hasKids,
          expanded: expanded,
          selected: cat.id == selected,
          onTap: () => ref.read(selectedCategoryProvider.notifier).state =
              cat.id,
          onToggle: () => setState(() {
            if (!_expanded.add(cat.id)) _expanded.remove(cat.id);
          }),
          onContextMenu: (pos) =>
              _showCategoryMenu(context, cat, pos, all),
        ),
        if (hasKids && expanded)
          for (final k in kids)
            _buildSubtree(
              k,
              all: all,
              depth: depth + 1,
              selected: selected,
            ),
      ],
    );
  }

  Future<void> _addRoot(List<Category> all) async {
    final dl = ref.read(kernelProvider).downloadDir;
    final outcome = await showDialog<CategoryEditorOutcome>(
      context: context,
      builder: (_) => CategoryEditorDialog(
        existing: null,
        all: all,
        defaultDownloadDir: dl,
      ),
    );
    if (outcome == null ||
        outcome.action == CategoryEditorAction.cancelled ||
        outcome.category == null) {
      return;
    }
    final notifier = ref.read(categoriesProvider.notifier);
    if (outcome.action == CategoryEditorAction.created) {
      await notifier.addCategory(outcome.category!);
      ref.read(selectedCategoryProvider.notifier).state =
          outcome.category!.id;
    }
  }

  Future<void> _showCategoryMenu(
    BuildContext context,
    Category cat,
    Offset globalPosition,
    List<Category> all,
  ) async {
    final l = AppLocalizations.of(context);
    final hasChildren = all.any((c) => c.parentId == cat.id);
    final canDelete = !cat.isDefault && !hasChildren;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'addChild',
          child: _MenuItem(
            icon: Icons.create_new_folder_outlined,
            label: l.newChildCategory,
          ),
        ),
        PopupMenuItem<String>(
          value: 'rename',
          enabled: !cat.isDefault,
          child: _MenuItem(
            icon: Icons.drive_file_rename_outline,
            label: l.renameCategory,
          ),
        ),
        PopupMenuItem<String>(
          value: 'edit',
          child: _MenuItem(
            icon: Icons.tune,
            label: l.editCategory,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'openFolder',
          child: _MenuItem(
            icon: Icons.folder_open,
            label: l.openFolder,
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          enabled: canDelete,
          child: _MenuItem(
            icon: Icons.delete_outline,
            label: l.deleteCategory,
          ),
        ),
      ],
    );
    if (choice == null) return;
    switch (choice) {
      case 'addChild':
        await _addChild(cat, all);
      case 'rename':
        if (!cat.isDefault) await _rename(cat, all);
      case 'edit':
        await _edit(cat, all);
      case 'openFolder':
        await _openSaveFolder(cat);
      case 'delete':
        if (canDelete) await _confirmDelete(cat);
    }
  }

  Future<void> _addChild(Category parent, List<Category> all) async {
    final dl = ref.read(kernelProvider).downloadDir;
    final outcome = await showDialog<CategoryEditorOutcome>(
      context: context,
      builder: (_) => CategoryEditorDialog(
        existing: null,
        all: all,
        defaultDownloadDir: dl,
        initialParentId: parent.id,
      ),
    );
    if (outcome == null ||
        outcome.action != CategoryEditorAction.created ||
        outcome.category == null) {
      return;
    }
    await ref.read(categoriesProvider.notifier).addCategory(outcome.category!);
    setState(() => _expanded.add(parent.id));
    ref.read(selectedCategoryProvider.notifier).state = outcome.category!.id;
  }

  Future<void> _rename(Category cat, List<Category> all) async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController(text: cat.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.renameCategory),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == cat.name) return;
    final updated = cat.copyWith(name: newName);
    await ref.read(categoriesProvider.notifier).updateCategory(updated);
  }

  Future<void> _edit(Category cat, List<Category> all) async {
    final dl = ref.read(kernelProvider).downloadDir;
    final outcome = await showDialog<CategoryEditorOutcome>(
      context: context,
      builder: (_) => CategoryEditorDialog(
        existing: cat,
        all: all,
        defaultDownloadDir: dl,
      ),
    );
    if (outcome == null ||
        outcome.action == CategoryEditorAction.cancelled ||
        outcome.category == null) {
      return;
    }
    final notifier = ref.read(categoriesProvider.notifier);
    if (outcome.action == CategoryEditorAction.updated) {
      await notifier.updateCategory(outcome.category!);
    } else if (outcome.action == CategoryEditorAction.deleted) {
      // Re-fetch the live state (the notifier is the source of truth).
      await notifier.removeCategory(outcome.category!.id);
      if (ref.read(selectedCategoryProvider) == outcome.category!.id) {
        ref.read(selectedCategoryProvider.notifier).state = null;
      }
    }
  }

  Future<void> _openSaveFolder(Category cat) async {
    if (cat.defaultSaveDir.isEmpty) return;
    try {
      final dir = Directory(cat.defaultSaveDir);
      if (await dir.exists()) {
        await Process.start('explorer', [dir.absolute.path],
            mode: ProcessStartMode.detached);
      }
    } catch (_) {
      // Best-effort; ignore failures (locked down box, etc.).
    }
  }

  Future<void> _confirmDelete(Category cat) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteCategory),
        content: Text(l.confirmDeleteCategory),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.deleteCategory),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(categoriesProvider.notifier).removeCategory(cat.id);
    if (ref.read(selectedCategoryProvider) == cat.id) {
      ref.read(selectedCategoryProvider.notifier).state = null;
    }
  }
}

// ── Building blocks ──────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

/// Fixed-position row for the "All Downloads" and "Uncategorized" entries.
class _LeafRow extends StatelessWidget {
  const _LeafRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.35)
              : null,
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single row in the category tree. Indented by [depth] * 16 and
/// prefixed with a chevron (when there are children), the category
/// icon, and the category name. Right-click triggers the context menu.
class _CategoryNodeRow extends StatelessWidget {
  const _CategoryNodeRow({
    required this.category,
    required this.depth,
    required this.hasChildren,
    required this.expanded,
    required this.selected,
    required this.onTap,
    required this.onToggle,
    required this.onContextMenu,
  });

  final Category category;
  final int depth;
  final bool hasChildren;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final ValueChanged<Offset> onContextMenu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final indent = depth * 16.0;
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onSecondaryTapDown: (d) => onContextMenu(d.globalPosition),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 4 + indent),
              SizedBox(
                width: 18,
                height: 18,
                child: hasChildren
                    ? InkWell(
                        onTap: onToggle,
                        child: Icon(
                          expanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_right,
                          size: 16,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 4),
              Icon(categoryIcon(category.iconName), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Local copy of the table's right-click menu entry — the table's
/// `_MenuItem` is library-private and this widget is in a different
/// library.
class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18),
      const SizedBox(width: 12),
      Text(label),
    ]);
  }
}
