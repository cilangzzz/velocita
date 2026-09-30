import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/app_localizations.dart';

/// Plugins page — M4 surface (stub).
///
/// Real plugin loading from disk is M5 work. For now this is a placeholder
/// list of "discovered" plugins that the engine reports back.
class PluginsPage extends ConsumerWidget {
  const PluginsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.plugins,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.folder_open),
              label: Text(l.pluginInstall),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _PluginRow(
          name: 'YouTube Capturer',
          version: '1.0.0',
          enabled: false,
        ),
        const _PluginRow(
          name: 'Media Muxer',
          version: '0.4.1',
          enabled: true,
        ),
        const _PluginRow(
          name: 'SFTP Adapter',
          version: '2.0.0',
          enabled: false,
        ),
      ],
    );
  }
}

class _PluginRow extends ConsumerWidget {
  const _PluginRow({
    required this.name,
    required this.version,
    required this.enabled,
  });

  final String name;
  final String version;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      title: Text(name),
      subtitle: Text('v$version'),
      value: enabled,
      onChanged: (_) {},
      secondary: Icon(enabled ? Icons.toggle_on : Icons.toggle_off),
    );
  }
}
