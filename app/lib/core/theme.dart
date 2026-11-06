import 'package:flutter/material.dart';

class AppTheme {
  // Theme Palette: Forest Green, Warm Beige, Electric Purple

  // Primary: Forest Green
  static const Color primary = Color(0xFF1B4332);
  static const Color primaryContainer = Color(0xFF2D6A4F);
  static const Color primaryFixed = Color(0xFFD8F3DC);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryFixed = Color(0xFF081C15);

  // Secondary & Accent: Electric Purple
  static const Color secondary = Color(0xFF7C3AED);
  static const Color accent = Color(0xFF8B5CF6);
  static const Color electricPurple = Color(0xFF7C3AED);
  static const Color electricPurpleLight = Color(0xFFA78BFA);
  static const Color secondaryContainer = Color(0xFFEDE9FE);
  static const Color onSecondaryContainer = Color(0xFF5B21B6);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // Neutral Canvas & Cards: Warm Beige
  static const Color beige = Color(0xFFF5F2EB);
  static const Color beigeDark = Color(0xFFE6DEC9);
  static const Color background = Color(0xFFF7F4EE);
  static const Color surface = Color(0xFFF7F4EE);
  static const Color surfaceLight = Color(0xFFEFECE4);
  static const Color surfaceContainer = Color(0xFFEAE5DC);
  static const Color surfaceContainerLow = Color(0xFFF2EFE8);
  static const Color surfaceContainerHigh = Color(0xFFE2DCD2);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color inverseSurface = Color(0xFF1B2A1E); // Deep forest pine
  static const Color inverseOnSurface = Color(0xFFF0F4F1);

  // Typography & Borders
  static const Color textMain = Color(0xFF162518);
  static const Color textMuted = Color(0xFF526154);
  static const Color textSecondary = Color(0xFF768678);
  static const Color border = Color(0xFFE0D8CB);
  static const Color borderLight = Color(0xFFEBE5DA);
  static const Color outline = Color(0xFF768678);

  // Semantics & Status
  static const Color tertiary = Color(0xFFD97706);
  static const Color tertiaryFixed = Color(0xFFFEF3C7);
  static const Color onTertiaryFixed = Color(0xFF78350F);

  static const Color success = Color(0xFF2D6A4F);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFB91C1C);
  static const Color errorContainer = Color(0xFFFEE2E2);

  // Dark variant aliases for backwards compatibility
  static const Color darkBackground = Color(0xFF0F1B12);
  static const Color darkSurface = Color(0xFF17291B);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        surface: surfaceContainerLowest,
        onSurface: textMain,
        error: error,
      ),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textMain,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
        iconTheme: IconThemeData(color: textMain),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: secondary, width: 2), // Electric purple focus
        ),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
        labelStyle: const TextStyle(color: textMuted, fontSize: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: secondary, // Electric purple active nav item
        unselectedItemColor: textSecondary,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  // Backward compatibility alias for main.dart
  static ThemeData get darkTheme => lightTheme;
}
