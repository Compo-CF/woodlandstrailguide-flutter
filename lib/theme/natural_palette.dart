import 'package:flutter/material.dart';

/// Naturalized palette matching the iOS NaturalPalette.swift values.
/// Kept as a plain class of static Colors so it works anywhere without
/// needing a Theme.of(context) lookup.
class NaturalPalette {
  static const Color forest = Color(0xFF2E7A45);  // primary green
  static const Color route = Color(0xFFD46A3D);   // terracotta accent (routes/pins)
  static const Color cardBg = Color(0xFFFAF7EF);  // warm off-white background
  static const Color chipBg = Color(0xFFF0EBDF);  // slightly darker chip fill
  static const Color buttonBg = Color(0xFFFFFFFF);
  static const Color hairline = Color(0xFFDDD6C4);
  static const Color ink = Color(0xFF2A2A2A);
  static const Color inkMuted = Color(0xFF6E6E6E);

  static const Color startPin = Color(0xFF2E7A45);
  static const Color endPin = Color(0xFFD46A3D);
  static const Color waypointPin = Color(0xFFE0B23F);
}
