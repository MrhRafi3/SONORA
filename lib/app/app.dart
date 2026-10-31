import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_accent.dart';

/// Notifier for managing active [ThemeMode]. Defaults to [ThemeMode.dark].
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }
}

/// Provider for managing active [ThemeMode]. Defaults to [ThemeMode.dark].
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// The root application widget for SONORA.
class SonoraApp extends ConsumerWidget {
  const SonoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final themeAccent = ref.watch(themeAccentProvider);

    return MaterialApp.router(
      title: 'SONORA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildLightTheme(accent: themeAccent),
      darkTheme: AppTheme.buildDarkTheme(accent: themeAccent),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
