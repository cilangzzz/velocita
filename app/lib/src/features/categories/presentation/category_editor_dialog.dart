import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/category.dart';
import '../../../localization/app_localizations.dart';

/// Modal dialog for creating or editing a [Category].
///
/// Pass `category: null` to create, or an existing instance to edit. The
/// dialog owns the form state, validation, and the icon-picker grid.
/// Returns a [CategoryEditorOutcome] describing what the user did (or
/// [CategoryEditorOutcome.cancelled] if they closed it without saving).
class CategoryEditorDialog extends StatefulWidget {
  const CategoryEditorDialog({
    super.key,
    required this.existing,
    required this.all,
    required this.defaultDownloadDir,
    this.initialParentId,
  });

  /// `null` → create mode, otherwise edit mode for that category.
  final Category? existing;

  /// The full list of categories (needed for the parent dropdown and
  /// to avoid id collisions when minting a new id).
  final List<Category> all;

  /// Used to suggest a default save dir for new categories whose name
  /// is the only thing the user enters.
  final String defaultDownloadDir;

  /// Pre-selected parent when creating a sub-category via the
  /// sidebar's "New sub-category" action.
  final String? initialParentId;

  @override
  State<CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<CategoryEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _saveDir;
  late final TextEditingController _extensions;
  late final TextEditingController _sites;
  late String _iconName;
  String? _parentId;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _name = TextEditingController(text: c?.name ?? '');
    _saveDir = TextEditingController(text: c?.defaultSaveDir ?? '');
    _extensions = TextEditingController(text: c?.extensions.join(' ') ?? '');
    _sites = TextEditingController(text: c?.sites.join('\n') ?? '');
    _iconName = c?.iconName ?? 'folder';
    _parentId = c?.parentId ?? widget.initialParentId;
  }

  @override
  void dispose() {
    _name.dispose();
    _saveDir.dispose();
    _extensions.dispose();
    _sites.dispose();
    super.dispose();
  }

  /// All categories that may legally be a parent of the category being
  /// edited. In edit mode, this excludes the category itself and any
  /// of its descendants (to prevent cycles). In create mode every
  /// existing category is fair game plus a "root" pseudo-option.
  List<Category> get _parentCandidates {
    final out = <Category>[];
    for (final c in widget.all) {
      if (widget.existing != null && c.id == widget.existing!.id) continue;
      if (widget.existing != null &&
          _descendantIds(widget.existing!.id).contains(c.id)) {
        continue;
      }
      out.add(c);
    }
    return out;
  }

  Set<String> _descendantIds(String rootId) {
    final out = <String>{};
    final stack = <String>[rootId];
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      for (final c in widget.all) {
        if (c.parentId == id && out.add(c.id)) stack.add(c.id);
      }
    }
    return out;
  }

  String _mintId() {
    final base = _name.text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'(^-+)|(-+$)'), '');
    if (base.isEmpty) return 'category';
    final taken = widget.all.map((c) => c.id).toSet();
    if (!taken.contains(base)) return base;
    for (var i = 2; i < 1000; i++) {
      final candidate = '$base-$i';
      if (!taken.contains(candidate)) return candidate;
    }
    return '$base-${DateTime.now().millisecondsSinceEpoch}';
  }

  String _suggestedSaveDir() {
    if (_saveDir.text.trim().isNotEmpty) return _saveDir.text.trim();
    final base = _parentId == null
        ? widget.defaultDownloadDir
        : (widget.all
            .firstWhere(
              (c) => c.id == _parentId,
              orElse: () => Category(
                id: '',
                name: '',
                defaultSaveDir: widget.defaultDownloadDir,
                extensions: const [],
              ),
            )
            .defaultSaveDir);
    final name = _name.text.trim().isEmpty
        ? 'NewCategory'
        : _name.text.trim();
    return '$base\\${_sanitize(name)}';
  }

  String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  List<String> _parseExtensions(String raw) {
    final parts = raw.split(RegExp(r'[,\s]+'));
    final out = <String>[];
    for (final p in parts) {
      var t = p.trim().toLowerCase();
      if (t.isEmpty) continue;
      if (!t.startsWith('.')) t = '.$t';
      if (!out.contains(t)) out.add(t);
    }
    return out;
  }

  List<String> _parseSites(String raw) {
    final parts = raw.split('\n');
    final out = <String>[];
    for (final p in parts) {
      var t = p.trim().toLowerCase();
      if (t.isEmpty) continue;
      // Strip scheme/path/port and the www. prefix.
      final schemeEnd = t.indexOf('://');
      if (schemeEnd >= 0) t = t.substring(schemeEnd + 3);
      final slash = t.indexOf('/');
      if (slash >= 0) t = t.substring(0, slash);
      final colon = t.indexOf(':');
      if (colon >= 0) t = t.substring(0, colon);
      if (t.startsWith('www.')) t = t.substring(4);
      if (t.isEmpty) continue;
      if (!out.contains(t)) out.add(t);
    }
    return out;
  }

  Future<void> _browseSaveDir() async {
    try {
      final process = await Process.start(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          'Add-Type -AssemblyName System.Windows.Forms; '
              '\$f = New-Object System.Windows.Forms.FolderBrowserDialog; '
              'if (\$f.ShowDialog() -eq "OK") { Write-Host \$f.SelectedPath }',
        ],
      );
      final output = await process.stdout
          .transform(const SystemEncoding().decoder)
          .join();
      await process.exitCode;
      final path = output.trim();
      if (path.isNotEmpty) {
        setState(() => _saveDir.text = path);
      }
    } catch (_) {
      // PowerShell unavailable (e.g. Linux test runs); leave the field alone.
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final id = widget.existing?.id ?? _mintId();
    final dir = _saveDir.text.trim().isEmpty
        ? _suggestedSaveDir()
        : _saveDir.text.trim();
    final cat = Category(
      id: id,
      name: _name.text.trim(),
      parentId: _parentId,
      defaultSaveDir: dir,
      extensions: _parseExtensions(_extensions.text),
      sites: _parseSites(_sites.text),
      iconName: _iconName,
      isDefault: widget.existing?.isDefault ?? false,
    );
    Navigator.of(context).pop(
      CategoryEditorOutcome(
        action: _isEdit
            ? CategoryEditorAction.updated
            : CategoryEditorAction.created,
        category: cat,
      ),
    );
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final existing = widget.existing!;
    final blocked = existing.isDefault ||
        widget.all.any((c) => c.parentId == existing.id);
    if (blocked) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(existing.isDefault
            ? l.deleteBlockedDefault
            : l.deleteBlockedNonEmpty),
      ));
      return;
    }
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
    if (!mounted) return;
    Navigator.of(context).pop(
      CategoryEditorOutcome(
        action: CategoryEditorAction.deleted,
        category: existing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final canDelete = _isEdit &&
        !widget.existing!.isDefault &&
        !widget.all.any((c) => c.parentId == widget.existing!.id);

    return AlertDialog(
      title: Text(_isEdit ? l.editCategory : l.newCategory),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Field(
                  label: l.categoryName,
                  child: TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l.categoryName
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                _Field(
                  label: l.categoryIcon,
                  child: _IconPicker(
                    selected: _iconName,
                    onSelected: (k) => setState(() => _iconName = k),
                  ),
                ),
                const SizedBox(height: 12),
                if (!_isEdit) ...[
                  _Field(
                    label: l.categoryParent,
                    child: DropdownButtonFormField<String?>(
                      value: _parentId,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('—'),
                        ),
                        for (final c in _parentCandidates)
                          DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(c.name),
                          ),
                      ],
                      onChanged: (v) => setState(() => _parentId = v),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _Field(
                  label: l.categorySaveDir,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _saveDir,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: l.customDirectory,
                        onPressed: _browseSaveDir,
                        icon: const Icon(Icons.folder_open_outlined),
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Field(
                  label: l.categoryExtensions,
                  hint: l.categoryExtensionsHint,
                  child: TextFormField(
                    controller: _extensions,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _Field(
                  label: l.categorySites,
                  hint: l.categorySitesHint,
                  child: TextFormField(
                    controller: _sites,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (_isEdit)
          TextButton(
            onPressed: canDelete ? _delete : null,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l.deleteCategory),
          ),
        TextButton(
          onPressed: () => Navigator.of(context)
              .pop(const CategoryEditorOutcome.cancelled()),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(l.save),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, this.hint, required this.child});
  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        child,
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final entry in categoryIcons.entries)
          InkWell(
            onTap: () => onSelected(entry.key),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: entry.key == selected
                    ? Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.6)
                    : null,
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(entry.value, size: 18),
            ),
          ),
      ],
    );
  }
}

/// What the user did in [CategoryEditorDialog].
class CategoryEditorOutcome {
  const CategoryEditorOutcome({
    required this.action,
    this.category,
  });

  const CategoryEditorOutcome.cancelled()
      : action = CategoryEditorAction.cancelled,
        category = null;

  final CategoryEditorAction action;
  final Category? category;
}

enum CategoryEditorAction { created, updated, deleted, cancelled }
