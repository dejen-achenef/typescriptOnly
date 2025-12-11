import 'package:flutter/material.dart';
import 'app_typography.dart';

class AppColors {
  // ──────────────────────── PRIMARY COLOR SCALE ────────────────────────
  static const Color primary = Color(0xFF1D0075); // Deep Royal Blue

  // PRIMARY COLOR SCALE (Deep Royal Blue)
  static const Color primary25 = Color(0xFFF5F3FF);
  static const Color primary50 = Color(0xFFEDE9FE);
  static const Color primary100 = Color(0xFFDDD6FE);
  static const Color primary200 = Color(0xFFC4B5FD);
  static const Color primary300 = Color(0xFFA78BFA);
  static const Color primary400 = Color(0xFF8B5CF6);
  static const Color primary500 = Color(0xFF7C3AED);
  static const Color primary600 = Color(0xFF6D28D9);
  static const Color primary700 = Color(0xFF5B21B6);
  static const Color primary800 = Color(0xFF4C1D95);
  static const Color primary900 = Color(0xFF1D0075); // Base primary
  static const Color primary950 = Color(0xFF0F0052);

  // SECONDARY COLOR (Vibrant Purple - Complementary)
  static const Color secondary50 = Color(0xFFFDF4FF);
  static const Color secondary100 = Color(0xFFFAE8FF);
  static const Color secondary200 = Color(0xFFF5D0FE);
  static const Color secondary300 = Color(0xFFF0ABFC);
  static const Color secondary400 = Color(0xFFE879F9);
  static const Color secondary500 = Color(0xFFD946EF);
  static const Color secondary600 = Color(0xFFC026D3);
  static const Color secondary700 = Color(0xFFA21CAF);
  static const Color secondary800 = Color(0xFF86198F);
  static const Color secondary900 = Color(0xFF701A75);

  // TERTIARY COLOR (Electric Pink - Accent)
  static const Color tertiary50 = Color(0xFFFFF1F3);
  static const Color tertiary100 = Color(0xFFFFE4E8);
  static const Color tertiary200 = Color(0xFFFECDD6);
  static const Color tertiary300 = Color(0xFFFDA4AF);
  static const Color tertiary400 = Color(0xFFFB7185);
  static const Color tertiary500 = Color(0xFFF43F5E);
  static const Color tertiary600 = Color(0xFFE11D48);
  static const Color tertiary700 = Color(0xFFBE123C);
  static const Color tertiary800 = Color(0xFF9F1239);
  static const Color tertiary900 = Color(0xFF881337);

  // NEUTRAL/GRAY PALETTE (Optimized for both themes)
  static const Color neutral25 = Color(0xFFFCFCFD);
  static const Color neutral50 = Color(0xFFF9FAFB);
  static const Color neutral100 = Color(0xFFF3F4F6);
  static const Color neutral200 = Color(0xFFE5E7EB);
  static const Color neutral300 = Color(0xFFD1D5DB);
  static const Color neutral400 = Color(0xFF9CA3AF);
  static const Color neutral500 = Color(0xFF6B7280);
  static const Color neutral600 = Color(0xFF4B5563);
  static const Color neutral700 = Color(0xFF374151);
  static const Color neutral800 = Color(0xFF1F2937);
  static const Color neutral900 = Color(0xFF111827);
  static const Color neutral950 = Color(0xFF0A0F1C);

  // SEMANTIC COLORS
  static const Color error50 = Color(0xFFFEF2F2);
  static const Color error100 = Color(0xFFFEE2E2);
  static const Color error200 = Color(0xFFFECACA);
  static const Color error300 = Color(0xFFFCA5A5);
  static const Color error400 = Color(0xFFF87171);
  static const Color error500 = Color(0xFFEF4444);
  static const Color error600 = Color(0xFFDC2626);
  static const Color error700 = Color(0xFFB91C1C);
  static const Color error800 = Color(0xFF991B1B);
  static const Color error900 = Color(0xFF7F1D1D);

  static const Color success50 = Color(0xFFF0FDF4);
  static const Color success100 = Color(0xFFDCFCE7);
  static const Color success200 = Color(0xFFBBF7D0);
  static const Color success300 = Color(0xFF86EFAC);
  static const Color success400 = Color(0xFF4ADE80);
  static const Color success500 = Color(0xFF22C55E);
  static const Color success600 = Color(0xFF16A34A);
  static const Color success700 = Color(0xFF15803D);
  static const Color success800 = Color(0xFF166534);
  static const Color success900 = Color(0xFF14532D);

  static const Color warning50 = Color(0xFFFFFBEB);
  static const Color warning100 = Color(0xFFFEF3C7);
  static const Color warning200 = Color(0xFFFDE68A);
  static const Color warning300 = Color(0xFFFCD34D);
  static const Color warning400 = Color(0xFFFBBF24);
  static const Color warning500 = Color(0xFFF59E0B);
  static const Color warning600 = Color(0xFFD97706);
  static const Color warning700 = Color(0xFFB45309);
  static const Color warning800 = Color(0xFF92400E);
  static const Color warning900 = Color(0xFF78350F);

  static const Color info50 = Color(0xFFF0F9FF);
  static const Color info100 = Color(0xFFE0F2FE);
  static const Color info200 = Color(0xFFBAE6FD);
  static const Color info300 = Color(0xFF7DD3FC);
  static const Color info400 = Color(0xFF38BDF8);
  static const Color info500 = Color(0xFF0EA5E9);
  static const Color info600 = Color(0xFF0284C7);
  static const Color info700 = Color(0xFF0369A1);
  static const Color info800 = Color(0xFF075985);
  static const Color info900 = Color(0xFF0C4A6E);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        // PRIMARY - Deep Royal Blue
        primary: AppColors.primary900,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primary50,
        onPrimaryContainer: AppColors.primary900,

        // SECONDARY - Vibrant Purple
        secondary: AppColors.secondary600,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.secondary50,
        onSecondaryContainer: AppColors.secondary900,

        // TERTIARY - Electric Pink
        tertiary: AppColors.tertiary600,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.tertiary50,
        onTertiaryContainer: AppColors.tertiary900,

        // ERROR
        error: AppColors.error600,
        onError: Colors.white,
        errorContainer: AppColors.error50,
        onErrorContainer: AppColors.error700,

        // BACKGROUND & SURFACE
        background: AppColors.neutral50,
        onBackground: AppColors.neutral900,
        surface: Colors.white,
        onSurface: AppColors.neutral900,
        surfaceVariant: AppColors.neutral100,
        onSurfaceVariant: AppColors.neutral700,

        // OUTLINE
        outline: AppColors.neutral300,
        outlineVariant: AppColors.neutral200,

        // SURFACE TINT
        surfaceTint: AppColors.primary900,
      ),

      // Typography
      textTheme: AppTypography.light,

      // Component Themes
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.neutral900,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.light.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: AppColors.neutral700),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.neutral300.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.neutral200, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary900,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          textStyle: AppTypography.buttonLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary900,
          textStyle: AppTypography.buttonLarge.copyWith(
            color: AppColors.primary900,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary900,
          side: BorderSide(color: AppColors.primary900, width: 1.5),
          textStyle: AppTypography.buttonLarge.copyWith(
            color: AppColors.primary900,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.neutral50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.neutral300, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.neutral300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary900, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error500, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error500, width: 2),
        ),
        labelStyle: AppTypography.light.bodyMedium?.copyWith(
          color: AppColors.neutral600,
        ),
        hintStyle: AppTypography.light.bodyMedium?.copyWith(
          color: AppColors.neutral500,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary900,
        unselectedItemColor: AppColors.neutral500,
        elevation: 4,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary900,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: AppColors.neutral200,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        // PRIMARY - Lighter blue for better contrast in dark mode
        primary: AppColors.primary400,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primary800,
        onPrimaryContainer: AppColors.primary100,

        // SECONDARY - Vibrant Purple
        secondary: AppColors.secondary400,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.secondary800,
        onSecondaryContainer: AppColors.secondary100,

        // TERTIARY - Electric Pink
        tertiary: AppColors.tertiary400,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.tertiary800,
        onTertiaryContainer: AppColors.tertiary100,

        // ERROR
        error: AppColors.error400,
        onError: Colors.white,
        errorContainer: AppColors.error800,
        onErrorContainer: AppColors.error100,

        // BACKGROUND & SURFACE - Premium dark palette
        background: AppColors.neutral950,
        onBackground: AppColors.neutral50,
        surface: AppColors.neutral900,
        onSurface: AppColors.neutral50,
        surfaceVariant: AppColors.neutral800,
        onSurfaceVariant: AppColors.neutral300,

        // OUTLINE
        outline: AppColors.neutral700,
        outlineVariant: AppColors.neutral600,

        // SURFACE TINT
        surfaceTint: AppColors.primary400,
      ),

      // Typography
      textTheme: AppTypography.dark,

      // Component Themes
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.neutral900,
        foregroundColor: AppColors.neutral50,
        elevation: 0,
        scrolledUnderElevation: 2,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.dark.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: AppColors.neutral300),
      ),

      cardTheme: CardThemeData(
        color: AppColors.neutral900,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.neutral700, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary400,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          textStyle: AppTypography.buttonLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary400,
          textStyle: AppTypography.buttonLarge.copyWith(
            color: AppColors.primary400,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary400,
          side: BorderSide(color: AppColors.primary400, width: 1.5),
          textStyle: AppTypography.buttonLarge.copyWith(
            color: AppColors.primary400,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.neutral800,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.neutral700, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.neutral700, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary400, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error400, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error400, width: 2),
        ),
        labelStyle: AppTypography.dark.bodyMedium?.copyWith(
          color: AppColors.neutral400,
        ),
        hintStyle: AppTypography.dark.bodyMedium?.copyWith(
          color: AppColors.neutral500,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.neutral900,
        selectedItemColor: AppColors.primary400,
        unselectedItemColor: AppColors.neutral400,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary400,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: AppColors.neutral700,
        thickness: 1,
        space: 1,
      ),

      // DARK MODE SPECIFIC ENHANCEMENTS
      scaffoldBackgroundColor: AppColors.neutral950,
      dialogBackgroundColor: AppColors.neutral900,
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.neutral900,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}

// ELEVATION COLORS FOR BOTH THEMES
class _ElevationColors extends ThemeExtension<_ElevationColors> {
  final Color level0;
  final Color level1;
  final Color level2;
  final Color level3;
  final Color level4;
  final Color level5;

  const _ElevationColors({
    required this.level0,
    required this.level1,
    required this.level2,
    required this.level3,
    required this.level4,
    required this.level5,
  });

  static const _ElevationColors light = _ElevationColors(
    level0: Colors.transparent,
    level1: Color(0x0A000000),
    level2: Color(0x0F000000),
    level3: Color(0x14000000),
    level4: Color(0x1A000000),
    level5: Color(0x1F000000),
  );

  static const _ElevationColors dark = _ElevationColors(
    level0: Colors.transparent,
    level1: Color(0x0AFFFFFF),
    level2: Color(0x0FFFFFFF),
    level3: Color(0x14FFFFFF),
    level4: Color(0x1AFFFFFF),
    level5: Color(0x1FFFFFFF),
  );

  @override
  ThemeExtension<_ElevationColors> copyWith({
    Color? level0,
    Color? level1,
    Color? level2,
    Color? level3,
    Color? level4,
    Color? level5,
  }) {
    return _ElevationColors(
      level0: level0 ?? this.level0,
      level1: level1 ?? this.level1,
      level2: level2 ?? this.level2,
      level3: level3 ?? this.level3,
      level4: level4 ?? this.level4,
      level5: level5 ?? this.level5,
    );
  }

  @override
  ThemeExtension<_ElevationColors> lerp(
    ThemeExtension<_ElevationColors>? other,
    double t,
  ) {
    if (other is! _ElevationColors) {
      return this;
    }
    return _ElevationColors(
      level0: Color.lerp(level0, other.level0, t)!,
      level1: Color.lerp(level1, other.level1, t)!,
      level2: Color.lerp(level2, other.level2, t)!,
      level3: Color.lerp(level3, other.level3, t)!,
      level4: Color.lerp(level4, other.level4, t)!,
      level5: Color.lerp(level5, other.level5, t)!,
    );
  }
}

// EASY ACCESS TO ELEVATION COLORS
extension ElevationColorsExtension on ThemeData {
  _ElevationColors get elevationColors =>
      extension<_ElevationColors>() ?? _ElevationColors.light;
}
