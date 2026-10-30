import 'package:flutter/material.dart';

/// Design tokens for SONORA color palette.
///
/// Features a premium audiophile visual identity with deep charcoal/near-black
/// surfaces and sophisticated warm orange/champagne accents.
abstract final class AppColors {
  // --- Dark Palette (Primary Audiophile Identity) ---
  static const Color darkBackground = Color(0xFF0F0F12);
  static const Color darkSurface = Color(0xFF17171C);
  static const Color darkSurfaceElevated = Color(0xFF222228);
  static const Color darkSurfaceOverlay = Color(0xFF2D2D36);

  static const Color darkAccent = Color(0xFFE59866); // Warm audiophile amber
  static const Color darkAccentLight = Color(0xFFF0B27A); // Warm highlight
  static const Color darkAccentGold = Color(0xFFE5C07B); // Champagne gold
  static const Color darkAccentGlow = Color(0x33E59866); // Soft glow

  static const Color darkTextPrimary = Color(0xFFF5F5F7); // Soft white
  static const Color darkTextSecondary = Color(0xFFA1A1AA); // Muted grey
  static const Color darkTextTertiary = Color(0xFF71717A); // Subtle hint
  static const Color darkTextDisabled = Color(0xFF52525B);

  static const Color darkBorder = Color(0xFF27272F);
  static const Color darkBorderHighlight = Color(0xFF3F3F4E);
  static const Color darkDivider = Color(0xFF1E1E24);

  // Status colors (Dark)
  static const Color darkSuccess = Color(0xFF4EBA6F);
  static const Color darkWarning = Color(0xFFF39C12);
  static const Color darkError = Color(0xFFE74C3C);
  static const Color darkInfo = Color(0xFF5DADE2);

  // --- Light Palette (Clean, warm porcelain companion) ---
  static const Color lightBackground = Color(0xFFF9F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF0F0F3);
  static const Color lightSurfaceOverlay = Color(0xFFE5E5EB);

  static const Color lightAccent = Color(0xFFD35400); // Warm terracotta / amber
  static const Color lightAccentLight = Color(0xFFE59866);
  static const Color lightAccentGold = Color(0xFFD4AC0D);
  static const Color lightAccentGlow = Color(0x26D35400);

  static const Color lightTextPrimary = Color(0xFF18181B);
  static const Color lightTextSecondary = Color(0xFF71717A);
  static const Color lightTextTertiary = Color(0xFFA1A1AA);
  static const Color lightTextDisabled = Color(0xFFD4D4D8);

  static const Color lightBorder = Color(0xFFE4E4E7);
  static const Color lightBorderHighlight = Color(0xFFD1D1D6);
  static const Color lightDivider = Color(0xFFEEEEF0);

  // Status colors (Light)
  static const Color lightSuccess = Color(0xFF2ECC71);
  static const Color lightWarning = Color(0xFFE67E22);
  static const Color lightError = Color(0xFFC0392B);
  static const Color lightInfo = Color(0xFF2980B9);

  // --- Gradients ---
  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF16161B), Color(0xFF0F0F12)],
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF24242C), Color(0xFF1A1A20)],
  );

  static const LinearGradient darkAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF0B27A), Color(0xFFE59866)],
  );

  static const LinearGradient champagneGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF9E79F), Color(0xFFE5C07B)],
  );
}
