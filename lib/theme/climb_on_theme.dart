import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class PacificTerrainColors {
  static const navy = Color(0xFF070A0B);
  static const navySoft = Color(0xFF14191B);
  static const seaGlass = Color(0xFF1B2926);
  static const cedar = Color(0xFFB7FF3C);
  static const skiBlue = Color(0xFF24C8FF);
  static const sand = Color(0xFFDDE6E2);
  static const cloud = Color(0xFF090C0D);
  static const ink = Color(0xFFF4F7F5);
  static const mist = Color(0xFF151B1D);
  static const line = Color(0xFF2A3335);
}

class ClimbOnTheme {
  static ThemeData light() => _build(ski: false);

  static ThemeData ski() => _build(ski: true);

  static ThemeData _build({required bool ski}) {
    final accent = ski
        ? PacificTerrainColors.skiBlue
        : PacificTerrainColors.cedar;
    final accentWash = ski
        ? const Color(0xFF102C35)
        : PacificTerrainColors.seaGlass;
    final bodyTheme = GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme)
        .apply(
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
      brightness: Brightness.dark,
      primary: accent,
      onPrimary: PacificTerrainColors.navy,
      primaryContainer: accentWash,
      onPrimaryContainer: accent,
      secondary: accent,
      onSecondary: PacificTerrainColors.navy,
      secondaryContainer: accentWash,
      onSecondaryContainer: PacificTerrainColors.ink,
      tertiary: ski ? PacificTerrainColors.cedar : PacificTerrainColors.skiBlue,
      onTertiary: PacificTerrainColors.navy,
      tertiaryContainer: const Color(0xFF182427),
      onTertiaryContainer: PacificTerrainColors.ink,
      error: const Color(0xFFFF705C),
      onError: PacificTerrainColors.navy,
      errorContainer: const Color(0xFF401D18),
      onErrorContainer: const Color(0xFFFFDAD2),
      surface: PacificTerrainColors.cloud,
      onSurface: PacificTerrainColors.ink,
      surfaceContainerHighest: PacificTerrainColors.mist,
      onSurfaceVariant: const Color(0xFFAAB5B1),
      outline: PacificTerrainColors.line,
      outlineVariant: const Color(0xFF202729),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: PacificTerrainColors.ink,
      onInverseSurface: PacificTerrainColors.navy,
      inversePrimary: accent,
    );

    const radius = BorderRadius.all(Radius.circular(14));
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: PacificTerrainColors.cloud,
      colorScheme: scheme,
      textTheme: textTheme,
      dividerColor: PacificTerrainColors.line,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: PacificTerrainColors.cloud,
        foregroundColor: PacificTerrainColors.ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.headlineSmall,
      ),
      cardTheme: const CardThemeData(
        color: PacificTerrainColors.navySoft,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: PacificTerrainColors.line),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: PacificTerrainColors.mist,
        selectedColor: accentWash,
        side: const BorderSide(color: PacificTerrainColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        labelStyle: textTheme.labelMedium,
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: PacificTerrainColors.navy,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accentWash,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PacificTerrainColors.navySoft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
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
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: PacificTerrainColors.navy,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PacificTerrainColors.ink,
          side: const BorderSide(color: PacificTerrainColors.line),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: const RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? accent
                : PacificTerrainColors.navySoft;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? PacificTerrainColors.navy
                : PacificTerrainColors.ink;
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
          foregroundColor: accent,
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
