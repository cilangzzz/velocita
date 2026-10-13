import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../data/category_icon_store.dart';
import '../domain/category.dart';
import '../../../localization/app_localizations.dart';
import '../../../theme/radii.dart';

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
  String? _iconName;
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
    _iconName = c?.iconName;
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
                    child: _ParentCategoryPicker(
                      all: widget.all,
                      excludeDescendantsOf: widget.existing?.id,
                      value: _parentId,
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

/// Material + custom-image icon picker.
///
/// Two tabs:
///   • **Material** — searchable grid of ~200 built-in `Icons.<name>`
///     candidates. Filter is case-insensitive substring on the key
///     (e.g. "mus" matches "music_note", "music_video", …).
///   • **Custom** — file picker for a local image, then a grid of
///     every image already in the icon store. Picked files are
///     copied into `<appSupport>/velocita/category_icons/` and
///     referenced via the `image:<id>` sentinel.
///
/// The selected key — either a Material key or an `image:<id>`
/// sentinel — is emitted to [onSelected] and visually highlighted
/// in both tabs.
class _IconPicker extends StatefulWidget {
  const _IconPicker({required this.selected, required this.onSelected});
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  State<_IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<_IconPicker> {
  int _tab = 0;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _filteredMaterial() {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return kMaterialIconNames;
    return [
      for (final name in kMaterialIconNames)
        if (name.toLowerCase().contains(q)) name,
    ];
  }

  /// Custom images already in the store. Read from the icon dir
  /// and re-loaded after every import.
  List<File> _customImages() {
    final dirPath = CategoryIconStore.iconDir;
    if (dirPath == null) return const [];
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return const [];
    final out = <File>[];
    for (final e in dir.listSync()) {
      if (e is File && _isSupportedExt(e.path)) out.add(e);
    }
    out.sort((a, b) => a.path.compareTo(b.path));
    return out;
  }

  bool _isSupportedExt(String path) {
    final ext = p.extension(path).toLowerCase();
    return kSupportedImageExtensions.contains(ext);
  }

  /// Pick an image via PowerShell `OpenFileDialog`, copy it into
  /// the icon store, and emit the new sentinel to the parent.
  Future<void> _pickCustom() async {
    final exts = kSupportedImageExtensions
        .map((e) => '*${e.toUpperCase()}')
        .join(';');
    final process = await Process.start(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        'Add-Type -AssemblyName System.Windows.Forms; '
            '\$f = New-Object System.Windows.Forms.OpenFileDialog; '
            "\$f.Filter = 'Image files ($exts)|$exts'; "
            'if (\$f.ShowDialog() -eq "OK") { Write-Host \$f.FileName }',
      ],
    );
    final output =
        await process.stdout.transform(const SystemEncoding().decoder).join();
    await process.exitCode;
    final picked = output.trim();
    if (picked.isEmpty) return;
    try {
      final iconName = await CategoryIconStore.importFrom(File(picked));
      if (!mounted) return;
      setState(() {}); // refresh custom grid
      widget.onSelected(iconName);
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not import icon: $e')),
      );
    }
  }

  void _deleteCustom(File file) async {
    await CategoryIconStore.delete('${kCustomImagePrefix}${p.basename(file.path)}');
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DefaultTabController(
      length: 2,
      initialIndex: _tab,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Tabs ────────────────────────────────────────────────
          TabBar(
            onTap: (i) => setState(() => _tab = i),
            tabs: const [
              Tab(icon: Icon(Icons.grid_view_outlined), text: 'Material'),
              Tab(icon: Icon(Icons.image_outlined), text: 'Custom'),
            ],
          ),
          const SizedBox(height: 8),
          if (_tab == 0) ...[
            // ── Material tab: search + grid ─────────────────────
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search icons…',
                prefixIcon: const Icon(Icons.search, size: 18),
                border: const OutlineInputBorder(),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: _MaterialGrid(
                names: _filteredMaterial(),
                selected: widget.selected,
                onSelected: widget.onSelected,
                emptyHint: _query.isEmpty
                    ? null
                    : 'No icons match "${_query.trim()}".',
              ),
            ),
          ] else ...[
            // ── Custom tab: file picker + grid ─────────────────
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _pickCustom,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Pick image…'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PNG / JPG / GIF / WebP / BMP',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: _CustomGrid(
                files: _customImages(),
                selected: widget.selected,
                onSelected: widget.onSelected,
                onDelete: _deleteCustom,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Grid of Material icon cells. Each cell is a 36×36 tappable
/// square. Empty filter result → centred hint message.
class _MaterialGrid extends StatelessWidget {
  const _MaterialGrid({
    required this.names,
    required this.selected,
    required this.onSelected,
    this.emptyHint,
  });

  final List<String> names;
  final String? selected;
  final ValueChanged<String> onSelected;
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) {
      return Center(
        child: Text(
          emptyHint ?? 'No icons.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return GridView.builder(
      scrollDirection: Axis.horizontal,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: names.length,
      itemBuilder: (context, i) {
        final name = names[i];
        return _IconCell(
          selected: name == selected,
          onTap: () => onSelected(name),
          child: Icon(categoryIcon(name), size: 18),
        );
      },
    );
  }
}

/// Grid of custom-image cells. Identical layout to [_MaterialGrid]
/// but renders Image.file cells with a small delete affordance on
/// hover-style long-press.
class _CustomGrid extends StatelessWidget {
  const _CustomGrid({
    required this.files,
    required this.selected,
    required this.onSelected,
    required this.onDelete,
  });

  final List<File> files;
  final String? selected;
  final ValueChanged<String> onSelected;
  final ValueChanged<File> onDelete;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return Center(
        child: Text(
          'No custom icons yet — click "Pick image…" to add one.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return GridView.builder(
      scrollDirection: Axis.horizontal,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: files.length,
      itemBuilder: (context, i) {
        final f = files[i];
        final iconName = '$kCustomImagePrefix${p.basename(f.path)}';
        return _IconCell(
          selected: iconName == selected,
          onTap: () => onSelected(iconName),
          onLongPress: () => _confirmDelete(context, f),
          child: Image.file(f, width: 18, height: 18, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image_outlined, size: 18)),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, File f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete custom icon?'),
        content: Text(p.basename(f.path)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) onDelete(f);
  }
}

/// Single 36×36 tappable cell shared by both grids.
class _IconCell extends StatelessWidget {
  const _IconCell({
    required this.selected,
    required this.onTap,
    required this.child,
    this.onLongPress,
  });

  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: Radii.brSm,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.6)
              : null,
          border: Border.all(
            color: selected ? scheme.primary : theme.dividerColor,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: Radii.brSm,
        ),
        alignment: Alignment.center,
        child: child,
      ),
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

// ── Parent-category picker (tree popup) ────────────────────────

/// Compact button that opens a tree-structured picker for choosing
/// a category's parent. Replaces the previous flat dropdown with
/// the same hierarchy the sidebar shows, so the user can place a
/// new category under any existing one — root or any nested node
/// — without having to mentally project the list into a tree.
///
/// [excludeDescendantsOf] greys out the supplied id and all of its
/// descendants so the picker can't be used to create a cycle
/// (only relevant in edit mode; the editor currently only shows
/// this widget in create mode but the param is here for parity
/// with the previous exclusion logic).
class _ParentCategoryPicker extends StatefulWidget {
  const _ParentCategoryPicker({
    required this.all,
    required this.value,
    required this.onChanged,
    this.excludeDescendantsOf,
  });

  final List<Category> all;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? excludeDescendantsOf;

  @override
  State<_ParentCategoryPicker> createState() => _ParentCategoryPickerState();
}

class _ParentCategoryPickerState extends State<_ParentCategoryPicker> {
  /// Display label for the picker button. `(root)` when no parent
  /// is selected, otherwise the chosen category's name.
  String _label() {
    final v = widget.value;
    if (v == null) return '(root)';
    for (final c in widget.all) {
      if (c.id == v) return c.name;
    }
    return '(missing)';
  }

  Future<void> _open() async {
    final picked = await showDialog<String?>(
      context: context,
      builder: (_) => _ParentCategoryTreeDialog(
        all: widget.all,
        initial: widget.value,
        excludeDescendantsOf: widget.excludeDescendantsOf,
      ),
    );
    // showDialog returns null both on "user picked root" and
    // "user cancelled" — the dialog uses a sentinel for the
    // former. See _ParentCategoryTreeDialog._rootSentinel.
    if (!mounted) return;
    if (picked == _ParentCategoryTreeDialog.cancelSentinel) return;
    widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                widget.value == null
                    ? Icons.account_tree_outlined
                    : Icons.subdirectory_arrow_right,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _label(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Icon(
                Icons.unfold_more,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal tree picker. Renders the category hierarchy with indented
/// rows + expand/collapse chevrons. A synthetic "— Root —" row sits
/// at the top for the "no parent" choice.
///
/// Uses a [Navigator.pop] sentinel for "cancelled" so the caller
/// can distinguish "user picked root" (pop with [rootSentinel]) from
/// "user closed the dialog" (pop with [cancelSentinel]).
class _ParentCategoryTreeDialog extends StatefulWidget {
  const _ParentCategoryTreeDialog({
    required this.all,
    required this.initial,
    this.excludeDescendantsOf,
  });

  final List<Category> all;
  final String? initial;
  final String? excludeDescendantsOf;

  /// Returned when the user picks the synthetic "root" option.
  static const String rootSentinel = '__root__';

  /// Returned when the user closes the dialog without picking.
  static const String cancelSentinel = '__cancel__';

  @override
  State<_ParentCategoryTreeDialog> createState() =>
      _ParentCategoryTreeDialogState();
}

class _ParentCategoryTreeDialogState
    extends State<_ParentCategoryTreeDialog> {
  /// Ids currently expanded in the tree. Initialised from
  /// [initial] (so the selected parent's ancestors auto-open) and
  /// grows as the user clicks chevrons. Not persisted.
  late final Set<String> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = _ancestorsOf(widget.initial).toSet();
  }

  List<String> _ancestorsOf(String? id) {
    if (id == null) return const [];
    final out = <String>[];
    var current = id;
    final seen = <String>{id};
    while (true) {
      Category? c;
      for (final x in widget.all) {
        if (x.id == current) {
          c = x;
          break;
        }
      }
      if (c == null || c.parentId == null) break;
      if (!seen.add(c.parentId!)) break;
      out.insert(0, c.parentId!);
      current = c.parentId!;
    }
    return out;
  }

  /// Top-level categories (no parent), in insertion order.
  List<Category> get _roots =>
      [for (final c in widget.all) if (c.parentId == null) c];

  List<Category> _childrenOf(String parentId) =>
      [for (final c in widget.all) if (c.parentId == parentId) c];

  /// Ids that should be rendered but non-selectable (the
  /// cycle-prevention rule for edit mode). Always empty in
  /// create mode.
  late final Set<String> _disabledIds = () {
    final root = widget.excludeDescendantsOf;
    if (root == null) return const <String>{};
    final out = <String>{root};
    final stack = <String>[root];
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      for (final c in widget.all) {
        if (c.parentId == id && out.add(c.id)) stack.add(c.id);
      }
    }
    return out;
  }();

  void _pick(String? id) {
    if (id != null && _disabledIds.contains(id)) return;
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                l.categoryParent,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  _TreeRow(
                    depth: 0,
                    icon: Icons.account_tree_outlined,
                    label: '— (root) —',
                    isLeaf: true,
                    expanded: false,
                    hasChildren: false,
                    selected: widget.initial == null,
                    disabled: false,
                    onTap: () => Navigator.of(context)
                        .pop(_ParentCategoryTreeDialog.rootSentinel),
                    onChevron: null,
                  ),
                  for (final r in _roots) ..._buildSubtree(r, 0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Recursive builder. Returns a flat list of [_TreeRow]s for the
  /// subtree rooted at [cat], honouring the [_expanded] state.
  List<Widget> _buildSubtree(Category cat, int depth) {
    final kids = _childrenOf(cat.id);
    final hasKids = kids.isNotEmpty;
    final expanded = _expanded.contains(cat.id);
    final disabled = _disabledIds.contains(cat.id);
    final selected = widget.initial == cat.id;
    return [
      _TreeRow(
        depth: depth,
        icon: categoryIcon(cat.iconName),
        label: cat.name,
        isLeaf: !hasKids,
        expanded: expanded,
        hasChildren: hasKids,
        selected: selected,
        disabled: disabled,
        onTap: disabled ? null : () => _pick(cat.id),
        onChevron: hasKids
            ? () => setState(() {
                  if (!_expanded.add(cat.id)) _expanded.remove(cat.id);
                })
            : null,
      ),
      if (hasKids && expanded)
        for (final k in kids) ..._buildSubtree(k, depth + 1),
    ];
  }
}

/// One row in the tree picker. Indent by [depth] * 16, leading
/// chevron + icon, then label. Disabled rows render with reduced
/// opacity and ignore taps.
class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.depth,
    required this.icon,
    required this.label,
    required this.isLeaf,
    required this.expanded,
    required this.hasChildren,
    required this.selected,
    required this.disabled,
    required this.onTap,
    required this.onChevron,
  });

  final int depth;
  final IconData icon;
  final String label;
  final bool isLeaf;
  final bool expanded;
  final bool hasChildren;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;
  final VoidCallback? onChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final indent = depth * 16.0;
    final fg = disabled
        ? scheme.onSurfaceVariant.withValues(alpha: 0.45)
        : (selected ? scheme.primary : scheme.onSurface);
    final bg = selected
        ? scheme.primaryContainer.withValues(alpha: 0.35)
        : null;
    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 4 + indent),
              SizedBox(
                width: 18,
                height: 18,
                child: hasChildren
                    ? InkWell(
                        onTap: onChevron,
                        child: Icon(
                          expanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_right,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                ),
              ),
              if (selected)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.check, size: 16, color: scheme.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
