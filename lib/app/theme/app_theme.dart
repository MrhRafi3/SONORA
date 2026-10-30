import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Extension for accessing SONORA specific audiophile theme tokens.
@immutable
class SonoraThemeExtension extends ThemeExtension<SonoraThemeExtension> {
  const SonoraThemeExtension({
    required this.surfaceElevated,
    required this.surfaceOverlay,
    required this.accentGlow,
    required this.accentGold,
    required this.backgroundGradient,
    required this.cardGradient,
    required this.accentGradient,
  });

  final Color surfaceElevated;
  final Color surfaceOverlay;
  final Color accentGlow;
  final Color accentGold;
  final LinearGradient backgroundGradient;
  final LinearGradient cardGradient;
  final LinearGradient accentGradient;

  static const SonoraThemeExtension dark = SonoraThemeExtension(
    surfaceElevated: AppColors.darkSurfaceElevated,
    surfaceOverlay: AppColors.darkSurfaceOverlay,
    accentGlow: AppColors.darkAccentGlow,
    accentGold: AppColors.darkAccentGold,
    backgroundGradient: AppColors.darkBackgroundGradient,
    cardGradient: AppColors.darkCardGradient,
    accentGradient: AppColors.darkAccentGradient,
  );

  static const SonoraThemeExtension light = SonoraThemeExtension(
    surfaceElevated: AppColors.lightSurfaceElevated,
    surfaceOverlay: AppColors.lightSurfaceOverlay,
    accentGlow: AppColors.lightAccentGlow,
    accentGold: AppColors.lightAccentGold,
    backgroundGradient: LinearGradient(
      colors: [AppColors.lightBackground, AppColors.lightSurfaceElevated],
    ),
    cardGradient: LinearGradient(
      colors: [AppColors.lightSurface, AppColors.lightSurfaceElevated],
    ),
    accentGradient: LinearGradient(
      colors: [AppColors.lightAccentLight, AppColors.lightAccent],
    ),
  );

  @override
  SonoraThemeExtension copyWith({
    Color? surfaceElevated,
    Color? surfaceOverlay,
    Color? accentGlow,
    Color? accentGold,
    LinearGradient? backgroundGradient,
    LinearGradient? cardGradient,
    LinearGradient? accentGradient,
  }) {
    return SonoraThemeExtension(
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
      accentGlow: accentGlow ?? this.accentGlow,
      accentGold: accentGold ?? this.accentGold,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      cardGradient: cardGradient ?? this.cardGradient,
      accentGradient: accentGradient ?? this.accentGradient,
    );
  }

  @override
  SonoraThemeExtension lerp(
    ThemeExtension<SonoraThemeExtension>? other,
    double t,
  ) {
    if (other is! SonoraThemeExtension) return this;
    return SonoraThemeExtension(
      surfaceElevated:
          Color.lerp(surfaceElevated, other.surfaceElevated, t) ??
          surfaceElevated,
      surfaceOverlay:
          Color.lerp(surfaceOverlay, other.surfaceOverlay, t) ?? surfaceOverlay,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t) ?? accentGlow,
      accentGold: Color.lerp(accentGold, other.accentGold, t) ?? accentGold,
      backgroundGradient:
          LinearGradient.lerp(
            backgroundGradient,
            other.backgroundGradient,
            t,
          ) ??
          backgroundGradient,
      cardGradient:
          LinearGradient.lerp(cardGradient, other.cardGradient, t) ??
          cardGradient,
      accentGradient:
          LinearGradient.lerp(accentGradient, other.accentGradient, t) ??
          accentGradient,
    );
  }
}

/// Convenience extension on [BuildContext] to retrieve Sonora theme tokens.
extension SonoraThemeContext on BuildContext {
  SonoraThemeExtension get sonoraTheme =>
      Theme.of(this).extension<SonoraThemeExtension>() ??
      SonoraThemeExtension.dark;
}

/// Reusable Theme configuration for SONORA.
abstract final class AppTheme {
  /// Default Dark Theme: Audiophile deep charcoal with warm amber accents.
  static ThemeData get darkTheme {
    final textTheme = AppTypography.createDarkTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.darkAccent,
        onPrimary: Colors.black,
        secondary: AppColors.darkAccentGold,
        onSecondary: Colors.black,
        error: AppColors.darkError,
        onError: Colors.white,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        outline: AppColors.darkBorder,
        outlineVariant: AppColors.darkBorderHighlight,
      ),
      textTheme: textTheme,
      extensions: const [SonoraThemeExtension.dark],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.roundedMd,
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: AppColors.darkSurfaceOverlay,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.darkAccent);
          }
          return const IconThemeData(color: AppColors.darkTextTertiary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.darkAccent,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.darkTextTertiary,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.darkSurfaceElevated,
        indicatorColor: AppColors.darkSurfaceOverlay,
        elevation: 0,
        selectedIconTheme: const IconThemeData(color: AppColors.darkAccent),
        unselectedIconTheme: const IconThemeData(
          color: AppColors.darkTextTertiary,
        ),
        selectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.darkAccent,
        ),
        unselectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextTertiary,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.darkAccent.withValues(alpha: 0.18);
            }
            return AppColors.darkSurfaceElevated;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.darkAccent;
            }
            return AppColors.darkTextSecondary;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppColors.darkBorder),
          ),
          shape: WidgetStateProperty.all(
            const RoundedRectangleBorder(borderRadius: AppSpacing.roundedMd),
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurfaceElevated,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceElevated,
        side: const BorderSide(color: AppColors.darkBorder),
        shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedSm),
        labelStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.darkTextPrimary,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.darkAccent,
        inactiveTrackColor: AppColors.darkSurfaceOverlay,
        thumbColor: AppColors.darkAccent,
        overlayColor: AppColors.darkAccentGlow,
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Light Theme: Minimalist warm companion theme.
  static ThemeData get lightTheme {
    final textTheme = AppTypography.createLightTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.lightAccent,
        onPrimary: Colors.white,
        secondary: AppColors.lightAccentGold,
        onSecondary: Colors.black,
        error: AppColors.lightError,
        onError: Colors.white,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        outline: AppColors.lightBorder,
        outlineVariant: AppColors.lightBorderHighlight,
      ),
      textTheme: textTheme,
      extensions: const [SonoraThemeExtension.light],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.lightTextPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.roundedMd,
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        indicatorColor: AppColors.lightSurfaceElevated,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.lightAccent);
          }
          return const IconThemeData(color: AppColors.lightTextTertiary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.lightAccent,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.lightTextTertiary,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.lightSurfaceElevated,
        indicatorColor: AppColors.lightSurfaceOverlay,
        elevation: 0,
        selectedIconTheme: const IconThemeData(color: AppColors.lightAccent),
        unselectedIconTheme: const IconThemeData(
          color: AppColors.lightTextTertiary,
        ),
        selectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.lightAccent,
        ),
        unselectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.lightTextTertiary,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.lightAccent.withValues(alpha: 0.15);
            }
            return AppColors.lightSurfaceElevated;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.lightAccent;
            }
            return AppColors.lightTextSecondary;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppColors.lightBorder),
          ),
          shape: WidgetStateProperty.all(
            const RoundedRectangleBorder(borderRadius: AppSpacing.roundedMd),
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurfaceElevated,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurfaceElevated,
        side: const BorderSide(color: AppColors.lightBorder),
        shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedSm),
        labelStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.lightTextPrimary,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.lightAccent,
        inactiveTrackColor: AppColors.lightSurfaceOverlay,
        thumbColor: AppColors.lightAccent,
        overlayColor: AppColors.lightAccentGlow,
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
