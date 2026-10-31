import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/app/app.dart';
import 'package:sonora/app/router.dart';
import 'package:sonora/app/theme/app_theme.dart';
import 'package:sonora/features/settings/presentation/settings_providers.dart';
import 'package:sonora/features/settings/presentation/settings_screen.dart';
import 'package:sonora/features/settings/presentation/subpages/about_settings_screen.dart';
import 'package:sonora/features/settings/presentation/subpages/appearance_settings_screen.dart';
import 'package:sonora/features/settings/presentation/subpages/playback_settings_screen.dart';

void main() {
  group('SettingsScreen — UI/UX Restructuring & Categories', () {
    testWidgets('Allows interactive theme mode switching', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default theme mode is dark
      expect(container.read(themeModeProvider), ThemeMode.dark);

      // Tap Light segment
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(container.read(themeModeProvider), ThemeMode.light);

      // Tap System segment
      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();
      expect(container.read(themeModeProvider), ThemeMode.system);

      // Clean unmount
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Renders all consolidated category cards on main screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header sections
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Configuration Categories'), findsOneWidget);

      // Verify all 7 consolidated category cards
      expect(find.text('Playback & Audio'), findsOneWidget);
      expect(find.text('Equalizer & Sound'), findsOneWidget);
      expect(find.text('Appearance & Personalization'), findsOneWidget);
      expect(find.text('Library & Storage'), findsOneWidget);
      expect(find.text('Notifications & Media Session'), findsOneWidget);
      expect(find.text('Privacy & Permissions'), findsOneWidget);
      expect(find.text('About SONORA'), findsOneWidget);

      // Verify Developer Credit pill on main card
      expect(find.text('Mrh Rafi'), findsOneWidget);

      // Clean unmount
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('PlaybackSettingsScreen toggles options and updates state', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const PlaybackSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bit-Perfect Direct Output'), findsOneWidget);
      expect(find.text('High-Res DAC Streaming'), findsOneWidget);
      expect(find.text('ReplayGain Normalization'), findsOneWidget);
      expect(find.text('Gapless Playback'), findsOneWidget);
      expect(find.text('Crossfade Transition'), findsOneWidget);
      expect(find.text('Pause on Disconnect'), findsOneWidget);

      // Initial state is true
      expect(container.read(settingsProvider).gaplessPlayback, isTrue);

      // Tap crossfade tile to open dialog
      await tester.tap(find.text('Crossfade Transition'));
      await tester.pumpAndSettle();

      expect(find.text('Crossfade Duration'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // Tap Done
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Clean unmount
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'AboutSettingsScreen prominently displays developer credit Mrh Rafi',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const AboutSettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Header Branding
        expect(find.text('SONORA'), findsOneWidget);
        expect(
          find.text('Premium High-Resolution Offline Audio Player'),
          findsOneWidget,
        );

        // Developer Credit Requirement 3
        expect(find.text('DEVELOPER & ARCHITECT'), findsOneWidget);
        expect(find.text('Mrh Rafi'), findsOneWidget);
        expect(
          find.text('Audio Engineering, DSP & Flutter Architecture'),
          findsOneWidget,
        );

        // Engine Architecture & Repository
        expect(find.text('Engine Architecture'), findsOneWidget);
        expect(find.text('C++17 DSP Core & Dart FFI'), findsOneWidget);
        expect(find.text('GitHub Repository'), findsOneWidget);
        expect(find.text('https://github.com/MrhRafi3/SONORA'), findsOneWidget);

        // Clean unmount
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('AppearanceSettingsScreen renders themes and accents', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const AppearanceSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Appearance & Personalization'), findsOneWidget);
      expect(find.text('Audiophile Accents'), findsOneWidget);
      expect(find.text('Amber Warmth'), findsOneWidget);
      expect(find.text('Rose Copper'), findsOneWidget);
      expect(find.text('Champagne Gold'), findsOneWidget);
      expect(find.text('Emerald Velvet'), findsOneWidget);
      expect(find.text('Sapphire Tube'), findsOneWidget);

      // Clean unmount
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Router navigates smoothly to Settings subpages', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.darkTheme,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to /settings
      router.go('/settings');
      await tester.pumpAndSettle();
      expect(find.text('Configuration Categories'), findsOneWidget);

      // Tap on About SONORA card
      await tester.tap(find.text('About SONORA'));
      await tester.pumpAndSettle();

      // Should be on About page with Mrh Rafi credit
      expect(find.text('Mrh Rafi'), findsOneWidget);
      expect(find.text('DEVELOPER & ARCHITECT'), findsOneWidget);

      // Clean unmount
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
