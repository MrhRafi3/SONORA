import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sonora/app/app_shell.dart';
import 'package:sonora/app/theme/app_theme.dart';
import 'package:sonora/features/equalizer/presentation/equalizer_providers.dart';
import 'package:sonora/features/home/presentation/home_screen.dart';
import 'package:sonora/features/player/data/fake_audio_player_facade.dart';
import 'package:sonora/features/player/data/sonora_audio_handler.dart';
import 'package:sonora/features/player/domain/ui_track.dart';
import 'package:sonora/features/player/presentation/player_state.dart';

void main() {
  const testTrackA = UiTrack(
    id: 'track-a',
    title: 'Track A',
    artist: 'Artist A',
    album: 'Album A',
    duration: Duration(minutes: 3),
    audioFormat: 'FLAC',
    sourceUri: 'content://media/external/audio/media/101',
  );

  const testTrackB = UiTrack(
    id: 'track-b',
    title: 'Track B',
    artist: 'Artist B',
    album: 'Album B',
    duration: Duration(minutes: 4),
    audioFormat: 'MP3',
    sourceUri: 'content://media/external/audio/media/102',
  );

  const testTrackC = UiTrack(
    id: 'track-c',
    title: 'Track C',
    artist: 'Artist C',
    album: 'Album C',
    duration: Duration(minutes: 5),
    audioFormat: 'WAV',
    sourceUri: 'content://media/external/audio/media/103',
  );

  group('Phase 02 Regression 1: Equalizer Preset Propagation & Bypass', () {
    test(
      'Selected EQ preset and bands propagate directly to AudioPlayerFacade',
      () async {
        final fakePlayer = FakeAudioPlayerFacade();
        final container = ProviderContainer(
          overrides: [audioPlayerFacadeProvider.overrideWithValue(fakePlayer)],
        );
        addTearDown(() {
          container.dispose();
          fakePlayer.dispose();
        });

        final eqNotifier = container.read(equalizerProvider.notifier);

        // Verify initial Flat preset propagation
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(fakePlayer.isEqualizerEnabled, isTrue);

        // Apply Rock preset (+4.5 dB bass, +3.5 dB treble)
        eqNotifier.applyPreset('Rock');
        expect(container.read(equalizerProvider).activePreset, equals('Rock'));
        expect(fakePlayer.lastEqualizerGains, isNotNull);
        expect(fakePlayer.lastEqualizerFrequencies, isNotNull);
        expect(fakePlayer.lastEqualizerFrequencies!.length, equals(10));
        // First band of Rock has positive boost
        expect(fakePlayer.lastEqualizerGains![0], greaterThan(0.0));

        // Adjust preamp gain
        eqNotifier.setPreampGain(3.0);
        expect(fakePlayer.lastPreampGain, equals(3.0));

        // Toggle bypass
        eqNotifier.toggleEnabled();
        expect(container.read(equalizerProvider).isEnabled, isFalse);
        expect(fakePlayer.isEqualizerEnabled, isFalse);

        // Re-enable
        eqNotifier.toggleEnabled();
        expect(container.read(equalizerProvider).isEnabled, isTrue);
        expect(fakePlayer.isEqualizerEnabled, isTrue);
      },
    );
  });

  group(
    'Phase 02 Regression 2: Next & Previous Track Single-Tap Reliability',
    () {
      late FakeAudioPlayerFacade fakePlayer;
      late ProviderContainer container;

      setUp(() {
        fakePlayer = FakeAudioPlayerFacade();
        container = ProviderContainer(
          overrides: [audioPlayerFacadeProvider.overrideWithValue(fakePlayer)],
        );
      });

      tearDown(() {
        container.dispose();
        fakePlayer.dispose();
      });

      test(
        'Single click on Next advances exactly one track without restart',
        () async {
          final notifier = container.read(playerProvider.notifier);
          await notifier.playTrack(
            testTrackA,
            queue: [testTrackA, testTrackB, testTrackC],
          );

          expect(container.read(playerProvider).track?.id, equals('track-a'));
          expect(container.read(playerProvider).queueIndex, equals(0));

          // Seek to 30 seconds into song
          await notifier.seekTo(const Duration(seconds: 30));
          expect(
            container.read(playerProvider).position,
            equals(const Duration(seconds: 30)),
          );

          // Exactly ONE tap on Next
          await notifier.nextTrack();

          final state = container.read(playerProvider);
          // Must advance to track B immediately, not restart track A
          expect(state.track?.id, equals('track-b'));
          expect(state.queueIndex, equals(1));
          expect(state.position, equals(Duration.zero));
        },
      );

      test(
        'Single click on Previous recedes exactly one track without 3-second restart',
        () async {
          final notifier = container.read(playerProvider.notifier);
          await notifier.playTrack(
            testTrackB,
            queue: [testTrackA, testTrackB, testTrackC],
          );

          expect(container.read(playerProvider).track?.id, equals('track-b'));
          expect(container.read(playerProvider).queueIndex, equals(1));

          // Simulate played for 45 seconds (well beyond 3 seconds)
          await notifier.seekTo(const Duration(seconds: 45));
          expect(
            container.read(playerProvider).position,
            equals(const Duration(seconds: 45)),
          );

          // Exactly ONE tap on Previous
          await notifier.previousTrack();

          final state = container.read(playerProvider);
          // Must recede to track A, NOT restart track B at 0:00
          expect(state.track?.id, equals('track-a'));
          expect(state.queueIndex, equals(0));
          expect(state.position, equals(Duration.zero));
        },
      );

      test(
        'Rapid consecutive Next and Previous taps update queue index safely',
        () async {
          final notifier = container.read(playerProvider.notifier);
          await notifier.playTrack(
            testTrackA,
            queue: [testTrackA, testTrackB, testTrackC],
          );

          // Rapid tap next twice
          final future1 = notifier.nextTrack();
          final future2 = notifier.nextTrack();
          await Future.wait([future1, future2]);

          final state = container.read(playerProvider);
          expect(state.track?.id, equals('track-c'));
          expect(state.queueIndex, equals(2));
        },
      );
    },
  );

  group('Phase 02 Regression 3: Lock-Screen Controls & SystemActions Sync', () {
    test(
      'SonoraAudioHandler systemActions includes skipToNext and skipToPrevious',
      () {
        final handler = SonoraAudioHandler();
        addTearDown(() => handler.disposeHandler());

        // Broadcast state
        handler.updateActiveTrack(testTrackA);
        handler.updateActiveQueue([testTrackA, testTrackB]);
        handler.updateQueueIndex(0);

        final state = handler.playbackState.value;
        expect(
          state.systemActions.contains(MediaAction.skipToNext),
          isTrue,
          reason:
              'Android MediaSessionCompat requires skipToNext in systemActions for lock screen controls',
        );
        expect(
          state.systemActions.contains(MediaAction.skipToPrevious),
          isTrue,
          reason:
              'Android MediaSessionCompat requires skipToPrevious in systemActions for lock screen controls',
        );

        // Verify active MediaItem metadata
        expect(handler.mediaItem.value, isNotNull);
        expect(handler.mediaItem.value!.id, equals('track-a'));
        expect(handler.mediaItem.value!.title, equals('Track A'));
        expect(handler.mediaItem.value!.artist, equals('Artist A'));
      },
    );

    test(
      'Remote skipToNext and skipToPrevious await async delegates cleanly',
      () async {
        final handler = SonoraAudioHandler();
        addTearDown(() => handler.disposeHandler());

        var nextCalled = false;
        var prevCalled = false;

        handler.onSkipToNext = () async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          nextCalled = true;
        };

        handler.onSkipToPrevious = () async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          prevCalled = true;
        };

        await handler.skipToNext();
        expect(nextCalled, isTrue);

        await handler.skipToPrevious();
        expect(prevCalled, isTrue);
      },
    );
  });

  group(
    'Phase 02 Regression 4: Android Back Navigation Hierarchy in AppShell',
    () {
      testWidgets(
        'Back from Settings returns to previous tab and only exits on Home root',
        (tester) async {
          final router = GoRouter(
            initialLocation: '/',
            routes: [
              StatefulShellRoute.indexedStack(
                builder: (context, state, navigationShell) {
                  return AppShell(navigationShell: navigationShell);
                },
                branches: [
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/',
                        builder: (context, state) =>
                            const Scaffold(body: Text('Home Screen Content')),
                      ),
                    ],
                  ),
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/library',
                        builder: (context, state) => const Scaffold(
                          body: Text('Library Screen Content'),
                        ),
                      ),
                    ],
                  ),
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/search',
                        builder: (context, state) =>
                            const Scaffold(body: Text('Search Screen Content')),
                      ),
                    ],
                  ),
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/settings',
                        builder: (context, state) => const Scaffold(
                          body: Text('Settings Screen Content'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp.router(
                routerConfig: router,
                theme: AppTheme.darkTheme,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 1. Initial on Home
          expect(find.text('Home Screen Content'), findsOneWidget);

          // 2. Navigate to Settings (index 3)
          await tester.tap(find.text('Settings'));
          await tester.pumpAndSettle();
          expect(find.text('Settings Screen Content'), findsOneWidget);

          // 3. Trigger Android system back
          final PopScope popScope = tester.widget(
            find.byKey(const Key('app_shell_pop_scope')),
          );
          expect(
            popScope.canPop,
            isFalse,
            reason: 'App must NOT exit when on Settings; canPop must be false',
          );

          // Invoke pop callback
          popScope.onPopInvokedWithResult!(false, null);
          await tester.pumpAndSettle();

          // 4. Back returned to Home
          expect(find.text('Home Screen Content'), findsOneWidget);

          // 5. On Home root, canPop is true allowing normal Android exit
          final PopScope homePopScope = tester.widget(
            find.byKey(const Key('app_shell_pop_scope')),
          );
          expect(
            homePopScope.canPop,
            isTrue,
            reason: 'On Home root, canPop must be true so Android can exit app',
          );

          // Clean unmount
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 100));
        },
      );
    },
  );

  group(
    'Phase 02 Regression 5: Fresh Launch Library Empty State (No Demo Song)',
    () {
      test('Fresh installation defaults to empty queue and empty state', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final playerState = container.read(playerProvider);
        expect(
          playerState.track,
          isNull,
          reason: 'No demo track should be loaded on fresh install',
        );
        expect(
          playerState.queue,
          isEmpty,
          reason: 'Queue must be empty on fresh install',
        );

        final emptyState = container.read(libraryEmptyStateProvider);
        expect(
          emptyState,
          isFalse,
          reason: 'Showcase demo tracks must NOT be enabled by default',
        );
      });

      testWidgets('Home screen renders genuine empty state on fresh launch', (
        tester,
      ) async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: HomeScreen())),
        );
        await tester.pumpAndSettle();

        // Renders genuine empty state
        expect(find.text('Your Music Library is Quiet'), findsOneWidget);
        // No demo song in UI
        expect(find.text('Clair de Lune (Audiophile Re-Master)'), findsNothing);

        // Clean unmount to drain Drift stream disposal timers
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
      });
    },
  );
}
