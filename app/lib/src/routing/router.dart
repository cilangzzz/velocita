import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/downloads/downloads.dart' as downloads;
import '../features/plugins/plugins.dart' as plugins;
import '../features/scheduler/scheduler.dart' as scheduler;
import '../features/settings/settings.dart' as settings;

/// The single source of truth for navigation. Built once at startup.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => _ShellLayout(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const downloads.DownloadsScreen(),
          ),
          GoRoute(
            path: '/scheduler',
            builder: (context, state) => const scheduler.SchedulerPage(),
          ),
          GoRoute(
            path: '/plugins',
            builder: (context, state) => const plugins.PluginsPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const settings.SettingsPage(),
          ),
        ],
      ),
    ],
  );
});

class _ShellLayout extends StatelessWidget {
  const _ShellLayout({required this.child});
  final Widget child;

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
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.cloud_download_outlined),
            selectedIcon: Icon(Icons.cloud_download),
            label: 'Downloads',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: 'Scheduler',
          ),
          NavigationDestination(
            icon: Icon(Icons.extension_outlined),
            selectedIcon: Icon(Icons.extension),
            label: 'Plugins',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        onDestinationSelected: (i) {
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
        },
      ),
    );
  }
}
