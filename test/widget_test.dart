import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/app/app.dart';

void main() {
  testWidgets('SonoraApp launches with Phase 02 home screen and mini-player', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: SonoraApp()));
    await tester.pumpAndSettle();

    // Verify app title and genuine empty state on first launch (no demo songs)
    expect(find.text('SONORA'), findsWidgets);
    expect(find.text('Your Music Library is Quiet'), findsOneWidget);

    // Verify navigation tabs
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify clean launch has no demo track in mini-player
    expect(find.text('Clair de Lune (Audiophile Re-Master)'), findsNothing);

    // Toggle showcase preview
    await tester.tap(find.text('View Showcase Preview'));
    await tester.pumpAndSettle();

    expect(find.text('Master-Quality Audio'), findsOneWidget);
    expect(find.text('Recently Played'), findsOneWidget);

    // Drag the main scroll view to reveal lower sections
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Curated Playlists'), findsOneWidget);

    // Clean unmount to drain Drift stream disposal timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
