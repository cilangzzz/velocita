import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/app_localizations.dart';
import '../../localization/locale_provider.dart';
import '../../theme/radii.dart';
import '../../theme/theme_provider.dart';
import '../browser_integration/browser_integration.dart';
import 'data/download_settings_provider.dart';
import 'domain/download_settings.dart';

/// Settings page — M3 surface.
///
/// M3 turns the wireframe into real, working controls for the three
/// download settings we can actually drive from the kernel today:
///   - default save directory (`aria2` `dir` global option)
///   - max concurrent downloads (`max-concurrent-downloads`)
///   - overall download speed limit (`max-overall-download-limit`)
///
/// Proxy / NAT-UPnP land in a future milestone — aria2 needs extra
/// startup flags that the bootstrap doesn't pass yet.
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
        // General — theme + language.
        _SettingsCard(
          title: l.general,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
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
                  ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(sel.first);
                },
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.settingsLanguage),
              subtitle: Text(
                locale.languageCode == 'zh' ? l.langChinese : l.langEnglish,
              ),
              // The classic DropdownButton opens a Material menu that
              // defaults to a square shape and a generic grey/surface
              // fill that fights the card's `surfaceContainerLow`. Wrap
              // it to:
              //   * drop the underline so the trailing widget sits flat
              //     against the card (otherwise the box draws a thin
              //     accent line that looks like a missing affordance)
              //   * round the popup 12 dp
              //   * recolour the popup to the M3 elevated-menu family
              //     (surfaceContainerHigh) so it matches the surrounding
              //     container tones and the item highlight reads cleanly
              //   * restyle the item text to use the theme's bodyMedium +
              //     onSurface so it doesn't inherit the dropdown's
              //     per-widget `style` accent color.
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: locale.languageCode,
                  borderRadius: Radii.brLg,
                  dropdownColor:
                      Theme.of(context).colorScheme.surfaceContainerHigh,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
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
            ),
          ],
        ),
        // Startup — auto-launch behaviour at sign-in.
        _SettingsCard(
          title: l.startup,
          children: const [_AutoStartTile(), _StartHiddenToTrayTile()],
        ),
        // Downloads — where downloads go and the headline caps.
        _SettingsCard(
          title: l.downloads,
          children: const [
            _SaveDirTile(),
            _MaxConcurrentTile(),
            _SpeedLimitTile(),
          ],
        ),
        // Advanced — multi-connection tuning for power users.
        _SettingsCard(
          title: l.advanced,
          children: const [
            _SplitTile(),
            _MaxConnPerServerTile(),
          ],
        ),
        // Connection — outbound network (proxy, NAT).
        _SettingsCard(
          title: l.connection,
          children: const [
            _ProxyTile(),
            _NatUpnpTile(),
          ],
        ),
        // Browser integration — wrapped here so the section shares the
        // same card style as the others. The section's own widget
        // returns body content only (no header) — the card title
        // above is the section's identity.
        _SettingsCard(
          title: l.browserIntegration,
          children: const [BrowserIntegrationSection()],
        ),
      ],
    );
  }
}

/// A grouped settings panel: card with a coloured section title and
/// a list of `children` (typically `ListTile`s with
/// `contentPadding: EdgeInsets.zero` so the card's own padding
/// provides the inset). Divider is intentionally not auto-inserted
/// between items — cards are tight enough that extra rules add noise.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ...children,
          ],
        ),
      ),
    );
  }
}


// ── Startup tiles ──────────────────────────────────────────

/// "Start at sign-in" + "Start minimized to tray" toggles. The two
/// are siblings because silent-start has no effect on its own
/// (a manual launch from a shortcut ignores `--start-minimized` and
/// only the auto-launched copy honours it), but the user can preview
/// either one before committing to a full auto-start.
class _AutoStartTile extends ConsumerWidget {
  const _AutoStartTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(downloadSettingsProvider);
    return settings.when(
      data: (s) => _AutoStartForm(initialAuto: s.autoStart, initialSilent: s.silentStart),
      loading: () => const _SkeletonRow(),
      error: (e, _) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.settingAutoStart),
        subtitle: Text(e.toString()),
      ),
    );
  }
}

class _AutoStartForm extends ConsumerStatefulWidget {
  const _AutoStartForm({required this.initialAuto, required this.initialSilent});
  final bool initialAuto;
  final bool initialSilent;

  @override
  ConsumerState<_AutoStartForm> createState() => _AutoStartFormState();
}

class _AutoStartFormState extends ConsumerState<_AutoStartForm> {
  late bool _auto;
  late bool _silent;
  String? _error;

  @override
  void initState() {
    super.initState();
    _auto = widget.initialAuto;
    _silent = widget.initialSilent;
  }

  @override
  void didUpdateWidget(covariant _AutoStartForm old) {
    super.didUpdateWidget(old);
    // External resets (file rewritten by another process) sync into
    // the local UI only when nothing is in flight.
    if (old.initialAuto != widget.initialAuto) _auto = widget.initialAuto;
    if (old.initialSilent != widget.initialSilent) _silent = widget.initialSilent;
  }

  Future<void> _setAuto(bool v) async {
    setState(() {
      _auto = v;
      _error = null;
    });
    await _apply();
  }

  Future<void> _setSilent(bool v) async {
    setState(() {
      _silent = v;
      _error = null;
    });
    await _apply();
  }

  Future<void> _apply() async {
    try {
      await ref.read(downloadSettingsProvider.notifier).apply(
            autoStart: _auto,
            silentStart: _silent,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.settingAutoStart),
          subtitle: Text(
            l.settingAutoStartHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: _auto,
          onChanged: _setAuto,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.settingSilentStart),
          subtitle: Text(
            l.settingSilentStartHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: _silent && _auto,
          // The switch is "on" only when both auto and silent are on;
          // tapping it always flips silent, and the disabled state
          // (autoStart off) makes the relationship visible.
          onChanged: _auto ? _setSilent : null,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
      ],
    );
  }
}

// ── Download tiles ─────────────────────────────────────────

class _SaveDirTile extends ConsumerWidget {
  const _SaveDirTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(downloadSettingsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.settingSaveDir),
            subtitle: Text(
              l.settingSaveDirHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          settings.when(
            data: (s) => _SaveDirField(initial: s.saveDir),
            loading: () => const _SaveDirSkeleton(),
            error: (e, _) => _SaveDirError(message: e.toString()),
          ),
        ],
      ),
    );
  }
}

class _SaveDirField extends ConsumerStatefulWidget {
  const _SaveDirField({required this.initial});
  final String initial;

  @override
  ConsumerState<_SaveDirField> createState() => _SaveDirFieldState();
}

class _SaveDirFieldState extends ConsumerState<_SaveDirField> {
  late final TextEditingController _controller;
  String? _committed;
  String? _savingError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
    _committed = widget.initial;
  }

  @override
  void didUpdateWidget(covariant _SaveDirField old) {
    super.didUpdateWidget(old);
    // External resets (e.g. file corruption → defaults) should overwrite
    // the local edit buffer only when nothing has been typed since.
    if (_controller.text == old.initial && widget.initial != old.initial) {
      _controller.text = widget.initial;
      _committed = widget.initial;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _browse() async {
    // M3 uses the same PowerShell folder picker the AddTaskDialog
    // already does. This keeps the desktop-only dependency out of the
    // kernel layer.
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
      _controller.text = path;
      _save();
    }
  }

  Future<void> _save() async {
    final path = _controller.text.trim();
    if (path.isEmpty || path == _committed) return;
    setState(() => _savingError = null);
    try {
      await ref
          .read(downloadSettingsProvider.notifier)
          .apply(saveDir: path);
      setState(() => _committed = path);
    } catch (e) {
      setState(() => _savingError = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              errorText: _savingError,
            ),
            onSubmitted: (_) => _save(),
            onEditingComplete: _save,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 40,
          child: OutlinedButton.icon(
            onPressed: _browse,
            icon: const Icon(Icons.folder_open_outlined, size: 16),
            label: Text(l.settingSaveDirBrowse),
          ),
        ),
      ],
    );
  }
}

class _SaveDirSkeleton extends StatelessWidget {
  const _SaveDirSkeleton();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 40,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
}

class _SaveDirError extends StatelessWidget {
  const _SaveDirError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: Radii.brMd,
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}

class _MaxConcurrentTile extends ConsumerWidget {
  const _MaxConcurrentTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(downloadSettingsProvider);
    return settings.when(
      data: (s) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.settingMaxConcurrent),
          subtitle: Text(
            l.settingMaxConcurrentHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: _ConcurrentControl(value: s.maxConcurrentDownloads),
        );
      },
      loading: () => const _SkeletonRow(),
      error: (e, _) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.settingMaxConcurrent),
        subtitle: Text(e.toString()),
      ),
    );
  }
}

class _ConcurrentControl extends ConsumerStatefulWidget {
  const _ConcurrentControl({required this.value});
  final int value;

  @override
  ConsumerState<_ConcurrentControl> createState() => _ConcurrentControlState();
}

class _ConcurrentControlState extends ConsumerState<_ConcurrentControl> {
  late int _pending;

  @override
  void initState() {
    super.initState();
    _pending = widget.value;
  }

  @override
  void didUpdateWidget(covariant _ConcurrentControl old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) {
      _pending = widget.value;
    }
  }

  Future<void> _commit(int v) async {
    setState(() => _pending = v);
    try {
      await ref
          .read(downloadSettingsProvider.notifier)
          .apply(maxConcurrentDownloads: v);
    } catch (_) {
      // Errors surface through provider state on next refresh; the
      // local _pending stays so the user keeps their last typed value.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '-',
          icon: const Icon(Icons.remove),
          onPressed: _pending > DownloadSettings.minConcurrent
              ? () => _commit(_pending - 1)
              : null,
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$_pending',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: '+',
          icon: const Icon(Icons.add),
          onPressed: _pending < DownloadSettings.maxConcurrent
              ? () => _commit(_pending + 1)
              : null,
        ),
      ],
    );
  }
}

class _SpeedLimitTile extends ConsumerWidget {
  const _SpeedLimitTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(downloadSettingsProvider);
    return settings.when(
      data: (s) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.settingSpeedLimits),
        subtitle: Text(
          l.settingSpeedLimitHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: _SpeedLimitControl(initialKBps: s.maxOverallDownloadLimitKBps),
      ),
      loading: () => const _SkeletonRow(),
      error: (e, _) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.settingSpeedLimits),
        subtitle: Text(e.toString()),
      ),
    );
  }
}

class _SpeedLimitControl extends ConsumerStatefulWidget {
  const _SpeedLimitControl({required this.initialKBps});
  final int? initialKBps;

  @override
  ConsumerState<_SpeedLimitControl> createState() => _SpeedLimitControlState();
}

class _SpeedLimitControlState extends ConsumerState<_SpeedLimitControl> {
  late final TextEditingController _controller;
  String? _committed;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialKBps == null ? '' : widget.initialKBps.toString(),
    );
    _committed = _controller.text;
  }

  @override
  void didUpdateWidget(covariant _SpeedLimitControl old) {
    super.didUpdateWidget(old);
    if (_controller.text == (old.initialKBps?.toString() ?? '') &&
        widget.initialKBps != old.initialKBps) {
      final text = widget.initialKBps == null ? '' : widget.initialKBps.toString();
      _controller.text = text;
      _committed = text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _controller.text.trim();
    int? kbps;
    if (raw.isEmpty) {
      kbps = null;
    } else {
      final parsed = int.tryParse(raw);
      if (parsed == null || parsed < 0) {
        setState(() => _error = 'invalid');
        return;
      }
      kbps = parsed;
    }
    final bytes = (kbps ?? 0) * 1024;
    setState(() {
      _error = null;
      _committed = raw;
    });
    try {
      await ref
          .read(downloadSettingsProvider.notifier)
          .apply(maxOverallDownloadLimitBytesPerSec: bytes);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 110,
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              isDense: true,
              isCollapsed: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              border: const OutlineInputBorder(),
              errorText: _error,
              hintText: l.settingValueUnlimited,
              suffixText: 'KiB/s',
              suffixStyle: theme.textTheme.bodySmall,
            ),
            onSubmitted: (_) => _save(),
            onEditingComplete: _save,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _committed == null || _committed!.isEmpty
              ? l.settingSpeedLimitUnlimited
              : '$_committed KiB/s',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ── Connection tiles ───────────────────────────────────────

/// `split` — how many ranges aria2 cuts each file into.
///
/// Note: `changeGlobalOption` only applies to NEW downloads; already-
/// running tasks keep their original piece layout.
class _SplitTile extends ConsumerWidget {
  const _SplitTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(downloadSettingsProvider);
    return settings.when(
      data: (s) => _SplitForm(initial: s.split),
      loading: () => const _SkeletonRow(),
      error: (e, _) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.settingSplit),
        subtitle: Text(e.toString()),
      ),
    );
  }
}

class _SplitForm extends ConsumerStatefulWidget {
  const _SplitForm({required this.initial});
  final int initial;

  @override
  ConsumerState<_SplitForm> createState() => _SplitFormState();
}

class _SplitFormState extends ConsumerState<_SplitForm> {
  late int _pending;

  @override
  void initState() {
    super.initState();
    _pending = widget.initial;
  }

  @override
  void didUpdateWidget(covariant _SplitForm old) {
    super.didUpdateWidget(old);
    if (widget.initial != old.initial) _pending = widget.initial;
  }

  Future<void> _commit(int v) async {
    setState(() => _pending = v);
    try {
      await ref.read(downloadSettingsProvider.notifier).apply(split: v);
    } catch (_) {/* keep _pending; user can retry */}
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.settingSplit),
            subtitle: Text(
              l.settingSplitHint,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: '-',
                icon: const Icon(Icons.remove),
                onPressed: _pending > 1 ? () => _commit(_pending - 1) : null,
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '$_pending',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: '+',
                icon: const Icon(Icons.add),
                onPressed: _pending < 16 ? () => _commit(_pending + 1) : null,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4, bottom: 8),
            child: Text(
              l.settingSplitAppliesToNew,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `max-connection-per-server` — cap on concurrent connections to the
/// same server. Effective per-task connection count =
/// `min(split, maxConnectionPerServer)`, so this must be ≥ `split` for
/// the user to get the full split count.
class _MaxConnPerServerTile extends ConsumerWidget {
  const _MaxConnPerServerTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(downloadSettingsProvider);
    return settings.when(
      data: (s) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.settingMaxConnPerServer),
        subtitle: Text(
          l.settingMaxConnPerServerHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: _ConcurrentStepper(
          value: s.maxConnectionPerServer,
          min: 1,
          max: 16,
          onCommit: (v) => ref
              .read(downloadSettingsProvider.notifier)
              .apply(maxConnectionPerServer: v),
        ),
      ),
      loading: () => const _SkeletonRow(),
      error: (e, _) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.settingMaxConnPerServer),
        subtitle: Text(e.toString()),
      ),
    );
  }
}

/// Generic `− N +` stepper extracted from `_MaxConcurrentTile` /
/// `_SplitForm` so the three download-number tiles share one widget.
class _ConcurrentStepper extends StatefulWidget {
  const _ConcurrentStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onCommit,
  });
  final int value;
  final int min;
  final int max;
  final Future<void> Function(int) onCommit;

  @override
  State<_ConcurrentStepper> createState() => _ConcurrentStepperState();
}

class _ConcurrentStepperState extends State<_ConcurrentStepper> {
  late int _pending;

  @override
  void initState() {
    super.initState();
    _pending = widget.value;
  }

  @override
  void didUpdateWidget(covariant _ConcurrentStepper old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) _pending = widget.value;
  }

  Future<void> _commit(int v) async {
    setState(() => _pending = v);
    await widget.onCommit(v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '-',
          icon: const Icon(Icons.remove),
          onPressed: _pending > widget.min ? () => _commit(_pending - 1) : null,
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$_pending',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: '+',
          icon: const Icon(Icons.add),
          onPressed: _pending < widget.max ? () => _commit(_pending + 1) : null,
        ),
      ],
    );
  }
}

class _ProxyTile extends ConsumerWidget {
  const _ProxyTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(downloadSettingsProvider);
    return settings.when(
      data: (s) => _ProxyForm(initial: s),
      loading: () => const _SkeletonRow(),
      error: (e, _) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.settingProxy),
        subtitle: Text(e.toString()),
      ),
    );
  }
}

class _ProxyForm extends ConsumerStatefulWidget {
  const _ProxyForm({required this.initial});
  final DownloadSettings initial;

  @override
  ConsumerState<_ProxyForm> createState() => _ProxyFormState();
}

class _ProxyFormState extends ConsumerState<_ProxyForm> {
  late ProxyKind _kind;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _user;
  late final TextEditingController _pass;
  late final TextEditingController _bypass;
  String? _committedSummary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _kind = widget.initial.proxyKind;
    _host = TextEditingController(text: widget.initial.proxyHost);
    _port = TextEditingController(
      text: widget.initial.proxyPort == 0
          ? ''
          : widget.initial.proxyPort.toString(),
    );
    _user = TextEditingController(text: widget.initial.proxyUsername);
    _pass = TextEditingController(text: widget.initial.proxyPassword);
    _bypass = TextEditingController(text: widget.initial.proxyBypass);
    _committedSummary = _summary(widget.initial);
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _pass.dispose();
    _bypass.dispose();
    super.dispose();
  }

  String _summary(DownloadSettings s) {
    if (s.proxyKind == ProxyKind.off) return 'off';
    if (s.proxyHost.isEmpty || s.proxyPort <= 0) return 'off';
    final user = s.proxyUsername.isEmpty ? '' : '${s.proxyUsername}@';
    return '${s.proxyKind.name}://$user${s.proxyHost}:${s.proxyPort}';
  }

  bool get _formValid {
    if (_kind == ProxyKind.off) return true;
    if (_host.text.trim().isEmpty) return false;
    final p = int.tryParse(_port.text.trim());
    if (p == null || p <= 0 || p > 65535) return false;
    return true;
  }

  Future<void> _apply() async {
    final l = AppLocalizations.of(context);
    if (!_formValid) {
      setState(() => _error = l.settingProxyIncomplete);
      return;
    }
    setState(() => _error = null);
    final port = _kind == ProxyKind.off ? 0 : int.parse(_port.text.trim());
    try {
      await ref.read(downloadSettingsProvider.notifier).apply(
            proxyKind: _kind,
            proxyHost: _host.text.trim(),
            proxyPort: port,
            proxyUsername: _user.text.trim(),
            proxyPassword: _pass.text,
            proxyBypass: _bypass.text.trim(),
          );
      if (!mounted) return;
      final next = ref.read(downloadSettingsProvider).value!;
      setState(() => _committedSummary = _summary(next));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l.settingProxyApplied),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.settingProxy),
            subtitle: Text(
              _committedSummary ?? 'off',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: SegmentedButton<ProxyKind>(
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: ProxyKind.off, label: Text(l.settingProxyOff)),
                ButtonSegment(
                    value: ProxyKind.http, label: Text(l.settingProxyHttp)),
                ButtonSegment(
                    value: ProxyKind.socks5,
                    label: Text(l.settingProxySocks5),
                    icon: const Icon(Icons.help_outline, size: 14),
                  ),
              ],
              selected: {_kind},
              onSelectionChanged: (sel) {
                final next = sel.first;
                if (next == ProxyKind.socks5) {
                  // aria2c (1.37.0) rejects SOCKS5 in both its startup
                  // flag and `changeGlobalOption` — keep the current mode
                  // and explain instead of leaving a dead config.
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(l.settingProxySocks5Unsupported),
                    duration: const Duration(seconds: 3),
                  ));
                  return;
                }
                setState(() => _kind = next);
              },
            ),
          ),
          if (_kind != ProxyKind.off) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _host,
                    decoration: InputDecoration(
                      labelText: l.settingProxyHost,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _port,
                    keyboardType: const TextInputType.numberWithOptions(),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: l.settingProxyPort,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _user,
              decoration: InputDecoration(
                labelText: l.settingProxyUsername,
                hintText: l.settingProxyAuthOptional,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l.settingProxyPassword,
                hintText: l.settingProxyAuthOptional,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bypass,
              decoration: InputDecoration(
                labelText: l.settingProxyBypass,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (_error != null) ...[
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: _apply,
                icon: const Icon(Icons.check, size: 16),
                label: Text(l.download),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NatUpnpTile extends ConsumerWidget {
  const _NatUpnpTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l.settingNatUpnp),
      trailing: SegmentedButton<String>(
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: 'off', label: Text(l.settingNatOff)),
          ButtonSegment(value: 'upnp', label: Text(l.settingNatUpnpOn)),
        ],
        selected: const {'off'},
        onSelectionChanged: (_) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.comingSoon),
          ));
        },
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

/// "Start hidden in tray" — applies to manual launches. The
/// auto-launched copy is controlled by [settingSilentStart] (sibling
/// in [DownloadSettings]); this tile is the opt-out for "show me the
/// window when I double-click the exe". Default: ON.
class _StartHiddenToTrayTile extends ConsumerWidget {
  const _StartHiddenToTrayTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(downloadSettingsProvider);
    return settings.when(
      data: (s) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.settingStartHiddenToTray),
        subtitle: Text(
          l.settingStartHiddenToTrayHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        value: s.startHiddenToTray,
        onChanged: (v) async {
          try {
            await ref
                .read(downloadSettingsProvider.notifier)
                .apply(startHiddenToTray: v);
          } catch (_) {}
        },
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
