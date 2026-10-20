import 'package:flutter/material.dart';

/// Warm, earthy palette pulled from the app icon — cream paths against deep
/// forest greens. The Android half of the same design system iOS's
/// `NaturalPalette.swift` defines; the values below are that file's light
/// appearance, converted from its 0–1 components.
///
/// **Light only, on purpose.** The iOS palette is dynamic: every surface has
/// a deep-forest dark variant. Reproducing that here means threading a
/// `BuildContext` through ~240 call sites, most of which sit inside `const`
/// constructors that would have to lose their `const`. That is a large
/// mechanical change with real regression risk, and it is not worth taking
/// on the same build that opens Play testing. `main.dart` therefore pins
/// `themeMode` to light so the app is consistently cream rather than
/// half-converted — a tracked gap against iOS, not an oversight.
///
/// Kept as plain static `Color`s so they work anywhere without a
/// `Theme.of(context)` lookup, and stay usable in `const` expressions.
class NaturalPalette {
  // MARK: Surfaces

  /// Floating-card background. Opaque, deliberately — see the note in
  /// NaturalPalette.swift: translucency let pin bubbles and street labels
  /// bleed up through the route card's own text. Separation comes from
  /// elevation (`NaturalMetrics.shadowFloating`) instead.
  static const Color cardBg = Color(0xFFF6EDD7);

  /// Pill/chip background, resting on a card.
  static const Color chipBg = Color(0xFFEADEC4);

  /// Map-control buttons sitting directly on the map surface. Slightly
  /// cooler than [cardBg] so they read as controls.
  static const Color buttonBg = Color(0xFFFBF6E8);

  // MARK: Strokes

  /// Deliberately subtle — for cards resting on the cream background.
  static const Color hairline = Color(0x214D422E);

  /// A meaningfully more visible border, for controls that float directly
  /// on the map. [hairline]'s values nearly disappear against busy or bright
  /// tiles (satellite imagery especially), so map-floating chrome needs its
  /// own higher-contrast border.
  static const Color controlBorder = Color(0x614D422E);

  // MARK: Ink

  static const Color ink = Color(0xFF2A3C2F);
  static const Color inkMuted = Color(0xFF69634D);

  // MARK: Accents

  /// Pathway green — matches the trail polyline color.
  static const Color forest = Color(0xFF218C45);

  /// Route accent. A softened terracotta, calmer than pure orange but still
  /// bold enough to read on top of the green trail network.
  static const Color route = Color(0xFFDF712A);

  /// Start/end waypoint pins. Forest green and a clay red — less neon than
  /// Material's stock green/red against the calmer base.
  static const Color startPin = Color(0xFF2E8C4D);
  static const Color endPin = Color(0xFFC44A40);

  /// Mid-route waypoint. Warm amber, distinct from both the green start and
  /// the red end without clashing with the terracotta route line.
  static const Color waypointPin = Color(0xFFC28C33);

  /// POI cluster bubbles. A deeper forest than [forest] so a white count
  /// stays legible at small sizes.
  static const Color cluster = Color(0xFF1B6539);

  /// Off-white used inside waypoint and POI pin rings. Slightly warm so the
  /// markers don't look stark against the cream-leaning UI.
  static const Color pinRing = Color(0xFFFBF7EE);

}
