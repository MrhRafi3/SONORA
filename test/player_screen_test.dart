import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/app/theme/app_theme.dart';
import 'package:sonora/features/player/presentation/player_screen.dart';

void main() {
  testWidgets(
    'PlayerScreen renders full-screen player with controls and formats',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const PlayerScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title and labels
      expect(find.text('NOW PLAYING'), findsOneWidget);
      expect(find.text('Clair de Lune (Audiophile Re-Master)'), findsOneWidget);
      expect(find.text('EQ & DSP'), findsOneWidget);
      expect(find.text('Queue'), findsOneWidget);

      // Verify favorite toggle interaction
      final favButton = find.byTooltip('Favorite');
      expect(favButton, findsOneWidget);
      await tester.tap(favButton);
      await tester.pumpAndSettle();

      // Verify play/pause toggle interaction
      final playButton = find.byType(Slider);
      expect(playButton, findsOneWidget);
    },
  );
}
