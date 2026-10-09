import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/downloads/downloads.dart' as downloads;
import '../features/plugins/plugins.dart' as plugins;
import '../features/scheduler/scheduler.dart' as scheduler;
import '../features/settings/settings.dart' as settings;
import '../localization/app_localizations.dart';

/// Global navigator key — used by the browser-integration listener to
/// open the [AddTaskDialog] from outside any specific route.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// The single source of truth for navigation. Built once at startup.
///
/// Layout: `[NavigationRail | Body]` — both children scroll independently.
///
/// Each tab is mounted exactly once via [IndexedStack]. Route builders
/// return [SizedBox.shrink] because the real pages live inside the
/// IndexedStack; this keeps scroll positions, TextEditingController
/// buffers, and provider subscriptions alive across switches and makes
/// tab swaps instant instead of paying a full page teardown + remount.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    navigatorKey: rootNavigatorKey,
    routes: [
      ShellRoute(
        builder: (context, state, _) => const _ShellLayout(),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/scheduler',
            builder: (_, __) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/plugins',
            builder: (_, __) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    ],
  );
});

class _ShellLayout extends StatelessWidget {
  const _ShellLayout();

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = switch (location) {
      '/' => 0,
      '/scheduler' => 1,
      '/plugins' => 2,
      '/settings' => 3,
      _ => 0,
    };

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _Rail(selectedIndex: index, onSelect: (i) {
              switch (i) {
                case 0:
                  context.go('/');
                case 1:
                  context.go('/scheduler');
                case 2:
                  context.go('/plugins');
                case 3:
                  context.go('/settings');
              }
            }, labels: const [
              ('downloadsTab', Icons.cloud_download_outlined, Icons.cloud_download),
              ('scheduler', Icons.schedule_outlined, Icons.schedule),
              ('plugins', Icons.extension_outlined, Icons.extension),
              ('settings', Icons.settings_outlined, Icons.settings),
            ]),
            const VerticalDivider(width: 1),
            // IndexedStack keeps all four pages mounted; switching tabs
            // just changes `index` so the offstage branches aren't torn
            // down. StackFit.expand makes the body fill the row's width,
            // which DownloadsScreen's inner `Expanded` relies on.
            Expanded(
              child: IndexedStack(
                index: index,
                sizing: StackFit.expand,
                children: const [
                  downloads.DownloadsScreen(),
                  scheduler.SchedulerPage(),
                  plugins.PluginsPage(),
                  settings.SettingsPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact icon-only navigation rail on the left.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.selectedIndex,
    required this.onSelect,
    required this.labels,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// Each entry: (i18n key, outlined icon, filled icon).
  final List<(String, IconData, IconData)> labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 64,
      child: NavigationRail(
        extended: false,
        backgroundColor: scheme.surfaceContainerHighest,
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelect,
        labelType: NavigationRailLabelType.none,
        destinations: [
          for (var i = 0; i < labels.length; i++)
            NavigationRailDestination(
              icon: Icon(labels[i].$2),
              selectedIcon: Icon(labels[i].$3, color: scheme.primary),
              label: Text(_labelFor(context, labels[i].$1)),
            ),
        ],
      ),
    );
  }

  String _labelFor(BuildContext context, String key) {
    final l = AppLocalizations.of(context);
    switch (key) {
      case 'downloadsTab':
        return l.downloadsTab;
      case 'scheduler':
        return l.scheduler;
      case 'plugins':
        return l.plugins;
      case 'settings':
        return l.settings;
      default:
        return key;
    }
  }
}
