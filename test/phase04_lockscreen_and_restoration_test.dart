import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/services/app_preferences_service.dart';
import 'package:sonora/features/player/data/fake_audio_player_facade.dart';
import 'package:sonora/features/player/data/sonora_audio_handler.dart';
import 'package:sonora/features/player/domain/ui_track.dart';
import 'package:sonora/features/player/presentation/player_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const trackA = UiTrack(
    id: 'track-a',
    title: 'Clair de Lune',
    artist: 'Claude Debussy',
    album: 'Suite Bergamasque',
    duration: Duration(minutes: 5, seconds: 0),
    audioFormat: 'FLAC',
    sampleRate: '96 kHz',
    bitDepth: '24-bit',
    artworkPath: '/storage/emulated/0/Music/debussy.jpg',
    sourceUri: 'content://media/external/audio/media/1001',
    filePath: '/storage/emulated/0/Music/debussy.flac',
  );

  const trackB = UiTrack(
    id: 'track-b',
    title: 'Gymnopédie No. 1',
    artist: 'Erik Satie',
    album: 'Piano Works',
    duration: Duration(minutes: 3, seconds: 20),
    audioFormat: 'MP3',
    sampleRate: '44.1 kHz',
    bitDepth: '320 kbps',
    artworkPath: null,
    sourceUri: 'content://media/external/audio/media/1002',
    filePath: '/storage/emulated/0/Music/satie.mp3',
  );

  const trackC = UiTrack(
    id: 'track-c',
    title: 'Pavane pour une infante défunte',
    artist: 'Maurice Ravel',
    album: 'Ravel Orchestral Works',
    duration: Duration(minutes: 6, seconds: 15),
    audioFormat: 'WAV',
    sampleRate: '48 kHz',
    bitDepth: '24-bit',
    artworkPath: null,
    sourceUri: 'content://media/external/audio/media/1003',
    filePath: '/storage/emulated/0/Music/ravel.wav',
  );

  group('Phase 04 — Lock Screen Media Controls & MediaSession Actions', () {
    late SonoraAudioHandler handler;

    setUp(() {
      handler = SonoraAudioHandler();
    });

    test(
      '1. System actions include lock-screen playback & navigation actions',
      () {
        final state = handler.playbackState.value;
        final actions = state.systemActions;

        expect(actions.contains(MediaAction.play), isTrue);
        expect(actions.contains(MediaAction.pause), isTrue);
        expect(actions.contains(MediaAction.playPause), isTrue);
        expect(actions.contains(MediaAction.stop), isTrue);
        expect(actions.contains(MediaAction.skipToNext), isTrue);
        expect(actions.contains(MediaAction.skipToPrevious), isTrue);
        expect(actions.contains(MediaAction.seek), isTrue);
      },
    );

    test(
      '2. Controls list order is [Previous, Play/Pause, Next, Stop] with compact indices [0, 1, 2]',
      () {
        final state = handler.playbackState.value;

        expect(state.controls.length, equals(4));
        expect(state.controls[0], equals(MediaControl.skipToPrevious));
        // When stopped/paused initially, middle control is Play
        expect(state.controls[1], equals(MediaControl.play));
        expect(state.controls[2], equals(MediaControl.skipToNext));
        expect(state.controls[3], equals(MediaControl.stop));
        expect(state.androidCompactActionIndices, equals(const [0, 1, 2]));
      },
    );

    test(
      '3. Controls switch to Pause when playing and toggle back to Play when paused',
      () {
        // Simulate player state active
        handler.updateActiveTrack(trackA);
        var state = handler.playbackState.value;
        expect(state.controls[1], equals(MediaControl.play));

        // Simulate playing event via load/play
        handler.playbackState.add(
          state.copyWith(
            playing: true,
            controls: [
              MediaControl.skipToPrevious,
              MediaControl.pause,
              MediaControl.skipToNext,
              MediaControl.stop,
            ],
          ),
        );
        state = handler.playbackState.value;
        expect(state.playing, isTrue);
        expect(state.controls[1], equals(MediaControl.pause));

        // Simulate pause
        handler.playbackState.add(
          state.copyWith(
            playing: false,
            controls: [
              MediaControl.skipToPrevious,
              MediaControl.play,
              MediaControl.skipToNext,
              MediaControl.stop,
            ],
          ),
        );
        state = handler.playbackState.value;
        expect(state.playing, isFalse);
        expect(state.controls[1], equals(MediaControl.play));
      },
    );

    test(
      '4. trackToMediaItem publishes title, artist, album, duration, and artUri',
      () {
        final itemWithArt = handler.trackToMediaItem(trackA);
        expect(itemWithArt.id, equals('track-a'));
        expect(itemWithArt.title, equals('Clair de Lune'));
        expect(itemWithArt.artist, equals('Claude Debussy'));
        expect(itemWithArt.album, equals('Suite Bergamasque'));
        expect(itemWithArt.duration, equals(const Duration(minutes: 5)));
        expect(itemWithArt.artUri, equals(Uri.file(trackA.artworkPath!)));

        final itemNoArt = handler.trackToMediaItem(trackB);
        expect(itemNoArt.id, equals('track-b'));
        expect(itemNoArt.title, equals('Gymnopédie No. 1'));
        expect(itemNoArt.artist, equals('Erik Satie'));
        expect(itemNoArt.album, equals('Piano Works'));
        expect(
          itemNoArt.duration,
          equals(const Duration(minutes: 3, seconds: 20)),
        );
        expect(itemNoArt.artUri, isNull);
      },
    );

    test(
      '5. seek broadcasts updated position to MediaSession immediately',
      () async {
        await handler.seek(const Duration(seconds: 42));
        final state = handler.playbackState.value;
        expect(state.updatePosition, equals(const Duration(seconds: 42)));
      },
    );
  });

  group('Phase 04 — Playback State & Position Restoration After App Restart', () {
    setUp(() {
      AppPreferencesService.setTestPreferences({});
    });

    tearDown(() {
      AppPreferencesService.resetForTesting();
    });

    test(
      '1. AppPreferencesService persists and retrieves playback session',
      () async {
        const prefs = AppPreferencesService();

        await prefs.savePlaybackSession(
          trackId: 'track-b',
          positionMs: 65432,
          queueIds: ['track-a', 'track-b', 'track-c'],
          queueIndex: 1,
        );

        final cached = prefs.getCachedPlaybackSession();
        expect(cached.trackId, equals('track-b'));
        expect(cached.positionMs, equals(65432));
        expect(cached.queueIds, equals(['track-a', 'track-b', 'track-c']));
        expect(cached.queueIndex, equals(1));

        final loaded = await prefs.loadPlaybackSession();
        expect(loaded.trackId, equals('track-b'));
        expect(loaded.positionMs, equals(65432));
        expect(loaded.queueIds, equals(['track-a', 'track-b', 'track-c']));
        expect(loaded.queueIndex, equals(1));
      },
    );

    test(
      '2. syncRealLibrary restores saved track, queue, and seek position in paused state',
      () async {
        const prefs = AppPreferencesService();
        await prefs.savePlaybackSession(
          trackId: 'track-b',
          positionMs: 80000,
          queueIds: ['track-a', 'track-b', 'track-c'],
          queueIndex: 1,
        );

        final fake = FakeAudioPlayerFacade();
        final handler = SonoraAudioHandler();
        final container = ProviderContainer(
          overrides: [
            audioPlayerFacadeProvider.overrideWithValue(fake),
            audioHandlerProvider.overrideWithValue(handler),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await fake.dispose();
        });

        final notifier = container.read(playerProvider.notifier);
        notifier.syncRealLibrary([trackA, trackB, trackC]);

        final state = container.read(playerProvider);
        expect(state.track?.id, equals('track-b'));
        expect(state.track?.title, equals('Gymnopédie No. 1'));
        expect(
          state.queue.map((t) => t.id).toList(),
          equals(['track-a', 'track-b', 'track-c']),
        );
        expect(state.queueIndex, equals(1));
        expect(state.position, equals(const Duration(milliseconds: 80000)));

        // CRITICAL: Restored session MUST be paused, never autoplay
        expect(state.isPlaying, isFalse);
        expect(fake.playCount, equals(0));
      },
    );

    test(
      '3. syncRealLibrary clamps saved position if it exceeds track duration',
      () async {
        const prefs = AppPreferencesService();
        // Track B is 3m 20s = 200,000ms. Save invalid position 999,999ms
        await prefs.savePlaybackSession(
          trackId: 'track-b',
          positionMs: 999999,
          queueIds: ['track-b'],
          queueIndex: 0,
        );

        final fake = FakeAudioPlayerFacade();
        final container = ProviderContainer(
          overrides: [audioPlayerFacadeProvider.overrideWithValue(fake)],
        );
        addTearDown(() async {
          container.dispose();
          await fake.dispose();
        });

        final notifier = container.read(playerProvider.notifier);
        notifier.syncRealLibrary([trackA, trackB]);

        final state = container.read(playerProvider);
        expect(state.track?.id, equals('track-b'));
        expect(state.position, equals(trackB.duration));
        expect(state.isPlaying, isFalse);
      },
    );

    test(
      '4. syncRealLibrary gracefully falls back to first track if saved track was deleted',
      () async {
        const prefs = AppPreferencesService();
        await prefs.savePlaybackSession(
          trackId: 'deleted-track-999',
          positionMs: 30000,
          queueIds: ['deleted-track-999'],
          queueIndex: 0,
        );

        final fake = FakeAudioPlayerFacade();
        final container = ProviderContainer(
          overrides: [audioPlayerFacadeProvider.overrideWithValue(fake)],
        );
        addTearDown(() async {
          container.dispose();
          await fake.dispose();
        });

        final notifier = container.read(playerProvider.notifier);
        notifier.syncRealLibrary([trackA, trackB]);

        final state = container.read(playerProvider);
        // Gracefully falls back to first available track in real library
        expect(state.track?.id, equals('track-a'));
        expect(state.position, equals(Duration.zero));
        expect(state.isPlaying, isFalse);
      },
    );

    test(
      '5. syncRealLibrary filters out deleted tracks from saved queue gracefully',
      () async {
        const prefs = AppPreferencesService();
        await prefs.savePlaybackSession(
          trackId: 'track-c',
          positionMs: 15000,
          queueIds: ['deleted-1', 'track-a', 'deleted-2', 'track-c'],
          queueIndex: 3,
        );

        final fake = FakeAudioPlayerFacade();
        final container = ProviderContainer(
          overrides: [audioPlayerFacadeProvider.overrideWithValue(fake)],
        );
        addTearDown(() async {
          container.dispose();
          await fake.dispose();
        });

        final notifier = container.read(playerProvider.notifier);
        notifier.syncRealLibrary([trackA, trackB, trackC]);

        final state = container.read(playerProvider);
        expect(state.track?.id, equals('track-c'));
        // Queue only contains valid remaining library tracks
        expect(
          state.queue.map((t) => t.id).toList(),
          equals(['track-a', 'track-c']),
        );
        expect(state.queueIndex, equals(1));
        expect(state.position, equals(const Duration(milliseconds: 15000)));
        expect(state.isPlaying, isFalse);
      },
    );

    test(
      '6. dismissPlayer and clearQueue clear saved playback session',
      () async {
        const prefs = AppPreferencesService();
        await prefs.savePlaybackSession(
          trackId: 'track-a',
          positionMs: 25000,
          queueIds: ['track-a'],
          queueIndex: 0,
        );

        final fake = FakeAudioPlayerFacade();
        final container = ProviderContainer(
          overrides: [audioPlayerFacadeProvider.overrideWithValue(fake)],
        );
        addTearDown(() async {
          container.dispose();
          await fake.dispose();
        });

        final notifier = container.read(playerProvider.notifier);
        notifier.syncRealLibrary([trackA]);

        // Call dismissPlayer
        await notifier.dismissPlayer();

        final sessionAfterDismiss = prefs.getCachedPlaybackSession();
        expect(sessionAfterDismiss.trackId, isNull);
        expect(sessionAfterDismiss.positionMs, equals(0));
      },
    );

    test(
      '7. saveCurrentSession saves active track, position, and queue state',
      () async {
        const prefs = AppPreferencesService();
        final fake = FakeAudioPlayerFacade();
        final container = ProviderContainer(
          overrides: [audioPlayerFacadeProvider.overrideWithValue(fake)],
        );
        addTearDown(() async {
          container.dispose();
          await fake.dispose();
        });

        final notifier = container.read(playerProvider.notifier);
        await notifier.playTrack(trackA, queue: [trackA, trackB, trackC]);
        await notifier.seekTo(const Duration(seconds: 45));

        final cached = prefs.getCachedPlaybackSession();
        expect(cached.trackId, equals('track-a'));
        expect(cached.positionMs, equals(45000));
        expect(cached.queueIds, equals(['track-a', 'track-b', 'track-c']));
        expect(cached.queueIndex, equals(0));
      },
    );
  });
}
