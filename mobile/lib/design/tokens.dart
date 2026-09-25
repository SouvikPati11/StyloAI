import 'package:flutter/material.dart';

/// StyloAI design tokens — one coherent, premium, gender-neutral system.
///
/// The palette is derived directly from the StyloAI logo: a deep navy-charcoal
/// canvas, a champagne/bronze gold accent, and ivory. It reads as an editorial
/// fashion-tech product for everyone — not a feminine beauty app. Navy is the
/// primary/interactive color (high contrast, accessible); gold is the metallic
/// brand accent used deliberately (brand marks, highlights, value/credits).
/// Colors are defined once here and never hard-coded ad hoc.
class AppColors {
  // ---- Light (editorial "paper") -----------------------------------------
  static const ink = Color(0xFF14181F); // navy-charcoal, primary text
  static const inkSoft = Color(0xFF454B57); // secondary text
  static const muted = Color(0xFF8B8F99); // tertiary text / captions
  static const bg = Color(0xFFFAF7F2); // warm ivory background
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF1ECE4);
  static const line = Color(0xFFE7E0D5);

  /// Primary interactive color — deep navy. Used for CTAs, active states.
  static const brand = Color(0xFF161C2C);

  /// Metallic brand accent — champagne/bronze gold. Deliberate highlights.
  static const accent = Color(0xFFA9803F);
  static const accentSoft = Color(0xFFF3EAD8);
  static const onAccent = Color(0xFFFFFFFF);
  static const onBrand = Color(0xFFF7F3EC);

  // Semantic
  static const success = Color(0xFF2F7D5B);
  static const warn = Color(0xFFB0782A);
  static const error = Color(0xFFB3402F);

  // ---- Dark (luxe — matches the logo icon canvas) ------------------------
  static const inkDark = Color(0xFFF5F0EC); // ivory text
  static const inkSoftDark = Color(0xFFC3BDB2);
  static const mutedDark = Color(0xFF8E9099);
  static const bgDark = Color(0xFF0E1626); // navy from the logo
  static const surfaceDark = Color(0xFF182136);
  static const surfaceAltDark = Color(0xFF212B41);
  static const lineDark = Color(0xFF2A3247);
  static const brandDark = Color(0xFFF5F0EC);
  static const accentDark = Color(0xFFCBA867); // champagne gold on navy
  static const accentSoftDark = Color(0xFF241E17);
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
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const pill = 999.0;
}

class AppDurations {
  static const fast = Duration(milliseconds: 180);
  static const med = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 600);
}
