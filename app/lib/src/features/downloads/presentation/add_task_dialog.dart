import 'dart:io';

import 'package:flutter/material.dart';

import 'package:velocita_kernel/velocita_kernel.dart';

/// Tabbed dialog for adding a new download: URL / Magnet / Torrent.
///
/// M3 surface. Each tab has its own input + validation:
///   - URL:   http(s) URL field, validates scheme
///   - Magnet: magnet URI field, validates prefix
///   - Torrent: file picker + bytes preview
class AddTaskDialog extends StatefulWidget {
  const AddTaskDialog({super.key});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _urlController = TextEditingController();
  final _magnetController = TextEditingController();
  final _urlFormKey = GlobalKey<FormState>();
  final _magnetFormKey = GlobalKey<FormState>();
  List<int>? _torrentBytes;
  String? _torrentName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _magnetController.dispose();
    super.dispose();
  }

  void _submit() {
    switch (_tabController.index) {
      case 0:
        if (!_urlFormKey.currentState!.validate()) return;
        Navigator.of(context).pop(SubmitResult(
          kind: SubmitKind.url,
          url: _urlController.text.trim(),
        ));
      case 1:
        if (!_magnetFormKey.currentState!.validate()) return;
        Navigator.of(context).pop(SubmitResult(
          kind: SubmitKind.magnet,
          magnet: _magnetController.text.trim(),
        ));
      case 2:
        if (_torrentBytes == null) return;
        Navigator.of(context).pop(SubmitResult(
          kind: SubmitKind.torrent,
          torrentBytes: _torrentBytes!,
          torrentName: _torrentName ?? 'file.torrent',
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Download'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'URL'),
                Tab(text: 'Magnet'),
                Tab(text: 'Torrent'),
              ],
            ),
            const SizedBox(height: 16),
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Download'),
        ),
      ],
    );
  }

  Widget _buildUrlTab() {
    return Form(
      key: _urlFormKey,
      child: TextFormField(
        controller: _urlController,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'URL',
          hintText: 'https://example.com/file.zip',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.url,
        validator: (value) {
          final s = (value ?? '').trim();
          if (s.isEmpty) return 'URL is required';
          final uri = Uri.tryParse(s);
          if (uri == null ||
              !(uri.scheme == 'http' || uri.scheme == 'https')) {
            return 'Must be an http(s) URL';
          }
          return null;
        },
        onFieldSubmitted: (_) => _submit(),
      ),
    );
  }

  Widget _buildMagnetTab() {
    return Form(
      key: _magnetFormKey,
      child: TextFormField(
        controller: _magnetController,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Magnet URI',
          hintText: 'magnet:?xt=urn:btih:...',
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          final s = (value ?? '').trim();
          if (!looksLikeMagnet(s)) return 'Must start with magnet:?';
          final parsed = parseMagnet(s);
          if (!parsed.hasBtih) {
            return 'Missing urn:btih: exact-topic';
          }
          return null;
        },
        onFieldSubmitted: (_) => _submit(),
      ),
    );
  }

  Widget _buildTorrentTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _pickTorrent,
          icon: const Icon(Icons.folder_open),
          label: Text(
            _torrentName == null ? 'Choose .torrent file' : _torrentName!,
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
    // M3 placeholder: PowerShell-driven OpenFileDialog.
    // M4 will swap to file_selector for a portable dialog.
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
  });

  final SubmitKind kind;
  final String? url;
  final String? magnet;
  final List<int>? torrentBytes;
  final String? torrentName;
}
