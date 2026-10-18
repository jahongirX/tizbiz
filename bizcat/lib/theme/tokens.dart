import 'package:flutter/painting.dart';

/// Bizcat colors (bizcat-brand/BRAND.md) plus derived functional colors.
///
/// Apricot is reserved for the main CTA ([CtaButton]) and map pins. Never use it for text.
abstract final class BzColors {
  // brand (bizcat-brand/BRAND.md)
  /// Primary: app bar text, body text, primary buttons.
  static const indigo = Color(0xFF1E1B4B);

  /// Pressed/hover of indigo.
  static const indigo700 = Color(0xFF312E81);

  /// CTA background + map pins ONLY.
  static const apricot = Color(0xFFFF8A5B);

  /// Pressed CTA.
  static const apricot600 = Color(0xFFF26A35);

  /// Page background.
  static const cream = Color(0xFFFAF6F0);

  /// Cards, sheets, nav bar.
  static const white = Color(0xFFFFFFFF);

  /// Secondary text.
  static const muted = Color(0xFF5B5785);

  /// Card/input borders, dividers.
  static const border = Color(0xFFECE5DA);

  // app surfaces (cool, indigo-tinted: white cards read clearly on them)
  /// Page background.
  static const bg = Color(0xFFF3F2F8);

  /// Top of the page gradient (fades into [bg]).
  static const bgTop = Color(0xFFE6E3F8);

  /// Icon tiles inside white cards, secondary pill buttons.
  static const tile = Color(0xFFF1F0F6);

  // derived (not brand colors; functional)
  /// Selected chip bg tint, nav indicator, info chip bg.
  static const indigo50 = Color(0xFFECEBFA);
  static const success = Color(0xFF15803D);
  static const successBg = Color(0xFFE7F6EC);
  static const warning = Color(0xFFB45309);
  static const warningBg = Color(0xFFFDF1E1);
  static const danger = Color(0xFFB91C1C);
  static const dangerBg = Color(0xFFFDECEC);
  static const neutral = Color(0xFF6B6880);
  static const neutralBg = Color(0xFFF1EEE8);

  // dark scheme (derived from indigo; brand defines none)
  static const darkBg = Color(0xFF121027);
  static const darkSurface = Color(0xFF1B1838);
  static const darkBorder = Color(0xFF2E2A55);
  static const darkText = Color(0xFFF4F2FF);
  static const darkMuted = Color(0xFFA9A5CF);

  /// Primary buttons/selection in dark; text on it = indigo.
  static const darkPrimary = Color(0xFFC7C5F7);

  /// Top of the dark page gradient.
  static const darkBgTop = Color(0xFF221E4A);

  /// Icon tiles in dark cards.
  static const darkTile = Color(0xFF262250);
}

/// Spacing scale.
abstract final class BzSpace {
  static const xs = 4.0, s = 8.0, m = 12.0, l = 16.0, xl = 20.0, xxl = 24.0, xxxl = 32.0;

  /// Horizontal page padding.
  static const gutter = 16.0;
}

/// Corner radii.
abstract final class BzRadius {
  static const s = 8.0, m = 12.0, l = 16.0, xl = 20.0, pill = 999.0;

  /// Grouped white cards (lists, sections).
  static const card = 24.0;

  /// Icon tiles inside rows.
  static const tile = 14.0;
}
