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

    // Verify app title and editorial header
    expect(find.text('SONORA'), findsWidgets);
    expect(find.text('Master-Quality Audio'), findsOneWidget);
    expect(find.text('Recently Played'), findsOneWidget);

    // Verify navigation tabs
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify active mini-player presence
    expect(find.text('Clair de Lune (Audiophile Re-Master)'), findsWidgets);

    // Drag the main scroll view to reveal lower sections
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Curated Playlists'), findsOneWidget);

    // Clean unmount to drain Drift stream disposal timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
