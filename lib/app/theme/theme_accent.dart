import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Available audiophile accent color palettes in SONORA.
enum ThemeAccent {
  amberWarmth(
    id: 'amber',
    name: 'Amber Warmth',
    accentColor: Color(0xFFE59866),
    accentLight: Color(0xFFF0B27A),
    accentGold: Color(0xFFE5C07B),
    accentGlow: Color(0x33E59866),
  ),
  roseCopper(
    id: 'copper',
    name: 'Rose Copper',
    accentColor: Color(0xFFE07A5F),
    accentLight: Color(0xFFF4A261),
    accentGold: Color(0xFFE76F51),
    accentGlow: Color(0x33E07A5F),
  ),
  champagneGold(
    id: 'gold',
    name: 'Champagne Gold',
    accentColor: Color(0xFFE5C07B),
    accentLight: Color(0xFFF9E79F),
    accentGold: Color(0xFFD4AC0D),
    accentGlow: Color(0x33E5C07B),
  ),
  emeraldVelvet(
    id: 'emerald',
    name: 'Emerald Velvet',
    accentColor: Color(0xFF52B788),
    accentLight: Color(0xFF74C69D),
    accentGold: Color(0xFF95D5B2),
    accentGlow: Color(0x3352B788),
  ),
  sapphireTube(
    id: 'sapphire',
    name: 'Sapphire Tube',
    accentColor: Color(0xFF5DADE2),
    accentLight: Color(0xFF85C1E9),
    accentGold: Color(0xFFAED6F1),
    accentGlow: Color(0x335DADE2),
  );

  const ThemeAccent({
    required this.id,
    required this.name,
    required this.accentColor,
    required this.accentLight,
    required this.accentGold,
    required this.accentGlow,
  });

  final String id;
  final String name;
  final Color accentColor;
  final Color accentLight;
  final Color accentGold;
  final Color accentGlow;
}

/// Riverpod notifier managing active accent theme.
class ThemeAccentNotifier extends Notifier<ThemeAccent> {
  @override
  ThemeAccent build() => ThemeAccent.amberWarmth;

  void setAccent(ThemeAccent accent) {
    state = accent;
  }
}

/// Provider for active audiophile accent palette.
final themeAccentProvider = NotifierProvider<ThemeAccentNotifier, ThemeAccent>(
  ThemeAccentNotifier.new,
);
