import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:velocita_kernel/velocita_kernel.dart';

import '../../../localization/app_localizations.dart';
import '../data/downloads_repository.dart';
import '../domain/download_task.dart';

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
class AddTaskDialog extends ConsumerStatefulWidget {
  const AddTaskDialog({super.key, this.categoryId});

  /// Optional id of the currently selected sidebar category.
  final String? categoryId;

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

  /// Auto-resolve saveDir from the URL or filename's extension.
  ///
  /// Resolution order:
  ///   1. URL/file extension matches a real category → that category's dir
  ///   2. No extension match → fall back to `Other/` (catch-all)
  ///   3. Caller-side fallback if [downloadsRepositoryProvider] is unset
  String _resolveAutoSaveDir() {
    final fallback = ref.read(downloadsRepositoryProvider).defaultSaveDir;
    final candidates = <String>[
      _urlController.text,
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
      for (final c in _defaultCategorySpecs) {
        if (c.extensions.isEmpty) continue; // skip "Other" catch-all
        if (c.extensions.contains(ext)) {
          return fallback == null
              ? 'Downloads\\${c.dirName}'
              : '$fallback\\${c.dirName}';
        }
      }
    }
    // No extension match → land in `Other/`. If the user has not typed
    // anything yet, fall back to the bare downloads dir.
    if (lastCandidate == null || lastCandidate.trim().isEmpty) {
      return fallback ?? 'Downloads';
    }
    return fallback == null ? 'Downloads\\Other' : '$fallback\\Other';
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
    switch (_tabController.index) {
      case 0:
        if (!_urlFormKey.currentState!.validate()) return;
        Navigator.of(context).pop(SubmitResult(
          kind: SubmitKind.url,
          url: _urlController.text.trim(),
          saveDir: dir,
        ));
      case 1:
        if (!_magnetFormKey.currentState!.validate()) return;
        Navigator.of(context).pop(SubmitResult(
          kind: SubmitKind.magnet,
          magnet: _magnetController.text.trim(),
          saveDir: dir,
        ));
      case 2:
        if (_torrentBytes == null) return;
        Navigator.of(context).pop(SubmitResult(
          kind: SubmitKind.torrent,
          torrentBytes: _torrentBytes!,
          torrentName: _torrentName ?? 'file.torrent',
          saveDir: dir,
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    _recomputePreview();
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.addDownloadTask),
      content: SizedBox(
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
            SizedBox(
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
    );
  }

  Widget _buildMagnetTab() {
    final l = AppLocalizations.of(context);
    return Form(
      key: _magnetFormKey,
      child: TextFormField(
        controller: _magnetController,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: l.magnetLabel,
          hintText: l.magnetHint,
          border: const OutlineInputBorder(),
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
    );
  }

  Widget _buildTorrentTab() {
    final l = AppLocalizations.of(context);
    return Column(
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
const List<_CategorySpec> _defaultCategorySpecs = [
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
  // Catch-all: anything whose extension doesn't match the 6 above lands
  // here. Has no extension list so it can never "win" the auto-detect;
  // instead we use it as the fallback bucket.
  _CategorySpec(id: 'other', dirName: 'Other', extensions: const []),
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
