import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/app/app.dart';
import 'package:sonora/app/theme/app_theme.dart';
import 'package:sonora/features/settings/presentation/settings_screen.dart';

void main() {
  testWidgets('SettingsScreen allows interactive theme mode switching', (
    tester,
  ) async {
    final container = ProviderContainer();

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
  });
}

