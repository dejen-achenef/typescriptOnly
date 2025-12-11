import 'dart:ui';
import 'package:flutter/material.dart';

class AppDesign {
  // ──────────────────────── GLASSMORPHISM ────────────────────────
  static BoxDecoration glass({
    double opacity = 0.1,
    double blur = 10,
    Color color = Colors.white,
    double borderRadius = 16,
    Border? border,
  }) {
    return BoxDecoration(
      color: color.withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: border ?? Border.all(color: Colors.white.withOpacity(0.2)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // ──────────────────────── GRADIENTS ────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1D0075), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFD946EF), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF111827), Color(0xFF1F2937)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ──────────────────────── SHADOWS ────────────────────────
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF1D0075).withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
        BoxShadow(
          color: const Color(0xFF1D0075).withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 4),
          spreadRadius: -2,
        ),
      ];

  static List<BoxShadow> get strongShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 24,
          offset: const Offset(0, 12),
          spreadRadius: -4,
        ),
      ];

  // ──────────────────────── ANIMATIONS ────────────────────────
  static const Duration durationFast = Duration(milliseconds: 200);
  static const Duration durationMedium = Duration(milliseconds: 400);
  static const Duration durationSlow = Duration(milliseconds: 600);

  static const Curve curveSmooth = Curves.easeInOutCubicEmphasized;
}
