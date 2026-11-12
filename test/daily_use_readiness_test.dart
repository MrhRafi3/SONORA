import 'package:audio_service/audio_service.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/app/theme/app_theme.dart';
import 'package:sonora/app/theme/theme_accent.dart';
import 'package:sonora/core/database/app_database.dart';
import 'package:sonora/core/services/app_preferences_service.dart';
import 'package:sonora/features/library/presentation/library_providers.dart';
import 'package:sonora/features/library/presentation/library_screen.dart';
import 'package:sonora/features/player/data/fake_audio_player_facade.dart';
import 'package:sonora/features/player/data/sonora_audio_handler.dart';
import 'package:sonora/features/player/domain/ui_track.dart';
import 'package:sonora/features/player/presentation/player_screen.dart';
import 'package:sonora/features/player/presentation/player_state.dart';
import 'package:sonora/features/player/presentation/widgets/audio_inspector_sheet.dart';

class _DelayedLoadFakeFacade extends FakeAudioPlayerFacade {
  final Map<String, Duration> loadDelays = {};
  final List<String> startedSources = [];
  final List<String?> playedSources = [];

  @override
  Future<void> load(String source, {bool isUri = false}) async {
    final delay = loadDelays[source] ?? Duration.zero;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    startedSources.add(source);
    await super.load(source, isUri: isUri);
  }

  @override
  Future<void> play() async {
    playedSources.add(lastLoadedSource);
    await super.play();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const localTrackA = UiTrack(
    id: 'local-a',
    title: 'Aurora Borealis',
    artist: 'Nordic Ensemble',
    album: 'Winter Sessions',
    duration: Duration(minutes: 4, seconds: 10),
    audioFormat: 'FLAC',
    sampleRate: '96 kHz',
    bitDepth: '24-bit',
    sourceUri: 'content://media/external/audio/media/501',
    filePath: '/storage/emulated/0/Music/aurora.flac',
  );

  const localTrackB = UiTrack(
    id: 'local-b',
    title: 'Solstice Dawn',
    artist: 'Nordic Ensemble',
    album: 'Winter Sessions',
    duration: Duration(minutes: 3, seconds: 45),
    audioFormat: 'M4A',
    sampleRate: '44.1 kHz',
    bitDepth: '256 kbps',
    sourceUri: 'content://media/external/audio/media/502',
    filePath: '/storage/emulated/0/Music/solstice.m4a',
  );

  const localTrackC = UiTrack(
    id: 'local-c',
    title: 'Nocturne Sketch',
    artist: 'Elena Solis',
    album: 'Night Piano',
    duration: Duration(minutes: 2, seconds: 55),
    audioFormat: 'MP3',
    sampleRate: '44.1 kHz',
    bitDepth: '320 kbps',
    sourceUri: 'content://media/external/audio/media/503',
    filePath: '/storage/emulated/0/Music/nocturne.mp3',
  );

  group('P0 Playback Race, Focus & Queue Regressions', () {
    test(
      'Rapid track switching cancels superseded slow load and plays latest track only',
      () async {
        final fake = _DelayedLoadFakeFacade()
          ..loadDelays['content://media/external/audio/media/501'] =
              const Duration(milliseconds: 80)
          ..loadDelays['content://media/external/audio/media/502'] =
              const Duration(milliseconds: 5);

        final container = ProviderContainer(
          overrides: [audioPlayerFacadeProvider.overrideWithValue(fake)],
        );
        addTearDown(() async {
          container.dispose();
          await fake.dispose();
        });

        final notifier = container.read(playerProvider.notifier);

        final slowFirst = notifier.playTrack(
          localTrackA,
          queue: [localTrackA, localTrackB],
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final fastSecond = notifier.playTrack(
          localTrackB,
          queue: [localTrackA, localTrackB],
        );

        await Future.wait([slowFirst, fastSecond]);

        final state = container.read(playerProvider);
        expect(state.track?.id, equals('local-b'));
        expect(state.queueIndex, equals(1));
        expect(state.isPlaying, isTrue);
        expect(fake.playCount, equals(1));
        expect(
          fake.playedSources,
          equals(['content://media/external/audio/media/502']),
        );
      },
    );

    test(
      'togglePlayPause loads unloaded initial track and playbackError clears cleanly',
      () async {
        final fake = FakeAudioPlayerFacade();
        final container = ProviderContainer(
          overrides: [audioPlayerFacadeProvider.overrideWithValue(fake)],
        );
        addTearDown(() async {
          container.dispose();
          await fake.dispose();
        });

        final notifier = container.read(playerProvider.notifier);
        notifier.syncRealLibrary([localTrackA, localTrackB]);

        var state = container.read(playerProvider);
        expect(state.track?.id, equals('local-a'));
        expect(fake.loadCount, equals(0));

        await notifier.togglePlayPause();
        state = container.read(playerProvider);
        expect(fake.loadCount, equals(1));
        expect(state.isPlaying, isTrue);

        // Simulate load failure on trackB
        fake.shouldFailLoad = true;
        await notifier.playTrack(localTrackB);
        state = container.read(playerProvider);
        expect(state.isLoading, isFalse);
        expect(state.isPlaying, isFalse);
        expect(state.playbackError, isNotNull);

        notifier.clearPlaybackError();
        expect(container.read(playerProvider).playbackError, isNull);
      },
    );

    test(
      'playNext inserts directly after active track and syncTrackFavorite updates active & queue',
      () async {
        final fake = FakeAudioPlayerFacade();
        final container = ProviderContainer(
          overrides: [audioPlayerFacadeProvider.overrideWithValue(fake)],
        );
        addTearDown(() async {
          container.dispose();
          await fake.dispose();
        });

        final notifier = container.read(playerProvider.notifier);
        await notifier.playTrack(
          localTrackA,
          queue: [localTrackA, localTrackB],
        );
        notifier.playNext(localTrackC);

        var state = container.read(playerProvider);
        expect(state.queue.map((t) => t.id).toList(), [
          'local-a',
          'local-c',
          'local-b',
        ]);

        notifier.syncTrackFavorite('local-a', true);
        state = container.read(playerProvider);
        expect(state.track?.isFavorite, isTrue);
        expect(state.queue.first.isFavorite, isTrue);
      },
    );

    test(
      'SonoraAudioHandler broadcasts queueIndex and synced repeat/shuffle modes',
      () {
        final handler = SonoraAudioHandler();
        handler.updateActiveQueue([localTrackA, localTrackB, localTrackC]);
        handler.updateQueueIndex(1);
        handler.syncModes(
          repeatMode: AudioServiceRepeatMode.one,
          shuffleMode: AudioServiceShuffleMode.all,
        );

        expect(handler.playbackState.value.queueIndex, equals(1));
        expect(
          handler.playbackState.value.repeatMode,
          equals(AudioServiceRepeatMode.one),
        );
        expect(
          handler.playbackState.value.shuffleMode,
          equals(AudioServiceShuffleMode.all),
        );

        handler.updateQueueIndex(99);
        expect(handler.playbackState.value.queueIndex, isNull);
      },
    );
  });

  group('P0 Non-Destructive Database Reconciliation & Search', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'reconcilePlatformTracks preserves favorites/dateAdded/artwork and marks missing unavailable',
      () async {
        final originalDate = DateTime(2025, 1, 15, 10, 30);

        final firstScan = await db.reconcilePlatformTracks(
          platformSource: 'android_mediastore',
          scannedEntries: [
            TracksCompanion.insert(
              id: 'ms-1',
              sourceUri: 'content://media/external/audio/media/1',
              filePath: '/storage/emulated/0/Music/one.flac',
              title: 'Track One',
              artist: 'Artist A',
              album: 'Album A',
              durationMs: 210000,
              fileExtension: 'flac',
              fileSizeBytes: 24000000,
              artworkPath: const Value('/cache/art/album_a.jpg'),
              platformSource: const Value('android_mediastore'),
              dateAdded: originalDate,
            ),
            TracksCompanion.insert(
              id: 'ms-2',
              sourceUri: 'content://media/external/audio/media/2',
              filePath: '/storage/emulated/0/Music/two.aac',
              title: 'Track Two',
              artist: 'Artist B',
              album: 'Album B',
              durationMs: 180000,
              fileExtension: 'aac',
              fileSizeBytes: 4200000,
              platformSource: const Value('android_mediastore'),
              dateAdded: originalDate,
            ),
          ],
        );

        expect(firstScan.newlyAddedCount, equals(2));
        await db.setFavorite('ms-1', true);

        // Rescan: ms-1 updated without artworkPath (preserved), ms-2 deleted from device
        final secondScan = await db.reconcilePlatformTracks(
          platformSource: 'android_mediastore',
          scannedEntries: [
            TracksCompanion.insert(
              id: 'ms-1',
              sourceUri: 'content://media/external/audio/media/1',
              filePath: '/storage/emulated/0/Music/one.flac',
              title: 'Track One (Remastered)',
              artist: 'Artist A',
              album: 'Album A',
              durationMs: 210000,
              fileExtension: 'flac',
              fileSizeBytes: 24000000,
              platformSource: const Value('android_mediastore'),
              dateAdded: DateTime(2026, 5, 1),
            ),
          ],
        );

        expect(secondScan.newlyAddedCount, equals(0));
        expect(secondScan.updatedCount, equals(1));
        expect(secondScan.markedUnavailableCount, equals(1));

        final preserved = await db.getTrackById('ms-1');
        expect(preserved, isNotNull);
        expect(preserved!.title, equals('Track One (Remastered)'));
        expect(preserved.isFavorite, isTrue);
        expect(preserved.artworkPath, equals('/cache/art/album_a.jpg'));
        expect(
          preserved.dateAdded.millisecondsSinceEpoch,
          equals(originalDate.millisecondsSinceEpoch),
        );

        final missing = await db.getTrackById('ms-2');
        expect(missing?.isAvailable, isFalse);

        // Search excludes unavailable ms-2 and matches ms-1 by fileExtension
        final aacResults = await db.searchTracks('aac');
        expect(aacResults, isEmpty);

        final flacResults = await db.searchTracks('flac');
        expect(flacResults.map((t) => t.id), equals(['ms-1']));
      },
    );
  });

  group('P1 UI Interactions, Inspector Honesty & Preferences Serialization', () {
    test(
      'AppPreferencesService parses and serializes ThemeMode and ThemeAccent',
      () {
        expect(AppPreferencesService.parseThemeMode('dark'), ThemeMode.dark);
        expect(AppPreferencesService.parseThemeMode('light'), ThemeMode.light);
        expect(
          AppPreferencesService.parseThemeMode('system'),
          ThemeMode.system,
        );
        expect(AppPreferencesService.parseThemeMode('unknown'), isNull);
        expect(
          AppPreferencesService.serializeThemeMode(ThemeMode.light),
          equals('light'),
        );
        expect(
          AppPreferencesService.parseAccent(ThemeAccent.roseCopper.id),
          equals(ThemeAccent.roseCopper),
        );
        expect(AppPreferencesService.parseAccent('invalid'), isNull);
      },
    );

    testWidgets(
      'AudioInspectorSheet displays honest runtime engine & storage path for local tracks',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: AudioInspectorSheet(track: localTrackA)),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Platform Audio Session (Native Decoder)'),
          findsOneWidget,
        );
        expect(
          find.text('/storage/emulated/0/Music/aurora.flac'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'LibraryScreen real Albums/Artists open collection sheet and Playlist delete requires confirmation',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final now = DateTime.now();
        await db.insertTrack(
          TracksCompanion.insert(
            id: 'ms-album-1',
            sourceUri: 'content://media/external/audio/media/701',
            filePath: '/storage/emulated/0/Music/track.flac',
            title: 'Glass Horizon',
            artist: 'Mira',
            album: 'Horizon LP',
            durationMs: 240000,
            fileExtension: 'flac',
            fileSizeBytes: 18000000,
            dateAdded: now,
          ),
        );
        await db.createPlaylist('pl-confirm', 'Roadtrip');

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

        // Tap Albums tab -> tap Horizon LP card
        await tester.tap(find.text('Albums'));
        await tester.pumpAndSettle();
        expect(find.text('Horizon LP'), findsOneWidget);
        await tester.tap(find.text('Horizon LP'));
        await tester.pumpAndSettle();
        expect(find.text('Play All'), findsOneWidget);
        expect(find.text('Glass Horizon'), findsWidgets);
        await tester.tap(find.byIcon(Icons.close_rounded).last);
        await tester.pumpAndSettle();

        // Tap Artists tab -> tap Mira row
        await tester.tap(find.text('Artists'));
        await tester.pumpAndSettle();
        expect(find.text('Mira'), findsOneWidget);
        await tester.tap(find.text('Mira'));
        await tester.pumpAndSettle();
        expect(find.text('Shuffle'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close_rounded).last);
        await tester.pumpAndSettle();

        // Tap Playlists tab -> scroll to Roadtrip -> tap Delete icon -> Cancel keeps -> Delete removes
        await tester.tap(find.text('Playlists'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Roadtrip'),
          150.0,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        expect(find.text('Roadtrip'), findsOneWidget);

        await tester.ensureVisible(find.byTooltip('Delete Playlist'));
        await tester.tap(find.byTooltip('Delete Playlist'));
        await tester.pumpAndSettle();
        expect(find.text('Delete Playlist'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Roadtrip'), findsOneWidget);

        await tester.tap(find.byTooltip('Delete Playlist'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(find.text('Roadtrip'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
        await db.close();
      },
    );

    testWidgets(
      'PlayerScreen Queue sheet supports per-item removal and Clear button',
      (tester) async {
        final fake = FakeAudioPlayerFacade();
        late WidgetRef capturedRef;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [audioPlayerFacadeProvider.overrideWithValue(fake)],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  return const PlayerScreen();
                },
              ),
            ),
          ),
        );
        await capturedRef
            .read(playerProvider.notifier)
            .playTrack(kShowcaseTracks.first, queue: kShowcaseTracks);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Queue'));
        await tester.pumpAndSettle();

        final expectedCount = kShowcaseTracks.length;
        expect(find.text('Up Next In Queue ($expectedCount)'), findsOneWidget);
        expect(find.byTooltip('Remove from queue'), findsWidgets);

        await tester.tap(find.byTooltip('Remove from queue').last);
        await tester.pumpAndSettle();
        expect(
          find.text('Up Next In Queue (${expectedCount - 1})'),
          findsOneWidget,
        );

        await tester.tap(find.text('Clear'));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
        await fake.dispose();
      },
    );
  });
}
