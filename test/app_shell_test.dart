import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/app/app.dart';

void main() {
  testWidgets('AppShell navigates between destinations and shows mini-player', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: SonoraApp()));
    await tester.pumpAndSettle();

    // 1. Initial on Home
    expect(find.text('Master-Quality Audio'), findsOneWidget);

    // 2. Tap Library tab
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.text('Music Library'), findsOneWidget);
    expect(find.text('Songs'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);

    // 3. Tap Search tab
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Explore High-Resolution Formats'), findsOneWidget);

    // 4. Tap Settings tab
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Parametric Equalizer'), findsOneWidget);

    // 5. MiniPlayer remains visible across navigation
    expect(find.text('Clair de Lune (Audiophile Re-Master)'), findsOneWidget);

    // Clean unmount to drain Drift stream disposal timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('AppShell adapts to wide tablet layout with NavigationRail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const ProviderScope(child: SonoraApp()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // Clean unmount to drain Drift stream disposal timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
