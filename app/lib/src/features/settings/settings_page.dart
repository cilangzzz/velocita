import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/app_localizations.dart';
import '../../localization/locale_provider.dart';

/// Settings page — M4 surface.
///
/// Per `docs/rule/flutter_rule/01-architecture.md`, settings is its own
/// feature module with its own barrel. M3 collapses the wireframe into
/// placeholders; each panel grows in its own milestone.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(title: l.general),
        ListTile(
          title: Text(l.themeDark),
          subtitle: Text(l.themeLight),
          trailing: const Icon(Icons.color_lens_outlined),
        ),
        ListTile(
          title: Text('Language'),
          subtitle: Text(locale.languageCode == 'zh' ? '中文' : 'English'),
          trailing: DropdownButton<String>(
            value: locale.languageCode,
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'zh', child: Text('中文')),
            ],
            onChanged: (v) {
              if (v == null) return;
              ref.read(localeProvider.notifier).setLocale(
                    v == 'zh' ? const Locale('zh', 'CN') : Locale(v),
                  );
            },
          ),
        ),
        const Divider(),
        _Section(title: l.downloads),
        const _Placeholder(label: 'Default save directory'),
        const _Placeholder(label: 'Max concurrent downloads'),
        const _Placeholder(label: 'Speed limits'),
        const Divider(),
        _Section(title: l.connection),
        const _Placeholder(label: 'Proxy'),
        const _Placeholder(label: 'NAT/UPnP'),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}
