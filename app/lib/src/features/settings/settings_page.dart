import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/app_localizations.dart';
import '../../localization/locale_provider.dart';
import '../../theme/theme_provider.dart';

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
    final themeMode = ref.watch(themeModeProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(title: l.general),
        ListTile(
          title: Text(l.settingsTheme),
          trailing: SegmentedButton<ThemeMode>(
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l.themeLight),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(l.themeDark),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l.themeSystem),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (sel) {
              ref.read(themeModeProvider.notifier).setThemeMode(sel.first);
            },
          ),
        ),
        ListTile(
          title: Text(l.settingsLanguage),
          subtitle: Text(
            locale.languageCode == 'zh' ? l.langChinese : l.langEnglish,
          ),
          trailing: DropdownButton<String>(
            value: locale.languageCode,
            items: [
              DropdownMenuItem(value: 'en', child: Text(l.langEnglish)),
              DropdownMenuItem(value: 'zh', child: Text(l.langChinese)),
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
        _Placeholder(label: l.settingSaveDir),
        _Placeholder(label: l.settingMaxConcurrent),
        _Placeholder(label: l.settingSpeedLimits),
        const Divider(),
        _Section(title: l.connection),
        _Placeholder(label: l.settingProxy),
        _Placeholder(label: l.settingNatUpnp),
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
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListTile(
      enabled: false,
      title: Text(label),
      trailing: Text(
        l.comingSoon,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
