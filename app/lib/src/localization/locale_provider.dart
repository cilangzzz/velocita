import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Locale state — exposed via Riverpod so the router can rebuild on change.
final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale>((ref) => LocaleNotifier());

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en'));

  void setLocale(Locale locale) => state = locale;
  void toggleZh() {
    state = state.languageCode == 'zh'
        ? const Locale('en')
        : const Locale('zh', 'CN');
  }
}
