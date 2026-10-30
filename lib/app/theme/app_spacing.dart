import 'package:flutter/material.dart';

/// Spacing, radius, insets, and animation tokens for SONORA.
abstract final class AppSpacing {
  // Spacing scales
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double huge = 64.0;

  // Border radius tokens
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 999.0;

  // Corner Radii
  static const Radius cornerXs = Radius.circular(radiusXs);
  static const Radius cornerSm = Radius.circular(radiusSm);
  static const Radius cornerMd = Radius.circular(radiusMd);
  static const Radius cornerLg = Radius.circular(radiusLg);
  static const Radius cornerXl = Radius.circular(radiusXl);

  // BorderRadius helpers
  static const BorderRadius roundedXs = BorderRadius.all(cornerXs);
  static const BorderRadius roundedSm = BorderRadius.all(cornerSm);
  static const BorderRadius roundedMd = BorderRadius.all(cornerMd);
  static const BorderRadius roundedLg = BorderRadius.all(cornerLg);
  static const BorderRadius roundedXl = BorderRadius.all(cornerXl);
  static const BorderRadius roundedFull = BorderRadius.all(
    Radius.circular(radiusFull),
  );

  // Common Insets
  static const EdgeInsets insetsNone = EdgeInsets.zero;
  static const EdgeInsets insetsXs = EdgeInsets.all(xs);
  static const EdgeInsets insetsSm = EdgeInsets.all(sm);
  static const EdgeInsets insetsMd = EdgeInsets.all(md);
  static const EdgeInsets insetsLg = EdgeInsets.all(lg);
  static const EdgeInsets insetsXl = EdgeInsets.all(xl);

  static const EdgeInsets insetsHSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets insetsHMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets insetsHLg = EdgeInsets.symmetric(horizontal: lg);

  static const EdgeInsets insetsVSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets insetsVMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets insetsVLg = EdgeInsets.symmetric(vertical: lg);

  // Screen padding standard
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );

  // Animation durations
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationMedium = Duration(milliseconds: 400);
  static const Duration durationSlow = Duration(milliseconds: 600);

  // Animation curves
  static const Curve curveDefault = Curves.easeInOutCubicEmphasized;
  static const Curve curveEnter = Curves.easeOutCubic;
  static const Curve curveExit = Curves.easeInCubic;
  static const Curve curveSharp = Curves.fastOutSlowIn;
}
