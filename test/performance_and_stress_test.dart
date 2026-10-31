import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audio_service/audio_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/database/app_database.dart';
import 'package:sonora/core/services/artwork_cache_service.dart';
import 'package:sonora/features/library/data/drift_library_repository.dart';
import 'package:sonora/features/player/data/fake_audio_player_facade.dart';
import 'package:sonora/features/player/data/sonora_audio_handler.dart';
import 'package:sonora/features/player/domain/ui_track.dart';
import 'package:sonora/features/player/presentation/player_state.dart';
import 'package:sonora/shared/widgets/sonora_artwork.dart';
import 'package:sonora_audio_engine/sonora_audio_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempTestDir;
  late ArtworkCacheService cacheService;

  setUpAll(() async {
    tempTestDir = await Directory.systemTemp.createTemp('sonora_perf_qa_test_');
    cacheService = ArtworkCacheService(customCacheDir: tempTestDir);
  });

  tearDownAll(() async {
    if (await tempTestDir.exists()) {
      await tempTestDir.delete(recursive: true);
    }
  });

  // =========================================================================
  // 1. DATABASE PERFORMANCE & LARGE LIBRARY BENCHMARK (5,000 TRACKS)
  // =========================================================================
  group('Phase 09: Database Indexing & Large Library Benchmarking', () {
    late AppDatabase database;
    late DriftLibraryRepository repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = DriftLibraryRepository(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      '1. Batch insert 5,000 tracks and benchmark query latencies with indexes',
      () async {
        final formats = ['FLAC', 'MP3', 'WAV', 'M4A', 'AAC', 'OGG', 'OPUS'];
        final artists = [
          'Ludwig van Beethoven',
          'Wolfgang Amadeus Mozart',
          'Johann Sebastian Bach',
          'Frédéric Chopin',
          'Claude Debussy',
          'Pyotr Ilyich Tchaikovsky',
          'Johannes Brahms',
          'Gustav Mahler',
        ];
        final albums = [
          'Symphonies Complete',
          'Piano Concertos',
          'Goldberg Variations',
          'Nocturnes',
          'Suite Bergamasque',
          'Violin Concertos',
          'Late Chamber Music',
          'Titan Studio Sessions',
        ];

        const totalTracks = 5000;
        final companions = <TracksCompanion>[];
        final baseDate = DateTime(2025, 1, 1);

        for (int i = 0; i < totalTracks; i++) {
          final artist = artists[i % artists.length];
          final album = albums[(i ~/ 5) % albums.length];
          final format = formats[i % formats.length];
          final durationMs = 120000 + (i * 37) % 360000;
          final dateAdded = baseDate.add(Duration(minutes: i * 15));
          final isHiRes = format == 'FLAC' || format == 'WAV';

          companions.add(
            TracksCompanion.insert(
              id: 'track_$i',
              sourceUri: 'content://media/external/audio/media/$i',
              filePath:
                  '/storage/emulated/0/Music/$artist/$album/track_$i.${format.toLowerCase()}',
              title: 'Movement ${i + 1} Allegro con brio',
              artist: artist,
              album: album,
              durationMs: durationMs,
              fileExtension: format.toLowerCase(),
              fileSizeBytes: 1024 * 1024 * (format == 'FLAC' ? 35 : 8),
              sampleRateHz: Value(isHiRes ? 96000 : 44100),
              bitDepth: Value(isHiRes ? 24 : 16),
              bitrateKbps: Value(isHiRes ? 2800 : 320),
              dateAdded: dateAdded,
              isFavorite: Value(i % 10 == 0), // 10% favorites
              isAvailable: const Value(true),
            ),
          );
        }

        // Benchmark Batch Insert
        final insertStopwatch = Stopwatch()..start();
        await database.batchInsertTracks(companions);
        insertStopwatch.stop();

        final count = (await database.getAllTracks()).length;
        expect(count, equals(totalTracks));

        // 1. Benchmark: Query all tracks (indexed isAvailable)
        final allTracksWatch = Stopwatch()..start();
        final allTracks = await repository.getTracks();
        allTracksWatch.stop();
        expect(allTracks.length, equals(totalTracks));
        expect(
          allTracksWatch.elapsedMilliseconds,
          lessThan(250),
          reason: 'Querying 5,000 tracks should complete quickly',
        );

        // 2. Benchmark: Watch sorted by Title
        final titleWatch = Stopwatch()..start();
        final titleSorted = await repository.watchTracks(sortBy: 'title').first;
        titleWatch.stop();
        expect(titleSorted.length, equals(totalTracks));
        expect(
          titleWatch.elapsedMilliseconds,
          lessThan(150),
          reason: 'Indexed title sort should execute rapidly',
        );

        // 3. Benchmark: Watch sorted by Artist
        final artistWatch = Stopwatch()..start();
        final artistSorted = await repository
            .watchTracks(sortBy: 'artist')
            .first;
        artistWatch.stop();
        expect(artistSorted.length, equals(totalTracks));
        expect(
          artistWatch.elapsedMilliseconds,
          lessThan(150),
          reason: 'Indexed artist sort should execute rapidly',
        );

        // 4. Benchmark: Watch sorted by Date Added (using idx_tracks_date_added)
        final dateWatch = Stopwatch()..start();
        final dateSorted = await repository
            .watchTracks(sortBy: 'dateAdded', ascending: false)
            .first;
        dateWatch.stop();
        expect(dateSorted.length, equals(totalTracks));
        expect(
          dateSorted.first.dateAdded.isAfter(dateSorted.last.dateAdded),
          isTrue,
        );
        expect(
          dateWatch.elapsedMilliseconds,
          lessThan(150),
          reason: 'Indexed dateAdded sort should execute rapidly',
        );

        // 5. Benchmark: Watch sorted by Duration (using idx_tracks_duration)
        final durationWatch = Stopwatch()..start();
        final durationSorted = await repository
            .watchTracks(sortBy: 'duration')
            .first;
        durationWatch.stop();
        expect(durationSorted.length, equals(totalTracks));
        expect(
          durationSorted.first.duration.inMilliseconds <=
              durationSorted.last.duration.inMilliseconds,
          isTrue,
        );
        expect(
          durationWatch.elapsedMilliseconds,
          lessThan(150),
          reason: 'Indexed duration sort should execute rapidly',
        );

        // 6. Benchmark: Search Query across 5,000 items
        final searchWatch = Stopwatch()..start();
        final searchResults = await repository.searchTracks('Beethoven');
        searchWatch.stop();
        expect(searchResults.isNotEmpty, isTrue);
        expect(
          searchWatch.elapsedMilliseconds,
          lessThan(100),
          reason: 'Searching 5,000 items should complete under 100ms',
        );

        // 7. Benchmark: Filter Favorites (using idx_tracks_favorite)
        final favWatch = Stopwatch()..start();
        final favorites = await repository.watchFavorites().first;
        favWatch.stop();
        expect(favorites.length, equals(totalTracks ~/ 10));
        expect(
          favWatch.elapsedMilliseconds,
          lessThan(80),
          reason: 'Indexed favorites query should execute under 80ms',
        );

        // 8. Benchmark: Recently Added stream (limit 20)
        final recentWatch = Stopwatch()..start();
        final recent = await repository
            .watchRecentlyAddedTracks(limit: 20)
            .first;
        recentWatch.stop();
        expect(recent.length, equals(20));
        expect(
          recentWatch.elapsedMilliseconds,
          lessThan(50),
          reason:
              'Indexed recently added limit query should execute under 50ms',
        );
      },
    );

    test('2. Playlist indexing and large playlist reordering benchmark', () async {
      // Create playlist
      final playlist = await repository.createPlaylist(
        'Large Audiophile Queue',
      );

      // Add 200 tracks to playlist
      for (int i = 0; i < 200; i++) {
        await database.insertTrack(
          TracksCompanion.insert(
            id: 'pl_track_$i',
            sourceUri: 'content://media/external/audio/media/pl_$i',
            filePath: '/storage/emulated/0/Music/track_$i.flac',
            title: 'Track $i',
            artist: 'Artist ${i % 10}',
            album: 'Album',
            durationMs: 180000,
            fileExtension: 'flac',
            fileSizeBytes: 20000000,
            dateAdded: DateTime.now(),
          ),
        );
        await repository.addTrackToPlaylist(playlist.id, 'pl_track_$i');
      }

      // Query playlist tracks (joins tracks and playlist_tracks with sortOrder)
      final fetchWatch = Stopwatch()..start();
      final plTracks = await repository.getTracksForPlaylist(playlist.id);
      fetchWatch.stop();
      expect(plTracks.length, equals(200));
      expect(fetchWatch.elapsedMilliseconds, lessThan(80));

      // Reorder: reverse the order of 200 tracks in a single atomic transaction
      final reversedIds = plTracks.map((t) => t.id).toList().reversed.toList();
      final reorderWatch = Stopwatch()..start();
      await repository.reorderPlaylistTracks(playlist.id, reversedIds);
      reorderWatch.stop();
      expect(
        reorderWatch.elapsedMilliseconds,
        lessThan(120),
        reason: 'Reordering 200 items in SQLite transaction should be fast',
      );

      final reorderedTracks = await repository.getTracksForPlaylist(
        playlist.id,
      );
      expect(reorderedTracks.first.id, equals('pl_track_199'));
      expect(reorderedTracks.last.id, equals('pl_track_0'));
    });
  });

  // =========================================================================
  // 2. ARTWORK CACHING, LRU RETENTION & DISK PRUNING
  // =========================================================================
  group('Phase 09: Artwork Caching, In-Memory Lookups & Disk Pruning', () {
    setUp(() async {
      await cacheService.clearCache();
    });

    tearDown(() async {
      await cacheService.clearCache();
    });

    test(
      '1. Saves artwork, retrieves from memory cache, and computes disk usage',
      () async {
        final sampleBytes = Uint8List.fromList(
          List.generate(1024, (i) => i % 256),
        );

        // Save artwork
        final path = await cacheService.saveArtworkBytes(
          'album_beethoven_5',
          sampleBytes,
        );
        expect(path, isNotNull);
        expect(File(path!).existsSync(), isTrue);

        // Verify fast in-memory cache hit
        final cachedPath = await cacheService.getCachedArtworkPath(
          'album_beethoven_5',
        );
        expect(cachedPath, equals(path));

        // Verify disk usage
        final usage = await cacheService.getDiskUsage();
        expect(usage, equals(1024));
      },
    );

    test(
      '2. Prunes oldest cached artwork files when exceeding maxBytes threshold',
      () async {
        // Write 5 files, each 2048 bytes (total 10240 bytes)
        final dummyBytes = Uint8List.fromList(
          List.generate(2048, (i) => i % 256),
        );
        final paths = <String>[];
        final baseTime = DateTime(2025, 1, 1, 12, 0);

        for (int i = 0; i < 5; i++) {
          final p = await cacheService.saveArtworkBytes('key_$i', dummyBytes);
          paths.add(p!);
          // Explicitly space lastModified timestamps by hours to guarantee deterministic LRU ordering
          await File(p).setLastModified(baseTime.add(Duration(hours: i)));
        }

        final initialUsage = await cacheService.getDiskUsage();
        expect(initialUsage, equals(5 * 2048));

        // Prune to max 4500 bytes (should keep exactly 2 newest files = 4096 bytes)
        await cacheService.pruneDiskCache(maxBytes: 4500);

        final prunedUsage = await cacheService.getDiskUsage();
        expect(prunedUsage, lessThanOrEqualTo(4500));

        // Oldest files (key_0, key_1, key_2) should be removed from disk
        expect(File(paths[0]).existsSync(), isFalse);
        expect(File(paths[1]).existsSync(), isFalse);
        expect(File(paths[2]).existsSync(), isFalse);
        // Newest files (key_3, key_4) should still exist
        expect(File(paths[3]).existsSync(), isTrue);
        expect(File(paths[4]).existsSync(), isTrue);
      },
    );

    test(
      '3. Handles null, empty bytes, and corrupted paths gracefully',
      () async {
        final nullResult = await cacheService.saveArtworkBytes(
          'null_key',
          null,
        );
        expect(nullResult, isNull);

        final emptyResult = await cacheService.saveArtworkBytes(
          'empty_key',
          Uint8List(0),
        );
        expect(emptyResult, isNull);

        final nonExistent = await cacheService.getCachedArtworkPath(
          'does_not_exist',
        );
        expect(nonExistent, isNull);
      },
    );

    testWidgets(
      '4. SonoraArtwork widget gracefully falls back to procedural vinyl on corrupted image path',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SonoraArtwork(
                size: 200,
                artworkPath: '/non/existent/corrupted_artwork.png',
                heroTag: 'test_hero',
              ),
            ),
          ),
        );

        await tester.pump();
        // Should render without throwing and display container
        expect(find.byType(SonoraArtwork), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // =========================================================================
  // 3. RAPID PLAYBACK ENGINE STRESS & CONCURRENCY
  // =========================================================================
  group('Phase 09: Rapid Playback Engine Stress & Concurrency', () {
    late FakeAudioPlayerFacade fakePlayer;
    late ProviderContainer container;

    final testTracks = List.generate(
      15,
      (i) => UiTrack(
        id: 'stress_track_$i',
        title: 'Stress Symphony No. $i',
        artist: 'Test Virtuoso',
        album: 'Stress Testing Studio Sessions',
        duration: Duration(minutes: 3 + (i % 4), seconds: i * 7 % 60),
        audioFormat: i % 2 == 0 ? 'FLAC' : 'MP3',
        sourceUri: 'content://media/external/audio/media/stress_$i',
      ),
    );

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
      '1. Concurrently spams rapid play/pause/seek/skip commands without race crashes',
      () async {
        final notifier = container.read(playerProvider.notifier);

        // Start initial playback
        await notifier.playTrack(testTracks[0], queue: testTracks);
        expect(fakePlayer.isPlaying, isTrue);

        // Rapidly fire 100 interleaved commands
        final random = math.Random(42);
        final futures = <Future<void>>[];

        for (int i = 0; i < 100; i++) {
          final action = i % 7;
          switch (action) {
            case 0:
              futures.add(notifier.togglePlayPause());
              break;
            case 1:
              futures.add(notifier.seek(random.nextDouble()));
              break;
            case 2:
              futures.add(notifier.nextTrack());
              break;
            case 3:
              futures.add(notifier.previousTrack());
              break;
            case 4:
              notifier.toggleShuffle();
              break;
            case 5:
              notifier.toggleRepeat();
              break;
            case 6:
              futures.add(
                notifier.playQueueIndex(random.nextInt(testTracks.length)),
              );
              break;
          }
        }

        // Await all queued async operations
        await Future.wait(futures);

        // Confirm player state remains valid and robust
        final finalState = container.read(playerProvider);
        expect(finalState.track, isNotNull);
        expect(finalState.queue.isNotEmpty, isTrue);
        expect(
          finalState.queueIndex,
          inInclusiveRange(0, finalState.queue.length - 1),
        );
        expect(finalState.position.inSeconds, greaterThanOrEqualTo(0));
      },
    );
  });

  // =========================================================================
  // 4. BACKGROUND AUDIO HANDLER & SYSTEM MEDIA INTERACTION RESILIENCE
  // =========================================================================
  group('Phase 09: Background Audio Handler & System Media Interaction', () {
    late SonoraAudioHandler handler;

    setUp(() {
      handler = SonoraAudioHandler();
    });

    test(
      '1. Converts UiTrack with extreme/missing values to MediaItem safely',
      () {
        final edgeTrack = UiTrack(
          id: 'edge_999',
          title: 'Very Long Title ' * 20, // 320 characters
          artist: 'Artist with Non-Latin Chars: ワーグナー & Чайковский & 베토벤 🎵',
          album: 'Album with Special Characters: "Special" / <Lossless> & 100%',
          duration: const Duration(hours: 2, minutes: 15),
          audioFormat: 'DSD256',
          sampleRate: '11.2 MHz',
          bitDepth: '1-bit',
          artworkPath: '/var/mobile/Containers/art.png',
          sourceUri: 'content://media/external/audio/media/999',
        );

        final mediaItem = handler.trackToMediaItem(edgeTrack);
        expect(mediaItem.id, equals('edge_999'));
        expect(mediaItem.title, contains('Very Long Title'));
        expect(mediaItem.artist, contains('ワーグナー'));
        expect(
          mediaItem.artUri,
          equals(Uri.file('/var/mobile/Containers/art.png')),
        );
        expect(mediaItem.extras?['audioFormat'], equals('DSD256'));
        expect(mediaItem.extras?['sampleRate'], equals('11.2 MHz'));
      },
    );

    test(
      '2. Broadcasts active track and queue updates to system streams safely',
      () {
        const trackA = UiTrack(
          id: 't-a',
          title: 'Track A',
          artist: 'Artist A',
          album: 'Album A',
          duration: Duration(minutes: 3),
          audioFormat: 'FLAC',
        );
        const trackB = UiTrack(
          id: 't-b',
          title: 'Track B',
          artist: 'Artist B',
          album: 'Album B',
          duration: Duration(minutes: 4),
          audioFormat: 'MP3',
        );

        handler.updateActiveTrack(trackA);
        expect(handler.mediaItem.value?.id, equals('t-a'));

        handler.updateActiveQueue([trackA, trackB]);
        expect(handler.queue.value.length, equals(2));
        expect(handler.queue.value[1].id, equals('t-b'));
      },
    );

    test(
      '3. Handles system remote callbacks without exceptions when unassigned',
      () async {
        // Calling system callbacks when onSkipToNext/etc are null should not throw
        handler.onSkipToNext = null;
        handler.onSkipToPrevious = null;
        handler.onSkipToQueueItem = null;
        handler.onSetRepeatMode = null;
        handler.onSetShuffleMode = null;

        await handler.skipToNext();
        await handler.skipToPrevious();
        await handler.skipToQueueItem(0);
        await handler.setRepeatMode(AudioServiceRepeatMode.all);
        await handler.setShuffleMode(AudioServiceShuffleMode.all);
      },
    );
  });

  // =========================================================================
  // 5. C++ AUDIO ENGINE FFI STRESS & MEMORY SAFETY
  // =========================================================================
  group('Phase 09: C++ Native Audio Engine FFI Stress & Leak Testing', () {
    test('1. Rapid allocate-and-dispose cycles of C++ engine instance', () {
      for (int i = 0; i < 25; i++) {
        final engine = SonoraAudioEngine.create(sampleRate: 48000, channels: 2);
        expect(engine.isDisposed, isFalse);
        engine.initStandardEq(numBands: 10);
        engine.dispose();
        expect(engine.isDisposed, isTrue);
      }
    });

    test(
      '2. Processes 100 consecutive 1024-frame stereo buffers under heavy EQ manipulation',
      () {
        final engine = SonoraAudioEngine.create(sampleRate: 48000, channels: 2);
        engine.initStandardEq(numBands: 10);
        engine.isEqEnabled = true;
        engine.isLimiterEnabled = true;

        const frames = 1024;
        final input = Float32List(frames * 2);
        final output = Float32List(frames * 2);

        // Fill with multi-frequency test wave
        for (int i = 0; i < frames; i++) {
          final val =
              0.4 * math.sin(2.0 * math.pi * 100.0 * i / 48000.0) +
              0.3 * math.sin(2.0 * math.pi * 1000.0 * i / 48000.0) +
              0.2 * math.sin(2.0 * math.pi * 10000.0 * i / 48000.0);
          input[i * 2] = val;
          input[i * 2 + 1] = val;
        }

        // Process 100 buffers while aggressively mutating EQ band gains and preamp
        for (int iter = 0; iter < 100; iter++) {
          final gainDb = ((iter % 25) - 12).toDouble(); // Sweeps -12 to +12 dB
          engine.setEqBandGain(iter % 10, gainDb);
          engine.preampGain = ((iter % 11) - 5)
              .toDouble(); // Sweeps -5 to +5 dB

          engine.processInterleaved(input, output);

          // Verify output samples are finite numbers (no NaN or Inf)
          for (int j = 0; j < output.length; j += 64) {
            expect(
              output[j].isFinite,
              isTrue,
              reason: 'Sample at $j must be finite',
            );
          }
        }

        engine.dispose();
      },
    );

    test('3. High-frequency FFT and waveform extraction under load', () {
      const fftSize = 1024;
      final samples = Float32List(fftSize);

      // Synthesize 1 kHz sine wave
      for (int i = 0; i < fftSize; i++) {
        samples[i] = math.sin(2.0 * math.pi * 1000.0 * i / 48000.0);
      }

      for (int iter = 0; iter < 50; iter++) {
        final magnitudes = SonoraAudioEngine.computeFft(
          samples,
          fftSize: fftSize,
        );
        expect(magnitudes.length, equals(fftSize ~/ 2));

        final bands = SonoraAudioEngine.computeSpectrumBands(
          magnitudes,
          sampleRate: 48000,
          numBands: 16,
        );
        expect(bands.length, equals(16));

        final waveform = SonoraAudioEngine.extractWaveform(
          samples,
          channels: 1,
          numPeaks: 32,
        );
        expect(waveform.length, equals(32));
      }
    });
  });

  // =========================================================================
  // 6. EXTREME DATA EDGE CASES & ERROR RESILIENCE
  // =========================================================================
  group('Phase 09: Extreme Data Edge Cases & Error Resilience', () {
    late AppDatabase database;
    late DriftLibraryRepository repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = DriftLibraryRepository(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      '1. Handles SQL injection attempts and wildcard characters in search query',
      () async {
        await database.insertTrack(
          TracksCompanion.insert(
            id: 'test_injection_1',
            sourceUri: 'content://media/1',
            filePath: '/storage/1.mp3',
            title: "Artist's Best Album; DROP TABLE tracks; --",
            artist: "O'Connor & Sons",
            album: "100% Guaranteed Hits",
            durationMs: 180000,
            fileExtension: 'mp3',
            fileSizeBytes: 5000000,
            dateAdded: DateTime.now(),
          ),
        );

        // Search with quotes, semicolons, and SQLite wildcards
        final res1 = await repository.searchTracks("O'Connor");
        expect(res1.length, equals(1));

        final res2 = await repository.searchTracks("DROP TABLE");
        expect(res2.length, equals(1));

        final res3 = await repository.searchTracks("%");
        expect(res3.length, equals(1));

        final res4 = await repository.searchTracks("");
        expect(res4.isEmpty, isTrue);

        final res5 = await repository.searchTracks("   ");
        expect(res5.isEmpty, isTrue);

        // Ensure tracks table still exists and is untouched
        final all = await repository.getTracks();
        expect(all.length, equals(1));
      },
    );

    test('2. Handles non-Latin and emoji metadata in tracks', () async {
      await database.insertTrack(
        TracksCompanion.insert(
          id: 'unicode_track',
          sourceUri: 'content://media/2',
          filePath: '/storage/ワーグナー/ニーベルングの指環/01_ラインの黄金.flac',
          title: 'ラインの黄金 前奏曲 (Vorspiel) 🎼 𝄢',
          artist: 'リヒャルト・ワーグナー (Richard Wagner)',
          album: 'ニーベルングの指環 (Der Ring des Nibelungen)',
          durationMs: 254000,
          fileExtension: 'flac',
          fileSizeBytes: 45000000,
          dateAdded: DateTime.now(),
        ),
      );

      final results = await repository.searchTracks('ワーグナー');
      expect(results.length, equals(1));
      expect(results.first.title, contains('ラインの黄金'));
      expect(results.first.artist, contains('Richard Wagner'));
    });

    test(
      '3. Zero duration and extreme duration tracks handled safely',
      () async {
        await database.insertTrack(
          TracksCompanion.insert(
            id: 'zero_duration',
            sourceUri: 'content://media/zero',
            filePath: '/storage/zero.mp3',
            title: 'Zero Length Track',
            artist: 'Unknown',
            album: 'Corrupted Files',
            durationMs: 0,
            fileExtension: 'mp3',
            fileSizeBytes: 100,
            dateAdded: DateTime.now(),
          ),
        );

        final track = await repository.getTrackById('zero_duration');
        expect(track, isNotNull);
        expect(track!.duration.inMilliseconds, equals(0));
        expect(track.formattedDuration, equals('0:00'));
      },
    );
  });
}
