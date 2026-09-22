import 'package:flutter/material.dart';

/// StyloAI design tokens — one coherent premium system used by every screen.
/// Editorial and calm: near-black ink on warm off-white, a single restrained
/// plum accent, generous whitespace. Defined once here; never hard-coded ad hoc.
class AppColors {
  // Light
  static const ink = Color(0xFF141414);
  static const inkSoft = Color(0xFF4A4540);
  static const muted = Color(0xFF8A827A);
  static const bg = Color(0xFFFAF8F5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF3EFEA);
  static const line = Color(0xFFE7E2DB);
  static const accent = Color(0xFF7C3A4B); // deep plum
  static const accentSoft = Color(0xFFF3E9EC);
  static const onAccent = Color(0xFFFFFFFF);

  // Semantic
  static const success = Color(0xFF2F7D5B);
  static const warn = Color(0xFFB0782A);
  static const error = Color(0xFFB3402F);

  // Dark
  static const inkDark = Color(0xFFF3EFEA);
  static const inkSoftDark = Color(0xFFC7C0B8);
  static const mutedDark = Color(0xFF938B82);
  static const bgDark = Color(0xFF141210);
  static const surfaceDark = Color(0xFF1E1B18);
  static const surfaceAltDark = Color(0xFF272320);
  static const lineDark = Color(0xFF34302B);
  static const accentDark = Color(0xFFC98A9B);
  static const accentSoftDark = Color(0xFF2E2226);
}

class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
  static const gutter = 16.0; // screen side padding
}

class AppRadii {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const pill = 999.0;
}

class AppDurations {
  static const fast = Duration(milliseconds: 180);
  static const med = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 600);
}
