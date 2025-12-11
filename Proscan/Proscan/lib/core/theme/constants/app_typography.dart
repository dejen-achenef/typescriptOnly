import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  // Base TextStyle with Inter font
  static TextStyle _base({
    required Color color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LIGHT MODE
  // ─────────────────────────────────────────────────────────────
  static TextTheme get light {
    const Color onBackground = Color(0xFF111827);
    const Color onSurfaceVariant = Color(0xFF6B7280);

    return TextTheme(
      // Display - For large, prominent text
      displayLarge: _base(
        color: onBackground,
        fontSize: 57,
        fontWeight: FontWeight.w400,
        height: 1.12,
        letterSpacing: -0.25,
      ),
      displayMedium: _base(
        color: onBackground,
        fontSize: 45,
        fontWeight: FontWeight.w400,
        height: 1.16,
      ),
      displaySmall: _base(
        color: onBackground,
        fontSize: 36,
        fontWeight: FontWeight.w400,
        height: 1.22,
      ),

      // Headline - For section headers
      headlineLarge: _base(
        color: onBackground,
        fontSize: 32,
        fontWeight: FontWeight.w400,
        height: 1.25,
      ),
      headlineMedium: _base(
        color: onBackground,
        fontSize: 28,
        fontWeight: FontWeight.w400,
        height: 1.29,
      ),
      headlineSmall: _base(
        color: onBackground,
        fontSize: 24,
        fontWeight: FontWeight.w400,
        height: 1.33,
      ),

      // Title - For card titles, dialog titles
      titleLarge: _base(
        color: onBackground,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.27,
      ),
      titleMedium: _base(
        color: onBackground,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.5,
        letterSpacing: 0.15,
      ),
      titleSmall: _base(
        color: onSurfaceVariant,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.43,
        letterSpacing: 0.1,
      ),

      // Body - For paragraph text
      bodyLarge: _base(
        color: onBackground,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.5,
      ),
      bodyMedium: _base(
        color: onSurfaceVariant,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.43,
        letterSpacing: 0.25,
      ),
      bodySmall: _base(
        color: onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.33,
        letterSpacing: 0.4,
      ),

      // Label - For buttons, labels, captions
      labelLarge: _base(
        color: onBackground,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.43,
        letterSpacing: 0.1,
      ),
      labelMedium: _base(
        color: onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.33,
        letterSpacing: 0.5,
      ),
      labelSmall: _base(
        color: onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.45,
        letterSpacing: 0.5,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DARK MODE
  // ─────────────────────────────────────────────────────────────
  static TextTheme get dark {
    const Color onBackground = Color(0xFFF9FAFB);
    const Color onSurfaceVariant = Color(0xFF9CA3AF);

    return TextTheme(
      // Display - For large, prominent text
      displayLarge: _base(
        color: onBackground,
        fontSize: 57,
        fontWeight: FontWeight.w400,
        height: 1.12,
        letterSpacing: -0.25,
      ),
      displayMedium: _base(
        color: onBackground,
        fontSize: 45,
        fontWeight: FontWeight.w400,
        height: 1.16,
      ),
      displaySmall: _base(
        color: onBackground,
        fontSize: 36,
        fontWeight: FontWeight.w400,
        height: 1.22,
      ),

      // Headline - For section headers
      headlineLarge: _base(
        color: onBackground,
        fontSize: 32,
        fontWeight: FontWeight.w400,
        height: 1.25,
      ),
      headlineMedium: _base(
        color: onBackground,
        fontSize: 28,
        fontWeight: FontWeight.w400,
        height: 1.29,
      ),
      headlineSmall: _base(
        color: onBackground,
        fontSize: 24,
        fontWeight: FontWeight.w400,
        height: 1.33,
      ),

      // Title - For card titles, dialog titles
      titleLarge: _base(
        color: onBackground,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.27,
      ),
      titleMedium: _base(
        color: onBackground,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.5,
        letterSpacing: 0.15,
      ),
      titleSmall: _base(
        color: onSurfaceVariant,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.43,
        letterSpacing: 0.1,
      ),

      // Body - For paragraph text
      bodyLarge: _base(
        color: onBackground,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.5,
      ),
      bodyMedium: _base(
        color: onSurfaceVariant,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.43,
        letterSpacing: 0.25,
      ),
      bodySmall: _base(
        color: onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.33,
        letterSpacing: 0.4,
      ),

      // Label - For buttons, labels, captions
      labelLarge: _base(
        color: onBackground,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.43,
        letterSpacing: 0.1,
      ),
      labelMedium: _base(
        color: onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.33,
        letterSpacing: 0.5,
      ),
      labelSmall: _base(
        color: onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.45,
        letterSpacing: 0.5,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CONVENIENCE GETTERS FOR COMMON TEXT STYLES
  // ─────────────────────────────────────────────────────────────

  // For app bar titles
  static TextStyle get appBarTitle =>
      const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.2);

  // For document titles
  static TextStyle get documentTitle =>
      const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.3);

  // For document metadata (date, size, pages)
  static TextStyle get documentMetadata =>
      const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.4);

  // For button text
  static TextStyle get buttonLarge =>
      const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5);

  // For chip labels
  static TextStyle get chipLabel =>
      const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.4);

  // For section headers
  static TextStyle get sectionHeader => const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.2,
  );
}
