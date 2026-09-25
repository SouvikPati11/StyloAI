import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design/tokens.dart';

/// Builds the light and dark [ThemeData] from the design tokens. A refined
/// serif display face (Fraunces) pairs with a clean sans (Inter) for body —
/// premium, editorial, and gender-neutral. Navy is the interactive color;
/// champagne gold is the metallic accent.
class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkDark : AppColors.ink;
    final bg = isDark ? AppColors.bgDark : AppColors.bg;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surface;
    final line = isDark ? AppColors.lineDark : AppColors.line;
    final muted = isDark ? AppColors.mutedDark : AppColors.muted;

    // Navy is primary in light; on the dark canvas the gold accent leads CTAs.
    final primary = isDark ? AppColors.accentDark : AppColors.brand;
    final onPrimary = isDark ? AppColors.ink : AppColors.onBrand;
    final accent = isDark ? AppColors.accentDark : AppColors.accent;

    final bodyBase = GoogleFonts.interTextTheme();

    final textTheme = bodyBase
        .apply(bodyColor: ink, displayColor: ink)
        .copyWith(
          displayLarge: GoogleFonts.fraunces(
              fontSize: 40,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: ink),
          displayMedium: GoogleFonts.fraunces(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              color: ink),
          headlineMedium: GoogleFonts.fraunces(
              fontSize: 24, fontWeight: FontWeight.w600, color: ink),
          titleLarge: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w600, color: ink),
          titleMedium: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600, color: ink),
          bodyLarge: GoogleFonts.inter(fontSize: 16, color: ink, height: 1.5),
          bodyMedium: GoogleFonts.inter(fontSize: 14, color: ink, height: 1.5),
          labelLarge: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600, color: ink),
          bodySmall: GoogleFonts.inter(fontSize: 12.5, color: muted),
        );

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: accent,
      onSecondary: isDark ? AppColors.ink : AppColors.onAccent,
      tertiary: accent,
      onTertiary: isDark ? AppColors.ink : AppColors.onAccent,
      error: AppColors.error,
      onError: Colors.white,
      surface: surface,
      onSurface: ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: scheme,
      textTheme: textTheme,
      primaryColor: primary,
      dividerColor: line,
      fontFamily: GoogleFonts.fraunces().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: ink,
        titleTextStyle: GoogleFonts.fraunces(
            fontSize: 22, fontWeight: FontWeight.w600, color: ink),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: line),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(54),
          textStyle:
              GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: line),
          textStyle:
              GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        side: BorderSide(color: line),
        labelStyle: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: ink),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: GoogleFonts.inter(color: bg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm)),
      ),
    );
  }
}
