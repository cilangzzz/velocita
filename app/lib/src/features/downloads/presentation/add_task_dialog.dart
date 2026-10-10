import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:velocita_kernel/velocita_kernel.dart';

import '../../../localization/app_localizations.dart';
import '../../../features/categories/categories.dart';
import '../../../theme/radii.dart';
import '../data/downloads_repository.dart';

/// Tabbed dialog for adding a new download: URL / Magnet / Torrent.
///
/// M5 surface. Each tab has its own input + validation:
///   - URL:   http(s) URL field, validates scheme
///   - Magnet: magnet URI field, validates prefix
///   - Torrent: file picker + bytes preview
///
/// The dialog auto-resolves the save directory from:
///   1. Caller-supplied [categoryId] (sidebar selection)
///   2. URL/file extension (auto-categorization)
///   3. None → caller uses its default
///
/// [initialUrl] (M6+): when non-null, pre-populates the URL field and
/// selects the URL tab. Used by the browser-extension integration to
/// hand a URL over to the user for confirmation.
class AddTaskDialog extends ConsumerStatefulWidget {
  const AddTaskDialog({
    super.key,
    this.categoryId,
    this.initialUrl,
    this.onResult,
    this.titleBar,
  });

  /// Optional id of the currently selected sidebar category.
  final String? categoryId;

  /// Optional pre-filled URL (M6 browser-integration surface).
  final String? initialUrl;

  /// Optional hook fired when the user confirms the dialog. Runs
  /// before the dialog pops, with the same `SubmitResult` that
  /// `Navigator.pop` will use as its return value.
  ///
  /// Used by the Add-Task sub-window: it has no `Navigator.pop`
  /// caller to receive the result (the dialog is the root of the
  /// sub-window's tree), so the sub-window supplies this callback
  /// to receive the result and IPC it back to the main app. The
  /// main-app `showDialog` path ignores this callback.
  final void Function(SubmitResult)? onResult;

  /// Optional custom widget to render in the dialog's title slot.
  /// When provided, the default text title is replaced and the
  /// dialog's `titlePadding` is collapsed to zero so the widget
  /// spans the full dialog width (used by the Add-Task sub-window
  /// to render its borderless title bar with min/max/close).
  final Widget? titleBar;

  @override
  ConsumerState<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends ConsumerState<AddTaskDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _urlController = TextEditingController();
  final _magnetController = TextEditingController();
  final _saveDirController = TextEditingController();
  final _urlFormKey = GlobalKey<FormState>();
  final _magnetFormKey = GlobalKey<FormState>();
  List<int>? _torrentBytes;
  String? _torrentName;

  /// Cached "save to" preview line so we can show it live.
  String _saveDirPreview = '';

  /// When non-null, overrides [saveDirPreview]. The user typed a custom
  /// path into the field — we use it verbatim instead of auto-resolving.
  String? _customSaveDir;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // M6 browser-integration surface: when the dialog is opened from
    // the queue (PendingAddRequestListener), the URL is prefilled and
    // the URL tab is selected so the user can confirm/adjust immediately.
    final prefilled = widget.initialUrl;
    if (prefilled != null && prefilled.isNotEmpty) {
      _urlController.text = prefilled;
      _tabController.index = 0;
    }
    _urlController.addListener(_recomputePreview);
    _magnetController.addListener(_recomputePreview);
    _saveDirController.addListener(_onCustomDirChanged);
    _tabController.addListener(_recomputePreview);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _magnetController.dispose();
    _saveDirController.dispose();
    super.dispose();
  }

  /// Auto-resolve saveDir from the user input. Resolution chain:
  ///   1. **Explicit category** (from the sidebar) → that category's dir
  ///   2. **URL host** matches a category's [Category.sites] → that dir
  ///   3. **Filename extension** matches a category's [Category.extensions]
  ///   4. **Fallback**: the `other` category's dir, else the bare downloads dir
  String _resolveAutoSaveDir() {
    final fallback = ref.read(downloadsRepositoryProvider).defaultSaveDir ??
        '';
    final cats = ref
            .watch(categoriesProvider)
            .valueOrNull
            ?.categories ??
        const <Category>[];
    final fallbackDir = fallback.isEmpty ? 'Downloads' : fallback;

    // 1. Explicit category (only when provided by the caller).
    final explicitId = widget.categoryId;
    if (explicitId != null && explicitId != '__none__') {
      final c = categoryById(cats, explicitId);
      if (c != null) {
        return resolvedSaveDir(
          all: cats,
          category: c,
          defaultDownloadDir: fallbackDir,
        );
      }
    }

    // 2. Site match (URL host only; magnets / torrents have no host).
    final urlText = _urlController.text.trim();
    if (urlText.isNotEmpty) {
      final host = Uri.tryParse(urlText)?.host ?? '';
      if (host.isNotEmpty) {
        final c = classifyBySite(cats, host);
        if (c != null) {
          return resolvedSaveDir(
            all: cats,
            category: c,
            defaultDownloadDir: fallbackDir,
          );
        }
      }
    }

    // 3. Extension match on whichever input the user is editing.
    final candidates = <String>[
      urlText,
      _magnetController.text,
      _torrentName ?? '',
    ];
    String? lastCandidate;
    for (final raw in candidates) {
      if (raw.isEmpty) continue;
      lastCandidate = raw;
      final last = raw.split('/').last.split('?').first;
      final ext = _extOf(last);
      if (ext.isEmpty) continue;
      for (final c in cats) {
        if (c.extensions.contains(ext)) {
          return resolvedSaveDir(
            all: cats,
            category: c,
            defaultDownloadDir: fallbackDir,
          );
        }
      }
    }

    // 4. Fallback → `other` category, then the bare downloads dir.
    final other = categoryById(cats, 'other');
    if (other != null && other.defaultSaveDir.isNotEmpty) {
      return other.defaultSaveDir;
    }
    if (lastCandidate == null || lastCandidate.trim().isEmpty) {
      return fallbackDir;
    }
    return fallbackDir;
  }

  String _extOf(String name) {
    var i = name.length - 1;
    while (i >= 0 && name[i] != '.') {
      if (name[i] == '/' || name[i] == '\\') return '';
      i--;
    }
    return i < 0 ? '' : name.substring(i).toLowerCase();
  }

  void _recomputePreview() {
    final preview = _resolveAutoSaveDir();
    // Always keep the text field in sync with the auto-resolved preview
    // when the user hasn't typed anything custom. Setting `text` triggers
    // `_onCustomDirChanged` which compares against `preview` and leaves
    // `_customSaveDir == null` — so the next URL change still updates
    // the field.
    if (_customSaveDir == null) {
      _saveDirController.text = preview;
    }
    if (preview != _saveDirPreview) {
      setState(() {
        _saveDirPreview = preview;
      });
    }
  }

  void _onCustomDirChanged() {
    final v = _saveDirController.text.trim();
    final preview = _resolveAutoSaveDir();
    setState(() {
      // Treat the text field as "not custom" iff its value matches what
      // auto-detection would produce. This prevents the very first
      // `_recomputePreview` (initState) from leaving a stale custom
      // value behind that would later block updates.
      _customSaveDir = (v.isEmpty || v == preview) ? null : v;
    });
  }

  Future<void> _browseSaveDir() async {
    // M5 placeholder: PowerShell-driven folder picker.
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
    final output =
        await process.stdout.transform(const SystemEncoding().decoder).join();
    await process.exitCode;
    final path = output.trim();
    if (path.isNotEmpty) {
      _saveDirController.text = path;
    }
  }

  void _submit() {
    final dir = _customSaveDir ?? _saveDirPreview;
    final void Function(SubmitResult)? onResult = widget.onResult;
    switch (_tabController.index) {
      case 0:
        if (!_urlFormKey.currentState!.validate()) return;
        final r = SubmitResult(
          kind: SubmitKind.url,
          url: _urlController.text.trim(),
          saveDir: dir,
        );
        if (onResult != null) onResult(r);
        Navigator.of(context).pop(r);
      case 1:
        if (!_magnetFormKey.currentState!.validate()) return;
        final r = SubmitResult(
          kind: SubmitKind.magnet,
          magnet: _magnetController.text.trim(),
          saveDir: dir,
        );
        if (onResult != null) onResult(r);
        Navigator.of(context).pop(r);
      case 2:
        if (_torrentBytes == null) return;
        final r = SubmitResult(
          kind: SubmitKind.torrent,
          torrentBytes: _torrentBytes!,
          torrentName: _torrentName ?? 'file.torrent',
          saveDir: dir,
        );
        if (onResult != null) onResult(r);
        Navigator.of(context).pop(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    _recomputePreview();
    final l = AppLocalizations.of(context);
    return AlertDialog(
      // Tighter corner radius than the M3 default (28px) — the
      // dialog is the primary surface for power users, so a more
      // rectangular look fits better with the rest of the app.
      shape: RoundedRectangleBorder(
        borderRadius: Radii.brLg,
      ),
      // Dialog-level margin: gives the content breathing room from the
      // dialog's own padding.
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 24,
      ),
      titlePadding: widget.titleBar != null
          ? EdgeInsets.zero
          : null,
      title: widget.titleBar ??
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l.addDownloadTask),
          ),
      content: Container(
        // Outer margin around the dialog body so the title, tabs,
        // and bottom action buttons don't feel cramped against the
        // dialog frame.
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: l.tabUrl),
                  Tab(text: l.tabMagnet),
                  Tab(text: l.tabTorrent),
                ],
              ),
              const SizedBox(height: 12),
              // Middle container: the per-tab input area. Wrap in a
              // Container with vertical margin so the input fields
              // don't sit right against the tab strip above and the
              // "save to" row below.
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 96,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUrlTab(),
                      _buildMagnetTab(),
                      _buildTorrentTab(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _SaveToField(
                controller: _saveDirController,
                preview: _saveDirPreview,
                isCustom: _customSaveDir != null,
                onBrowse: _browseSaveDir,
                saveToLabel: l.saveTo,
                customLabel: l.customDirectory,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l.download),
        ),
      ],
    );
  }

  Widget _buildUrlTab() {
    final l = AppLocalizations.of(context);
    return Form(
      key: _urlFormKey,
      child: Container(
        // URL field gets its own margin so the input sits with a bit
        // of breathing room from the dialog frame and any neighbours.
        margin: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 8,
        ),
        child: TextFormField(
          controller: _urlController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l.tabUrl,
            hintText: l.urlHint,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          validator: (value) {
            final s = (value ?? '').trim();
            if (s.isEmpty) return l.urlRequired;
            final uri = Uri.tryParse(s);
            if (uri == null ||
                !(uri.scheme == 'http' || uri.scheme == 'https')) {
              return l.urlInvalid;
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
    );
  }

  Widget _buildMagnetTab() {
    final l = AppLocalizations.of(context);
    return Form(
      key: _magnetFormKey,
      child: Container(
        // Magnet field needs the same surrounding margin as the URL
        // field so the two tab inputs feel symmetrical.
        margin: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 8,
        ),
        child: TextFormField(
          controller: _magnetController,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l.magnetLabel,
            hintText: l.magnetHint,
            border: const OutlineInputBorder(),
            // Magnet URIs are long; expanding the contentPadding
            // gives the multi-line text enough room to breathe
            // vertically and stops the top of the placeholder from
            // clipping.
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          validator: (value) {
            final s = (value ?? '').trim();
            if (!looksLikeMagnet(s)) return l.magnetInvalid;
            final parsed = parseMagnet(s);
            if (!parsed.hasBtih) {
              return l.magnetMissingBtih;
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
    );
  }

  Widget _buildTorrentTab() {
    final l = AppLocalizations.of(context);
    return Container(
      // Same surrounding margin as the URL / magnet inputs.
      margin: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: _pickTorrent,
            icon: const Icon(Icons.folder_open),
            label: Text(
              _torrentName == null ? l.chooseTorrent : _torrentName!,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_torrentBytes != null) ...[
            const SizedBox(height: 8),
            Text(
              '${(_torrentBytes!.length / 1024).toStringAsFixed(1)} KiB',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickTorrent() async {
    final process = await Process.start(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        'Add-Type -AssemblyName System.Windows.Forms; '
            '\$f = New-Object System.Windows.Forms.OpenFileDialog; '
            '\$f.Filter = "Torrent files (*.torrent)|*.torrent"; '
            'if (\$f.ShowDialog() -eq "OK") { Write-Host \$f.FileName }',
      ],
    );
    final output =
        await process.stdout.transform(const SystemEncoding().decoder).join();
    await process.exitCode;
    final path = output.trim();
    if (path.isEmpty) return;
    final bytes = await File(path).readAsBytes();
    setState(() {
      _torrentBytes = bytes;
      _torrentName = path.split(RegExp(r'[\\/]')).last;
    });
    _recomputePreview();
  }
}

/// Editable "save to" row. The text field is the authoritative storage
/// path: when the user hasn't typed anything, it auto-tracks the
/// category-resolved preview; as soon as the user types (or picks a
/// folder via the browse button), their value wins.
class _SaveToField extends StatelessWidget {
  const _SaveToField({
    required this.controller,
    required this.preview,
    required this.isCustom,
    required this.onBrowse,
    required this.saveToLabel,
    required this.customLabel,
  });

  final TextEditingController controller;
  final String preview;
  final bool isCustom;
  final VoidCallback onBrowse;
  final String saveToLabel;
  final String customLabel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.folder_outlined,
                size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              saveToLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l.saveToHint,
                  border: const OutlineInputBorder(),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: customLabel,
              onPressed: onBrowse,
              icon: const Icon(Icons.folder_open_outlined),
              iconSize: 18,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }
}

enum SubmitKind { url, magnet, torrent }

class SubmitResult {
  const SubmitResult({
    required this.kind,
    this.url,
    this.magnet,
    this.torrentBytes,
    this.torrentName,
    this.saveDir,
  });

  final SubmitKind kind;
  final String? url;
  final String? magnet;
  final List<int>? torrentBytes;
  final String? torrentName;

  /// Auto-resolved (or caller-supplied) save directory.
  final String? saveDir;
}

/// Top-level category specs used for both filter + add-task save-dir.
///
/// Previously duplicated the seed-category metadata; now the dialog
/// reads directly from [categoriesProvider], so this constant is gone.
