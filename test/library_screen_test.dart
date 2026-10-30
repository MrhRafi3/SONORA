import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/app/theme/app_theme.dart';
import 'package:sonora/core/database/app_database.dart';
import 'package:sonora/features/library/presentation/library_providers.dart';
import 'package:sonora/features/library/presentation/library_screen.dart';

void main() {
  testWidgets('LibraryScreen renders Songs, Albums, Artists, Playlists tabs', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const LibraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title and Tabs
    expect(find.text('Music Library'), findsOneWidget);
    expect(find.text('Songs'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Artists'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);

    // Switch to Albums tab
    await tester.tap(find.text('Albums'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Switch to Artists tab
    await tester.tap(find.text('Artists'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Switch to Playlists tab
    await tester.tap(find.text('Playlists'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Create New Playlist'), findsOneWidget);

    // Open Sort Sheet
    final sortButton = find.byTooltip('Sort Options');
    expect(sortButton, findsOneWidget);
    await tester.tap(sortButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Sort Library By'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Artist'), findsOneWidget);
    expect(find.text('Date Added'), findsOneWidget);
    expect(find.text('Ascending Order'), findsOneWidget);

    // Close sort sheet by tapping outside or tapping close icon
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Clean unmount
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));

    await db.close();
  });
}
