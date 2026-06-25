import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClimbOnTheme {
  static ThemeData light() {
    return _build(
      primary: const Color(0xFF0F6B45),
      secondary: const Color(0xFFFFB000),
      tertiary: const Color(0xFF0077B6),
      background: const Color(0xFFE6EFE4),
      surface: const Color(0xFFFFFCF4),
      navSelected: const Color(0xFFCFE8D8),
      chip: const Color(0xFFFFD166),
      navIndicator: const Color(0xFFFFC53D),
    );
  }

  static ThemeData ski() {
    return _build(
      primary: const Color(0xFF005C99),
      secondary: const Color(0xFF00B4D8),
      tertiary: const Color(0xFF5E60CE),
      background: const Color(0xFFDFF3FF),
      surface: const Color(0xFFF7FCFF),
      navSelected: const Color(0xFFBDEBFF),
      chip: const Color(0xFF90E0EF),
      navIndicator: const Color(0xFF48CAE4),
    );
  }

  static ThemeData _build({
    required Color primary,
    required Color secondary,
    required Color tertiary,
    required Color background,
    required Color surface,
    required Color navSelected,
    required Color chip,
    required Color navIndicator,
  }) {
    const ink = Color(0xFF17201B);
    const ember = Color(0xFFE9572B);

    final textTheme = GoogleFonts.soraTextTheme().apply(
      bodyColor: ink,
      displayColor: ink,
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        error: ember,
        surface: surface,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: surface,
        foregroundColor: ink,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE1DDD1)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: chip,
        selectedColor: tertiary.withValues(alpha: 0.28),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: navIndicator,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD8D3C6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD8D3C6)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return primary;
            }
            return surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return ink;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: primary)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
