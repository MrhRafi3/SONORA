import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/features/player/data/fake_audio_player_facade.dart';
import 'package:sonora/features/player/domain/ui_track.dart';
import 'package:sonora/features/player/presentation/player_screen.dart';
import 'package:sonora/features/player/presentation/player_state.dart';
import 'package:sonora/shared/widgets/mini_player.dart';

void main() {
  const track1 = UiTrack(
    id: 't-1',
    title: 'Symphony No. 5',
    artist: 'Ludwig van Beethoven',
    album: 'Classic Masters',
    duration: Duration(minutes: 3, seconds: 20),
    audioFormat: 'FLAC',
    sourceUri: 'content://media/external/audio/media/101',
  );

  const track2 = UiTrack(
    id: 't-2',
    title: 'Moonlight Sonata',
    artist: 'Ludwig van Beethoven',
    album: 'Piano Sonatas',
    duration: Duration(minutes: 4, seconds: 15),
    audioFormat: 'MP3',
    filePath: '/storage/emulated/0/Music/moonlight.mp3',
  );

  const track3 = UiTrack(
    id: 't-3',
    title: 'Canon in D',
    artist: 'Johann Pachelbel',
    album: 'Baroque Essentials',
    duration: Duration(minutes: 5),
    audioFormat: 'WAV',
    filePath: '/storage/emulated/0/Music/canon.wav',
  );

  group('SONORA Playback Engine — Clean Architecture & Riverpod', () {
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

    test('1. Play, pause, and resume toggles playback state', () async {
      final notifier = container.read(playerProvider.notifier);

      await notifier.playTrack(track1, queue: [track1, track2]);

      var state = container.read(playerProvider);
      expect(state.isPlaying, isTrue);
      expect(state.track?.id, equals('t-1'));
      expect(fakePlayer.loadCount, equals(1));
      expect(
        fakePlayer.lastLoadedSource,
        equals('content://media/external/audio/media/101'),
      );
      expect(fakePlayer.lastLoadedIsUri, isTrue);
      expect(fakePlayer.playCount, equals(1));

      // Toggle pause
      await notifier.togglePlayPause();
      state = container.read(playerProvider);
      expect(state.isPlaying, isFalse);
      expect(fakePlayer.pauseCount, equals(1));

      // Toggle resume
      await notifier.togglePlayPause();
      state = container.read(playerProvider);
      expect(state.isPlaying, isTrue);
      expect(fakePlayer.playCount, equals(2));
    });

    test(
      '2. Seek by percentage and explicit duration updates position',
      () async {
        final notifier = container.read(playerProvider.notifier);
        await notifier.playTrack(track1, queue: [track1]);

        // Seek to 50% of 200 seconds (3m20s) = 100 seconds
        await notifier.seek(0.5);
        var state = container.read(playerProvider);
        expect(state.position, equals(const Duration(seconds: 100)));
        expect(state.formattedPosition, equals('1:40'));
        expect(fakePlayer.seekCount, equals(1));

        // Seek to specific target
        await notifier.seekTo(const Duration(seconds: 30));
        state = container.read(playerProvider);
        expect(state.position, equals(const Duration(seconds: 30)));
        expect(state.formattedPosition, equals('0:30'));
        expect(fakePlayer.seekCount, equals(2));
      },
    );

    test('3. Next and previous advances and recedes track in queue', () async {
      final notifier = container.read(playerProvider.notifier);
      await notifier.playTrack(track1, queue: [track1, track2, track3]);

      expect(container.read(playerProvider).queueIndex, equals(0));

      // Advance to next
      await notifier.nextTrack();
      var state = container.read(playerProvider);
      expect(state.track?.id, equals('t-2'));
      expect(state.queueIndex, equals(1));
      expect(
        fakePlayer.lastLoadedSource,
        equals('/storage/emulated/0/Music/moonlight.mp3'),
      );
      expect(fakePlayer.lastLoadedIsUri, isFalse);

      // Return to previous
      await notifier.previousTrack();
      state = container.read(playerProvider);
      expect(state.track?.id, equals('t-1'));
      expect(state.queueIndex, equals(0));
    });

    test(
      '4. Previous-track restart behavior (> 3 seconds) restarts current track',
      () async {
        final notifier = container.read(playerProvider.notifier);
        await notifier.playTrack(track2, queue: [track1, track2, track3]);

        expect(container.read(playerProvider).queueIndex, equals(1));

        // Seek past 3 seconds (e.g. 15 seconds into track)
        await notifier.seekTo(const Duration(seconds: 15));
        expect(
          container.read(playerProvider).position,
          equals(const Duration(seconds: 15)),
        );

        // Previous button when > 3s must restart the track at 0:00 without changing queue index
        await notifier.previousTrack();
        final state = container.read(playerProvider);
        expect(state.track?.id, equals('t-2'));
        expect(state.queueIndex, equals(1));
        expect(state.position, equals(Duration.zero));
      },
    );

    test('5. Queue insertion, removal, and playQueueIndex', () async {
      final notifier = container.read(playerProvider.notifier);
      notifier.setQueue([track1, track2]);

      expect(container.read(playerProvider).queue.length, equals(2));

      // Add track
      notifier.addToQueue(track3);
      expect(container.read(playerProvider).queue.length, equals(3));
      expect(container.read(playerProvider).queue.last.id, equals('t-3'));

      // Remove track at index 1 (track2)
      await notifier.removeFromQueue(1);
      final state = container.read(playerProvider);
      expect(state.queue.length, equals(2));
      expect(state.queue[0].id, equals('t-1'));
      expect(state.queue[1].id, equals('t-3'));

      // Direct index playback
      await notifier.playQueueIndex(1);
      expect(container.read(playerProvider).track?.id, equals('t-3'));
      expect(container.read(playerProvider).queueIndex, equals(1));
    });

    test('6. Automatic advance on track completion stream', () async {
      final notifier = container.read(playerProvider.notifier);
      await notifier.playTrack(track1, queue: [track1, track2]);

      expect(container.read(playerProvider).track?.id, equals('t-1'));

      // Trigger completion event from playback engine
      fakePlayer.simulateCompletion();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(playerProvider);
      expect(state.track?.id, equals('t-2'));
      expect(state.queueIndex, equals(1));
    });

    test(
      '7. Shuffle mode preserves original queue and restores on un-shuffle',
      () async {
        final notifier = container.read(playerProvider.notifier);
        final testQueue = [track1, track2, track3];
        await notifier.playTrack(track1, queue: testQueue);

        expect(container.read(playerProvider).isShuffle, isFalse);

        // Enable shuffle
        notifier.toggleShuffle();
        var state = container.read(playerProvider);
        expect(state.isShuffle, isTrue);
        expect(state.originalQueue, equals(testQueue));
        // Current track remains playing at top
        expect(state.track?.id, equals('t-1'));
        expect(state.queue.length, equals(3));

        // Disable shuffle
        notifier.toggleShuffle();
        state = container.read(playerProvider);
        expect(state.isShuffle, isFalse);
        expect(state.queue, equals(testQueue));
        expect(state.queueIndex, equals(0));
      },
    );

    test('8. Repeat-one mode loops current track on completion', () async {
      final notifier = container.read(playerProvider.notifier);
      await notifier.playTrack(track1, queue: [track1, track2]);

      // Cycle repeat: off -> all -> one
      notifier.toggleRepeat();
      expect(
        container.read(playerProvider).repeatMode,
        equals(PlaybackRepeatMode.all),
      );
      notifier.toggleRepeat();
      expect(
        container.read(playerProvider).repeatMode,
        equals(PlaybackRepeatMode.one),
      );

      // Trigger completion
      fakePlayer.simulateCompletion();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(playerProvider);
      expect(state.track?.id, equals('t-1'));
      expect(fakePlayer.playCount, greaterThanOrEqualTo(2));
    });

    test('9. Repeat-all mode loops from last track back to first', () async {
      final notifier = container.read(playerProvider.notifier);
      await notifier.playTrack(track2, queue: [track1, track2]);

      // Cycle to repeat all
      notifier.toggleRepeat();
      expect(
        container.read(playerProvider).repeatMode,
        equals(PlaybackRepeatMode.all),
      );

      // Advance at end of queue
      await notifier.nextTrack();
      final state = container.read(playerProvider);
      expect(state.track?.id, equals('t-1'));
      expect(state.queueIndex, equals(0));
    });

    test('10. Repeat-off stops playback at the end of queue', () async {
      final notifier = container.read(playerProvider.notifier);
      await notifier.playTrack(track2, queue: [track1, track2]);

      expect(
        container.read(playerProvider).repeatMode,
        equals(PlaybackRepeatMode.off),
      );

      // Track completion at the end of queue
      fakePlayer.simulateCompletion();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(playerProvider);
      expect(state.isPlaying, isFalse);
      expect(state.position, equals(Duration.zero));
    });

    test(
      '11. Invalid track source produces error state without crashing',
      () async {
        final notifier = container.read(playerProvider.notifier);
        fakePlayer.shouldFailLoad = true;

        await notifier.playTrack(track1, queue: [track1]);

        final state = container.read(playerProvider);
        expect(state.isPlaying, isFalse);
        expect(state.isLoading, isFalse);
        expect(state.playbackError, isNotNull);
        expect(state.playbackError, contains('Failed to load audio source'));
      },
    );

    test(
      '12. Reactive streams synchronize position, duration, and buffering',
      () async {
        // Initialize state
        container.read(playerProvider);

        fakePlayer.simulatePosition(const Duration(seconds: 45));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(
          container.read(playerProvider).position,
          equals(const Duration(seconds: 45)),
        );

        fakePlayer.simulateDuration(const Duration(minutes: 6));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(
          container.read(playerProvider).duration,
          equals(const Duration(minutes: 6)),
        );

        fakePlayer.simulateBuffering(true);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(container.read(playerProvider).isLoading, isTrue);

        fakePlayer.simulateBuffering(false);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(container.read(playerProvider).isLoading, isFalse);
      },
    );

    test(
      '13. Clear queue and dismiss player reset state and stop audio',
      () async {
        final notifier = container.read(playerProvider.notifier);
        await notifier.playTrack(track1, queue: [track1, track2]);

        await notifier.clearQueue();
        final state = container.read(playerProvider);
        expect(state.queue, isEmpty);
        expect(state.track, isNull);
        expect(state.isPlaying, isFalse);
        expect(fakePlayer.stopCount, equals(1));
      },
    );
  });

  group('SONORA Playback UI Widget Integration', () {
    testWidgets('14. PlayerScreen and MiniPlayer live interaction', (
      tester,
    ) async {
      final fake = FakeAudioPlayerFacade();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [audioPlayerFacadeProvider.overrideWithValue(fake)],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Expanded(child: PlayerScreen()),
                  MiniPlayer(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // MiniPlayer renders currently loaded track
      expect(find.byType(MiniPlayer), findsOneWidget);
      expect(
        find.text('Clair de Lune (Audiophile Re-Master)'),
        findsNWidgets(2),
      );

      // Tap Next button on PlayerScreen
      final nextButtonFinder = find.byTooltip('Next');
      expect(nextButtonFinder, findsNWidgets(2)); // One in player, one in mini
      await tester.tap(nextButtonFinder.first);
      await tester.pumpAndSettle();

      // Track advanced to Acoustic Resonance in D Minor
      expect(find.text('Acoustic Resonance in D Minor'), findsNWidgets(2));

      // Cleanup
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
