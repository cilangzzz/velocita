import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common_widgets/status_bar.dart';
import 'features/browser_integration/browser_integration.dart';
import 'localization/app_localizations.dart';
import 'localization/locale_provider.dart';
import 'routing/router.dart';
import 'theme/radii.dart';
import 'theme/theme_provider.dart';

/// Top-level MaterialApp.router. The router is created once in
/// `routing/router.dart` so it can be unit-tested in isolation.
class VelocitaApp extends ConsumerWidget {
  const VelocitaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Velocita',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supported
          .map((l) => l == 'zh-CN' ? const Locale('zh', 'CN') : Locale(l))
          .toList(),
      localizationsDelegates: const [
        _AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return PendingAddRequestListener(
          navigatorKey: rootNavigatorKey,
          child: Scaffold(
            body: child,
            bottomNavigationBar: const StatusBar(),
          ),
        );
      },
    );
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3F51B5),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.compact,
      // ── Corner-radius scale (see theme/radii.dart) ──────────────
      // Without these overrides M3 widgets default to:
      //   * Dialog / AlertDialog — 28 dp (huge, reads like iOS)
      //   * Card                 — 12 dp
      //   * All buttons          — StadiumBorder (pill)
      //   * SegmentedButton      — StadiumBorder (pill)
      //   * InputDecoration      — 4 dp on the focused ring only
      // We clamp them all to the [Radii] scale so the desktop surface
      // stays consistent and rectangular.
      //
      // Per-widget `shape:` (or inline `BorderRadius.circular`) still
      // wins, so explicit overrides — e.g. the pill selector button
      // in downloads_screen.dart — are unaffected.
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: Radii.brMd),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: Radii.brLg),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: Radii.brLg),
      ),
      snackBarTheme: SnackBarThemeData(
        shape: RoundedRectangleBorder(borderRadius: Radii.brSm),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: Radii.brSm),
        enabledBorder: OutlineInputBorder(borderRadius: Radii.brSm),
        focusedBorder: OutlineInputBorder(borderRadius: Radii.brSm),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: Radii.brMd),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: Radii.brMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: Radii.brMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: Radii.brMd),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: Radii.brSm),
          ),
        ),
      ),
    );
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supported.contains(locale.languageCode) ||
      AppLocalizations.supported.contains('${locale.languageCode}-${locale.countryCode}');

  @override
  Future<AppLocalizations> load(Locale locale) =>
      AppLocalizations.load(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
