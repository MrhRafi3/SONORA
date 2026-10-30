import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/app/theme/app_colors.dart';
import 'package:sonora/app/theme/app_spacing.dart';
import 'package:sonora/app/theme/app_theme.dart';

void main() {
  group('Design System & Theme Tokens', () {
    test('Dark theme is configured with correct audiophile color scheme', () {
      final darkTheme = AppTheme.darkTheme;

      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.scaffoldBackgroundColor, AppColors.darkBackground);
      expect(darkTheme.colorScheme.primary, AppColors.darkAccent);
      expect(darkTheme.colorScheme.surface, AppColors.darkSurface);

      final extension = darkTheme.extension<SonoraThemeExtension>();
      expect(extension, isNotNull);
      expect(extension!.surfaceElevated, AppColors.darkSurfaceElevated);
      expect(extension.accentGlow, AppColors.darkAccentGlow);
    });

    test('Light theme is configured properly', () {
      final lightTheme = AppTheme.lightTheme;

      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.scaffoldBackgroundColor, AppColors.lightBackground);
      expect(lightTheme.colorScheme.primary, AppColors.lightAccent);

      final extension = lightTheme.extension<SonoraThemeExtension>();
      expect(extension, isNotNull);
      expect(extension!.surfaceElevated, AppColors.lightSurfaceElevated);
    });

    test('Spacing tokens maintain consistent scale hierarchy', () {
      expect(AppSpacing.xxs, lessThan(AppSpacing.xs));
      expect(AppSpacing.xs, lessThan(AppSpacing.sm));
      expect(AppSpacing.sm, lessThan(AppSpacing.md));
      expect(AppSpacing.md, lessThan(AppSpacing.lg));
      expect(AppSpacing.lg, lessThan(AppSpacing.xl));
      expect(AppSpacing.xl, lessThan(AppSpacing.xxl));
      expect(AppSpacing.xxl, lessThan(AppSpacing.huge));
    });
  });
}
