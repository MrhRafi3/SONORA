import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sonora/features/splash/presentation/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestSplash({
    required GoRouter router,
    bool disableAnimations = false,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        disableAnimations: disableAnimations,
        size: const Size(400, 800),
      ),
      child: ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets(
      'SplashScreen renders with solid #171717 background and centered logo',
      (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Text('Home Target')),
        ),
      ],
    );

    await tester.pumpWidget(buildTestSplash(router: router));

    // Initial frame
    await tester.pump();

    // Verify solid background color #171717
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFF171717));

    // Verify centered logo image is present
    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
    final assetImage = image.image as AssetImage;
    expect(assetImage.assetName, 'assets/branding/sonora_logo.png');

    // Verify strictly NO text, wordmarks, or taglines
    expect(find.byType(Text), findsNothing);

    // Pump to complete animation and verify navigation to home target
    await tester.pumpAndSettle();
    expect(find.text('Home Target'), findsOneWidget);
  });

  testWidgets(
      'SplashScreen executes scale and opacity entrance, pulse, and settling',
      (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Text('Home Target')),
        ),
      ],
    );

    await tester.pumpWidget(buildTestSplash(router: router));

    // Frame 0: Entrance begins (opacity 0, scale 0.85)
    await tester.pump();
    final initialOpacity = tester.widget<Opacity>(
      find.byKey(const Key('splash_logo_opacity')),
    );
    expect(initialOpacity.opacity, 0.0);

    // Frame at 300ms: Mid-entrance (fading in and scaling up)
    await tester.pump(const Duration(milliseconds: 300));
    final midEntranceOpacity = tester.widget<Opacity>(
      find.byKey(const Key('splash_logo_opacity')),
    );
    expect(midEntranceOpacity.opacity, greaterThan(0.0));
    expect(midEntranceOpacity.opacity, lessThan(1.0));

    // Frame at 650ms: Entrance complete (opacity ~ 1.0)
    await tester.pump(const Duration(milliseconds: 350));
    final entranceCompleteOpacity = tester.widget<Opacity>(
      find.byKey(const Key('splash_logo_opacity')),
    );
    expect(entranceCompleteOpacity.opacity, closeTo(1.0, 0.01));

    // Frame at 1000ms: During acoustic pulse (scale > 1.0)
    await tester.pump(const Duration(milliseconds: 350));
    final pulseTransform = tester.widget<Transform>(
      find.byKey(const Key('splash_logo_transform')),
    );
    final scaleValue = pulseTransform.transform.getMaxScaleOnAxis();
    expect(scaleValue, greaterThan(1.0));

    // Settle out to completion and navigate
    await tester.pumpAndSettle();
    expect(find.text('Home Target'), findsOneWidget);
  });

  testWidgets('SplashScreen respects reduced-motion accessibility setting', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Text('Home Target')),
        ),
      ],
    );

    await tester.pumpWidget(
      buildTestSplash(router: router, disableAnimations: true),
    );

    // Initial pump draws first frame
    await tester.pump();
    // In reduced motion, completes rapidly after 250ms delay
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Home Target'), findsOneWidget);
  });

  testWidgets(
      'SplashScreen maintains responsive sizing without overflow across compact and tablet displays',
      (
    tester,
  ) async {
    const viewports = [
      Size(320, 480), // Compact legacy phone
      Size(360, 640), // Standard Android
      Size(412, 915), // Tall flagship
      Size(800, 1200), // Tablet
    ];

    for (final viewport in viewports) {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1.0;

      final router = GoRouter(
        initialLocation: '/splash',
        routes: [
          GoRoute(
            path: '/splash',
            builder: (context, state) => const SplashScreen(),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: Text('Home Target')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      // Verify no RenderFlex errors at any stage of animation
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Clean unmount
      await tester.pumpWidget(const SizedBox.shrink());
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
