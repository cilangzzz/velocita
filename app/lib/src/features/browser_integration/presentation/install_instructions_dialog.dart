// ignore_for_file: avoid_relative_lib_imports
// Copy-paste instructions shown after the user clicks one of the
// "Install for {Chrome,Edge,Firefox}" buttons in Settings. The actual
// install work is already done by `host_installer.installFor`; this
// dialog just shows the user what to do next in the browser.
import 'package:flutter/material.dart';

import '../../../localization/app_localizations.dart';
import '../domain/browser_integration_settings.dart';

class InstallInstructionsDialog extends StatelessWidget {
  const InstallInstructionsDialog({super.key, required this.kind});

  final BrowserKind kind;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final browserName = switch (kind) {
      BrowserKind.chrome => 'Chrome',
      BrowserKind.edge => 'Edge',
      BrowserKind.firefox => 'Firefox',
    };
    final title = switch (kind) {
      BrowserKind.chrome => l.installForChrome,
      BrowserKind.edge => l.installForEdge,
      BrowserKind.firefox => l.installForFirefox,
    };
    final header = l.browserIntegrationInstalledHintText(browserName);
    final steps = switch (kind) {
      BrowserKind.chrome => <String>[
          l.installStepsChrome1,
          l.installStepsChrome2,
          l.installStepsChrome3,
          l.installStepsChrome4,
        ],
      BrowserKind.edge => <String>[
          l.installStepsEdge1,
          l.installStepsEdge2,
          l.installStepsEdge3,
          l.installStepsEdge4,
        ],
      BrowserKind.firefox => <String>[
          l.installStepsFirefox1,
          l.installStepsFirefox2,
          l.installStepsFirefox3,
          l.installStepsFirefox4,
        ],
    };
    return AlertDialog(
      title: Text('$title $browserName'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              header,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < steps.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    child: Text('${i + 1}',
                        style: Theme.of(context).textTheme.labelSmall),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(steps[i])),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.close),
        ),
      ],
    );
  }
}
