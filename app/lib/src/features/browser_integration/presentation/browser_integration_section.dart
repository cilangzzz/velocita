// ignore_for_file: avoid_relative_lib_imports
// Settings-page section: Browser integration.
//
// Renders the master on/off toggle, the per-download confirmation
// toggle, the running-status line, and the per-browser install /
// uninstall buttons. Reuses the visual style of the existing
// settings sections (a label-cased `_Section` header + body content)
// but does NOT share the private `_Section` widget from
// `settings_page.dart` — that one is private and we want a
// self-contained file.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../localization/app_localizations.dart';
import '../data/browser_integration_controller.dart';
import '../data/browser_integration_settings_provider.dart';
import '../data/browser_launcher.dart';
import '../data/host_installer.dart';
import '../domain/browser_integration_settings.dart';
import 'install_instructions_dialog.dart';

class BrowserIntegrationSection extends ConsumerWidget {
  const BrowserIntegrationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(browserIntegrationSettingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(title: l.browserIntegration),
        settings.when(
          data: (s) => _BrowserIntegrationContent(settings: s),
          loading: () => const _SkeletonRow(),
          error: (e, _) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.browserIntegration),
            subtitle: Text(e.toString()),
          ),
        ),
      ],
    );
  }
}

class _BrowserIntegrationContent extends ConsumerWidget {
  const _BrowserIntegrationContent({required this.settings});
  final BrowserIntegrationSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final running = ref.watch(browserIntegrationControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Master on/off switch. Drives the entire feature: when off,
        // the local IPC server is stopped and the extension cannot
        // hand off requests to this instance.
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.browserIntegrationEnabled),
          subtitle: Text(
            l.browserIntegrationEnabledHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: settings.enabled,
          onChanged: (v) => ref
              .read(browserIntegrationControllerProvider.notifier)
              .setEnabled(v),
        ),
        // Per-download confirmation. Only meaningful when the feature
        // is enabled.
        Opacity(
          opacity: settings.enabled ? 1.0 : 0.5,
          child: IgnorePointer(
            ignoring: !settings.enabled,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.browserIntegrationConfirm),
              subtitle: Text(
                l.browserIntegrationConfirmHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              value: settings.showConfirmationPopup,
              onChanged: (v) => ref
                  .read(browserIntegrationSettingsProvider.notifier)
                  .apply(showConfirmationPopup: v),
            ),
          ),
        ),
        _ListeningLine(port: settings.port, running: running, enabled: settings.enabled),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in BrowserKind.values)
              _InstallButton(
                kind: kind,
                installed: settings.installedBrowsers.contains(kind),
                enabled: settings.enabled,
              ),
            OutlinedButton.icon(
              onPressed: settings.enabled
                  ? () => _uninstallAll(context, ref)
                  : null,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: Text(l.uninstallIntegration),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Manual-install escape hatch: writes a `.reg` file the user
        // can double-click to import everything in one go. Useful
        // when the live `reg add` path is being blocked (AV / shell
        // quoting / corporate group policy) and as a belt-and-
        // suspenders when the user just wants to see exactly what
        // registry keys are about to be written.
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: settings.enabled ? () => _generateRegFile(context) : null,
            icon: const Icon(Icons.description_outlined, size: 16),
            label: Text(l.browserIntegrationGenerateRegFile),
          ),
        ),
      ],
    );
  }
}

class _ListeningLine extends StatelessWidget {
  const _ListeningLine({
    required this.port,
    required this.running,
    required this.enabled,
  });
  final int port;
  final bool running;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final color = (enabled && running) ? scheme.primary : scheme.outline;
    final label = !enabled
        ? l.browserIntegrationDisabled
        : running
            ? l.browserIntegrationListening
            : l.browserIntegrationStarting;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.circle, size: 12, color: color),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      subtitle: Text(
        'http://127.0.0.1:$port',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _InstallButton extends ConsumerWidget {
  const _InstallButton({
    required this.kind,
    required this.installed,
    required this.enabled,
  });
  final BrowserKind kind;
  final bool installed;
  final bool enabled;

  String get _browserName => switch (kind) {
        BrowserKind.chrome => 'Chrome',
        BrowserKind.edge => 'Edge',
        BrowserKind.firefox => 'Firefox',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return FilledButton.tonalIcon(
      onPressed: enabled ? () => _installFlow(context, ref, kind) : null,
      icon: Icon(
        installed ? Icons.check : Icons.download_outlined,
        size: 16,
      ),
      label: Text('${l.installFor(kind)} $_browserName'),
    );
  }
}

extension on AppLocalizations {
  String installFor(BrowserKind kind) => switch (kind) {
        BrowserKind.chrome => installForChrome,
        BrowserKind.edge => installForEdge,
        BrowserKind.firefox => installForFirefox,
      };
}

Future<void> _installFlow(
  BuildContext context,
  WidgetRef ref,
  BrowserKind kind,
) async {
  final l = AppLocalizations.of(context);
  try {
    await installFor(kind);
    await ref
        .read(browserIntegrationSettingsProvider.notifier)
        .markInstalled(kind);
    if (!context.mounted) return;
    // Open the browser's own extensions page so the user is one
    // click away from "Load unpacked". We launch the specific
    // browser binary (msedge.exe / chrome.exe / firefox.exe) instead
    // of handing the URL to the default browser — the URL uses a
    // browser-specific scheme that only the matching browser handles.
    final launched = await openInBrowser(kind, extensionsPageUrl(kind));
    if (!context.mounted) return;
    if (launched == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Could not find the browser. Open ${extensionsPageUrl(kind)} manually.',
        ),
        duration: const Duration(seconds: 4),
      ));
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => InstallInstructionsDialog(kind: kind),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l.browserIntegrationInstallFailed}: $e')),
    );
  }
}

Future<void> _uninstallAll(BuildContext context, WidgetRef ref) async {
  await uninstallAll();
  for (final k in BrowserKind.values) {
    await ref
        .read(browserIntegrationSettingsProvider.notifier)
        .markUninstalled(k);
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Browser integration uninstalled')),
  );
}

/// Write a `.reg` file the user can double-click in Explorer to
/// import every registry entry the feature needs. After writing,
/// reveal the file in the OS file manager so the user just has to
/// double-click it.
Future<void> _generateRegFile(BuildContext context) async {
  final l = AppLocalizations.of(context);
  try {
    final f = await writeRegFile();
    if (!context.mounted) return;
    final path = f.path;
    final folder = f.parent.path;

    if (Platform.isWindows) {
      // The most reliable way to "reveal in Explorer" on Windows is
      // `cmd /c start "" "<path>"`. The empty `""` is the title
      // `start` requires; the second quoted arg is the path. The
      // shell handles the quoting for us, so paths with spaces
      // (e.g. `C:\Users\John Smith\…`) work without any extra work
      // on our side.
      //
      // NOTE: do NOT try `explorer.exe /select,<path>` — the
      // `/select,` flag must be glued to the path as a single argv
      // entry, and Dart's Windows quoting escapes the inner quotes
      // in a way that makes Explorer fall through to a default
      // location. Tested and confirmed.
      var opened = false;
      try {
        await Process.start(
          'cmd',
          ['/c', 'start', '""', folder],
          runInShell: true,
        );
        opened = true;
      } catch (e) {
        // fall through to the direct-explorer fallback
      }
      if (!opened) {
        try {
          await Process.start('explorer.exe', [folder]);
        } catch (e) {
          // ignore — SnackBar below shows the path so the user can
          // navigate manually.
        }
      }
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${l.browserIntegrationRegFileWritten}\n$path'),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: l.copy,
        onPressed: () {
          // Hand the path to the user's clipboard so they can paste
          // it into Run / Explorer / etc.
          Clipboard.setData(ClipboardData(text: path));
        },
      ),
    ));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to write .reg file: $e')),
    );
  }
}

// ── small duplicated style primitives (private to settings_page.dart) ──

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

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();
  @override
  Widget build(BuildContext context) => const ListTile(
        contentPadding: EdgeInsets.zero,
        title: SizedBox(
          height: 16,
          child: LinearProgressIndicator(),
        ),
      );
}
