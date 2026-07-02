import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class PacificTerrainColors {
  static const navy = Color(0xFF112D3B);
  static const navySoft = Color(0xFF1D4655);
  static const seaGlass = Color(0xFFD7E8E3);
  static const cedar = Color(0xFFB85C3E);
  static const sand = Color(0xFFE9DDC7);
  static const cloud = Color(0xFFFAFAF7);
  static const ink = Color(0xFF172427);
  static const mist = Color(0xFFEFF3F0);
  static const line = Color(0xFFD9E0DC);
}

class ClimbOnTheme {
  static ThemeData light() => _build(ski: false);

  static ThemeData ski() => _build(ski: true);

  static ThemeData _build({required bool ski}) {
    final primary = ski ? const Color(0xFF17495C) : PacificTerrainColors.navy;
    final bodyTheme = GoogleFonts.manropeTextTheme().apply(
      bodyColor: PacificTerrainColors.ink,
      displayColor: PacificTerrainColors.ink,
    );
    final serifTheme = GoogleFonts.sourceSerif4TextTheme(bodyTheme).apply(
      bodyColor: PacificTerrainColors.ink,
      displayColor: PacificTerrainColors.ink,
    );
    final textTheme = bodyTheme.copyWith(
      displayLarge: serifTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -1.4,
      ),
      displayMedium: serifTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -1,
      ),
      headlineLarge: serifTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
      ),
      headlineMedium: serifTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: serifTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleLarge: serifTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: bodyTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.15,
      ),
      labelLarge: bodyTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
      ),
      labelMedium: bodyTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
    );

    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: PacificTerrainColors.cloud,
      primaryContainer: PacificTerrainColors.seaGlass,
      onPrimaryContainer: PacificTerrainColors.navy,
      secondary: PacificTerrainColors.cedar,
      onSecondary: Colors.white,
      secondaryContainer: PacificTerrainColors.sand,
      onSecondaryContainer: PacificTerrainColors.ink,
      tertiary: const Color(0xFF527A71),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFDCEAE5),
      onTertiaryContainer: PacificTerrainColors.navy,
      error: const Color(0xFFA94635),
      onError: Colors.white,
      errorContainer: const Color(0xFFF4DED7),
      onErrorContainer: const Color(0xFF561E16),
      surface: PacificTerrainColors.cloud,
      onSurface: PacificTerrainColors.ink,
      surfaceContainerHighest: PacificTerrainColors.mist,
      onSurfaceVariant: const Color(0xFF56625F),
      outline: PacificTerrainColors.line,
      outlineVariant: const Color(0xFFE6EAE7),
      shadow: PacificTerrainColors.navy,
      scrim: PacificTerrainColors.navy,
      inverseSurface: PacificTerrainColors.navy,
      onInverseSurface: PacificTerrainColors.cloud,
      inversePrimary: PacificTerrainColors.seaGlass,
    );

    const radius = BorderRadius.all(Radius.circular(14));
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: PacificTerrainColors.cloud,
      colorScheme: scheme,
      textTheme: textTheme,
      dividerColor: PacificTerrainColors.line,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: PacificTerrainColors.cloud,
        foregroundColor: PacificTerrainColors.navy,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: PacificTerrainColors.navy,
        ),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shadowColor: Color(0x19112D3B),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: PacificTerrainColors.line),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: PacificTerrainColors.mist,
        selectedColor: PacificTerrainColors.seaGlass,
        side: const BorderSide(color: PacificTerrainColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: PacificTerrainColors.navy,
        ),
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: PacificTerrainColors.cloud,
        surfaceTintColor: Colors.transparent,
        indicatorColor: PacificTerrainColors.seaGlass,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(
            color: PacificTerrainColors.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        border: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: PacificTerrainColors.line),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: PacificTerrainColors.line),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: PacificTerrainColors.navy, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: PacificTerrainColors.cloud,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PacificTerrainColors.navy,
          side: const BorderSide(color: PacificTerrainColors.line),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: const RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: PacificTerrainColors.navy),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? PacificTerrainColors.navy
                : PacificTerrainColors.cloud;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? PacificTerrainColors.cloud
                : PacificTerrainColors.navy;
          }),
          side: const WidgetStatePropertyAll(
            BorderSide(color: PacificTerrainColors.line),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: radius),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: PacificTerrainColors.navy,
          shape: const RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: PacificTerrainColors.cloud,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: PacificTerrainColors.cloud,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
