import 'package:flutter/widgets.dart';

/// Corner-radius scale for the entire app.
///
/// Intentional bias: keep everything below 12 dp. The product surface is a
/// desktop download manager — large radii make widgets (pill selectors,
/// popup menus) look like mobile/IOS chrome rather than native desktop UI.
/// Most call sites should reach for [md] or [lg]; [xs] is reserved for
/// pip-sized cells (scheduler heatmap, legend dots).
///
/// Scale:
///   * [xs] — 2 dp, sub-element rounding (heatmap cells, swatches)
///   * [sm] — 4 dp, small chips (category-icon picker)
///   * [md] — 6 dp, inline containers and pill selectors
///   * [lg] — 8 dp, popup surfaces (dropdown menus, context menus)
class Radii {
  Radii._();

  static const double xs = 2;
  static const double sm = 4;
  static const double md = 6;
  static const double lg = 8;

  static const BorderRadius brXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
}
