import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sonora/features/splash/presentation/splash_screen.dart';
import 'package:sonora/features/splash/presentation/widgets/animated_sonora_wordmark.dart';
import 'package:sonora/features/splash/presentation/widgets/macos_ambient_backdrop.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  GoRouter buildTestRouter() {
    return GoRouter(
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
  }

  Widget buildTestSplash({
    required GoRouter router,
    bool disableAnimations = false,
    Size size = const Size(400, 800),
    EdgeInsets padding = EdgeInsets.zero,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        disableAnimations: disableAnimations,
        size: size,
        padding: padding,
        textScaler: textScaler,
      ),
      child: ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
  }

  double fadeOpacityOf(WidgetTester tester, Key key) {
    return tester.widget<FadeTransition>(find.byKey(key)).opacity.value;
  }

  testWidgets(
    'SplashScreen renders charcoal base, ambient backdrop, SONORA wordmark, and no illustrations',
    (tester) async {
      final router = buildTestRouter();

      await tester.pumpWidget(buildTestSplash(router: router));
      await tester.pump();

      // Verify solid charcoal base color #171717
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF171717));

      // Verify both Android and iOS light-on-dark system overlay styling
      final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
      );
      expect(overlay.value.statusBarIconBrightness, Brightness.light);
      expect(overlay.value.statusBarBrightness, Brightness.dark);

      // Verify ambient GPU-friendly backdrop and animated wordmark
      expect(find.byType(MacosAmbientBackdrop), findsOneWidget);
      expect(find.byKey(const Key('splash_background_canvas')), findsOneWidget);
      expect(find.byType(AnimatedSonoraWordmark), findsOneWidget);

      // Verify no illustrations, icons, or raster logo images
      expect(find.byType(Image), findsNothing);
      expect(find.byType(Icon), findsNothing);

      // Verify all 6 SONORA letters and tagline exist
      for (var i = 0; i < AnimatedSonoraWordmark.letters.length; i++) {
        expect(find.byKey(Key('splash_letter_$i')), findsOneWidget);
      }
      expect(find.text('FEEL EVERY FREQUENCY'), findsOneWidget);

      // Complete animation and verify navigation to home target
      await tester.pumpAndSettle();
      expect(find.text('Home Target'), findsOneWidget);
    },
  );

  testWidgets(
    'SplashScreen runs staggered letter reveal, letter-spacing settle, and tagline fade-in',
    (tester) async {
      final router = buildTestRouter();

      await tester.pumpWidget(buildTestSplash(router: router));

      // Frame 0: Letters hidden at initial state, tagline hidden
      await tester.pump();
      expect(fadeOpacityOf(tester, const Key('splash_letter_opacity_0')), 0.0);
      expect(fadeOpacityOf(tester, const Key('splash_letter_opacity_5')), 0.0);
      expect(fadeOpacityOf(tester, const Key('splash_tagline_opacity')), 0.0);

      final letter0InitialTx = tester
          .widget<Transform>(find.byKey(const Key('splash_letter_transform_0')))
          .transform
          .getTranslation();
      final letter5InitialTx = tester
          .widget<Transform>(find.byKey(const Key('splash_letter_transform_5')))
          .transform
          .getTranslation();
      // Initial spacing pushes outer letters outward from center
      expect(letter0InitialTx.x, lessThan(0.0));
      expect(letter5InitialTx.x, greaterThan(0.0));
      // Initial vertical offset is slightly below resting baseline
      expect(letter0InitialTx.y, greaterThan(0.0));

      // At 750ms: Staggered reveal in progress (S ahead of A, spacing converging)
      await tester.pump(const Duration(milliseconds: 750));
      final letter0MidOpacity = fadeOpacityOf(
        tester,
        const Key('splash_letter_opacity_0'),
      );
      final letter5MidOpacity = fadeOpacityOf(
        tester,
        const Key('splash_letter_opacity_5'),
      );
      expect(letter0MidOpacity, greaterThan(letter5MidOpacity));
      expect(letter0MidOpacity, greaterThan(0.2));

      final letter0MidTx = tester
          .widget<Transform>(find.byKey(const Key('splash_letter_transform_0')))
          .transform
          .getTranslation();
      expect(letter0MidTx.x.abs(), lessThan(letter0InitialTx.x.abs()));
      expect(letter0MidTx.y, lessThan(letter0InitialTx.y));

      // Tagline not yet visible at 750ms (starts at 56% ~ 1344ms)
      expect(fadeOpacityOf(tester, const Key('splash_tagline_opacity')), 0.0);

      // At 1600ms (750 + 850): Tagline actively fading in
      await tester.pump(const Duration(milliseconds: 850));
      final taglineMidOpacity = fadeOpacityOf(
        tester,
        const Key('splash_tagline_opacity'),
      );
      expect(taglineMidOpacity, greaterThan(0.0));
      expect(taglineMidOpacity, lessThan(1.0));

      // At 2050ms (1600 + 450): Typography and tagline settled before transition
      await tester.pump(const Duration(milliseconds: 450));
      final letter5SettledOpacity = fadeOpacityOf(
        tester,
        const Key('splash_letter_opacity_5'),
      );
      final taglineSettledOpacity = fadeOpacityOf(
        tester,
        const Key('splash_tagline_opacity'),
      );
      final letter0SettledTx = tester
          .widget<Transform>(find.byKey(const Key('splash_letter_transform_0')))
          .transform
          .getTranslation();

      expect(letter5SettledOpacity, closeTo(1.0, 0.01));
      expect(taglineSettledOpacity, closeTo(1.0, 0.01));
      expect(letter0SettledTx.x, closeTo(0.0, 0.01));
      expect(letter0SettledTx.y, closeTo(0.0, 0.01));

      // Finish timeline and crossfade to Home
      await tester.pumpAndSettle();
      expect(find.text('Home Target'), findsOneWidget);
    },
  );

  testWidgets('SplashScreen respects reduced-motion accessibility setting', (
    tester,
  ) async {
    final router = buildTestRouter();

    await tester.pumpWidget(
      buildTestSplash(router: router, disableAnimations: true),
    );

    await tester.pump();
    // Immediately settled in reduced-motion mode
    expect(fadeOpacityOf(tester, const Key('splash_letter_opacity_0')), 1.0);
    expect(fadeOpacityOf(tester, const Key('splash_tagline_opacity')), 1.0);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Home Target'), findsOneWidget);
  });

  testWidgets(
    'SplashScreen supports subsequent launches cleanly without stale state',
    (tester) async {
      // First launch
      final firstRouter = buildTestRouter();
      await tester.pumpWidget(buildTestSplash(router: firstRouter));
      await tester.pumpAndSettle();
      expect(find.text('Home Target'), findsOneWidget);

      // Unmount (app background/restart simulation)
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      // Subsequent launch
      final secondRouter = buildTestRouter();
      await tester.pumpWidget(buildTestSplash(router: secondRouter));
      await tester.pump();

      expect(fadeOpacityOf(tester, const Key('splash_letter_opacity_0')), 0.0);

      await tester.pumpAndSettle();
      expect(find.text('Home Target'), findsOneWidget);
    },
  );

  testWidgets(
    'SplashScreen respects SafeArea and avoids overflow across phone, landscape, and tablet displays',
    (tester) async {
      const viewports = [
        Size(320, 480), // Compact phone
        Size(360, 640), // Standard Android
        Size(412, 915), // Tall flagship
        Size(800, 400), // Landscape phone
        Size(800, 1200), // Tablet
      ];

      for (final viewport in viewports) {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;

        final router = buildTestRouter();
        await tester.pumpWidget(
          buildTestSplash(
            router: router,
            size: viewport,
            padding: const EdgeInsets.only(top: 44, bottom: 34),
            textScaler: const TextScaler.linear(1.35),
          ),
        );

        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.pump(const Duration(milliseconds: 800));
        expect(tester.takeException(), isNull);

        await tester.pump(const Duration(milliseconds: 900));
        expect(tester.takeException(), isNull);

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Home Target'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
