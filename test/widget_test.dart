import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/app/app.dart';

void main() {
  testWidgets('SonoraApp launches and displays Home screen foundation', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: SonoraApp()));
    await tester.pumpAndSettle();

    // Verify app title and foundation header
    expect(find.text('SONORA'), findsOneWidget);
    expect(find.text('High-Resolution Audio Player'), findsOneWidget);
    expect(find.text('System Status'), findsOneWidget);

    // Verify navigation tabs
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
