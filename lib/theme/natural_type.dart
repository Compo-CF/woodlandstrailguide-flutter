import 'package:flutter/material.dart';

import 'natural_palette.dart';

/// The typographic half of the design system — [NaturalPalette] owns color,
/// this owns type and the metrics that go with it. Mirrors iOS's
/// `NaturalType.swift`.
///
/// The app previously used the system font everywhere. Roboto is good and
/// deliberately invisible, which is the problem: it signals nothing, so a
/// carefully chosen palette still reads as stock. Pairing a display face
/// with the system font for body text is the cheapest change that makes an
/// app look authored.
///
/// Display face is **Fraunces** (SIL Open Font License 1.1 — free to embed
/// and ship). It's a warm old-style serif with a slightly rustic cut, which
/// lands close to park wayfinding and field-guide plates rather than generic
/// app chrome. Body text stays on the system font, which is more legible at
/// small sizes than any serif and is what the platform's users already read
/// fluently.
///
/// Rules of thumb for applying this:
///   - Display: numbers that matter (distance, elevation), screen and sheet
///     titles, achievement names. Things a sign would say.
///   - System: everything the user reads in sentences, every control label.
///   - Never set the display face below ~15sp; Fraunces' contrast gets
///     fragile and it stops being more legible than the system font.
///
/// Unlike iOS, nothing here needs a `relativeTo:` equivalent — Flutter
/// scales `fontSize` by the platform text-scale factor automatically, so
/// these styles already honor the user's font-size setting.
class NaturalType {
  /// The family name registered in pubspec.yaml. Flutter resolves the three
  /// bundled static instances by `fontWeight`, so unlike iOS there are no
  /// PostScript names to get right.
  static const String displayFamily = 'Fraunces';

  static TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w600,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: displayFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  // MARK: Semantic styles
  //
  // Prefer these over calling display() with a raw size. Sizes chosen once,
  // here, is what keeps a type system a system.

  /// Big numerals — route distance, elevation totals, walk summaries. The
  /// one place the face should be unmistakable.
  static TextStyle hero({Color? color}) =>
      display(40, weight: FontWeight.w700, color: color);

  /// Sheet and screen titles.
  static TextStyle title({Color? color}) =>
      display(23, weight: FontWeight.w600, color: color);

  /// Card headings and achievement names.
  static TextStyle heading({Color? color}) =>
      display(18, weight: FontWeight.w600, color: color);

  /// Inline emphasis that should still feel like the display face —
  /// segment distances, stat values in the trip log.
  static TextStyle statValue({Color? color}) =>
      display(17, weight: FontWeight.w500, color: color);
}

/// Corner radius and elevation were being chosen per call site, which is why
/// surfaces that should feel like siblings don't. One scale, used
/// everywhere, is most of what reads as "designed".
class NaturalMetrics {
  /// Chips, small controls.
  static const double radiusSmall = 10;

  /// Buttons, inline cards.
  static const double radiusMedium = 14;

  /// Sheets and the floating route card.
  static const double radiusLarge = 22;

  /// Surfaces resting on another surface.
  static const List<BoxShadow> shadowResting = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  /// Surfaces floating over the map, which need to separate from busy,
  /// high-contrast tiles.
  static const List<BoxShadow> shadowFloating = [
    BoxShadow(
      color: Color(0x2E000000),
      blurRadius: 14,
      offset: Offset(0, 5),
    ),
  ];

  /// Chrome for controls that float directly on the map — the directions,
  /// map-style, recenter, loop, more and search buttons, and the weather
  /// pill. A fully opaque background, a crisp visible border and a real drop
  /// shadow, so the control reads as "floating above the map" regardless of
  /// what's underneath (satellite imagery in particular otherwise washes out
  /// a subtler background/border combination).
  static BoxDecoration mapControlChrome({
    BorderRadius? borderRadius,
    bool circle = false,
    Color fill = NaturalPalette.buttonBg,
  }) {
    return BoxDecoration(
      color: fill,
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : (borderRadius ?? BorderRadius.circular(radiusMedium)),
      border: Border.all(color: NaturalPalette.controlBorder, width: 1.25),
      boxShadow: const [
        BoxShadow(
          color: Color(0x47000000),
          blurRadius: 6,
          offset: Offset(0, 3),
        ),
      ],
    );
  }
}
