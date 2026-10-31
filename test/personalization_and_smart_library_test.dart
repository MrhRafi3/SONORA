import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/app/theme/app_theme.dart';
import 'package:sonora/app/theme/theme_accent.dart';
import 'package:sonora/core/database/app_database.dart';
import 'package:sonora/features/home/presentation/home_screen.dart';
import 'package:sonora/features/library/data/drift_library_repository.dart';
import 'package:sonora/features/library/domain/entities.dart';
import 'package:sonora/features/library/domain/smart_playlist.dart';
import 'package:sonora/features/library/presentation/library_providers.dart';
import 'package:sonora/features/library/presentation/library_screen.dart';
import 'package:sonora/features/player/data/fake_audio_player_facade.dart';
import 'package:sonora/features/player/presentation/player_state.dart';
import 'package:sonora/features/playlists/presentation/playlist_detail_screen.dart';
import 'package:sonora/features/settings/presentation/settings_screen.dart';

void main() {
  group('Phase 08: Theme Accents & Personalization', () {
    test(
      'ThemeAccentProvider defaults to amberWarmth and switches accents',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(themeAccentProvider), ThemeAccent.amberWarmth);

        container
            .read(themeAccentProvider.notifier)
            .setAccent(ThemeAccent.emeraldVelvet);
        expect(container.read(themeAccentProvider), ThemeAccent.emeraldVelvet);

        container
            .read(themeAccentProvider.notifier)
            .setAccent(ThemeAccent.sapphireTube);
        expect(container.read(themeAccentProvider), ThemeAccent.sapphireTube);
      },
    );

    test('AppTheme.buildDarkTheme adapts to custom ThemeAccent', () {
      final darkEmerald = AppTheme.buildDarkTheme(
        accent: ThemeAccent.emeraldVelvet,
      );
      expect(
        darkEmerald.colorScheme.primary,
        ThemeAccent.emeraldVelvet.accentColor,
      );

      final ext = darkEmerald.extension<SonoraThemeExtension>();
      expect(ext, isNotNull);
      expect(ext!.accentGlow, ThemeAccent.emeraldVelvet.accentGlow);
      expect(ext.accentGold, ThemeAccent.emeraldVelvet.accentGold);
    });

    test('AppTheme.buildLightTheme adapts to custom ThemeAccent', () {
      final lightCopper = AppTheme.buildLightTheme(
        accent: ThemeAccent.roseCopper,
      );
      expect(
        lightCopper.colorScheme.primary,
        ThemeAccent.roseCopper.accentColor,
      );

      final ext = lightCopper.extension<SonoraThemeExtension>();
      expect(ext, isNotNull);
      expect(ext!.accentGlow, ThemeAccent.roseCopper.accentGlow);
    });
  });

  group('Phase 08: Smart Playlists & Filtering Domain Logic', () {
    final now = DateTime.now();

    final testTracks = [
      AudioTrack(
        id: 'track_1',
        sourceUri: 'file:///track1.flac',
        filePath: '/storage/track1.flac',
        title: 'Hi-Res Master Symphony',
        artist: 'Orchestra',
        album: 'Audiophile Collection',
        duration: const Duration(minutes: 5),
        fileExtension: 'flac',
        fileSizeBytes: 45000000,
        sampleRateHz: 96000,
        bitDepth: 24,
        dateAdded: now.subtract(const Duration(days: 3)),
        isFavorite: true,
      ),
      AudioTrack(
        id: 'track_2',
        sourceUri: 'file:///track2.mp3',
        filePath: '/storage/track2.mp3',
        title: 'Standard Acoustic Song',
        artist: 'Singer',
        album: 'Acoustic Sessions',
        duration: const Duration(minutes: 3),
        fileExtension: 'mp3',
        fileSizeBytes: 7000000,
        sampleRateHz: 44100,
        bitDepth: 16,
        dateAdded: now.subtract(const Duration(days: 1)),
        isFavorite: false,
      ),
      AudioTrack(
        id: 'track_3',
        sourceUri: 'file:///track3.wav',
        filePath: '/storage/track3.wav',
        title: 'Studio Pure Direct',
        artist: 'Jazz Trio',
        album: 'Blue Notes',
        duration: const Duration(minutes: 4),
        fileExtension: 'wav',
        fileSizeBytes: 50000000,
        sampleRateHz: 192000,
        bitDepth: 24,
        dateAdded: now,
        isFavorite: true,
      ),
    ];

    test('Favorites filter isolates starred tracks', () {
      final favorites = SmartPlaylistType.favorites.filter(testTracks);
      expect(favorites.length, 2);
      expect(favorites.map((t) => t.id), containsAll(['track_1', 'track_3']));
    });

    test(
      'Hi-Res Studio Masters isolates 24-bit / 96kHz+ / FLAC / WAV tracks',
      () {
        final hiRes = SmartPlaylistType.hiResMasters.filter(testTracks);
        expect(hiRes.length, 2);
        expect(hiRes.map((t) => t.id), containsAll(['track_1', 'track_3']));
      },
    );

    test('Lossless Vault filters FLAC and WAV audio', () {
      final lossless = SmartPlaylistType.losslessVault.filter(testTracks);
      expect(lossless.length, 2);
      expect(lossless.map((t) => t.id), containsAll(['track_1', 'track_3']));
    });

    test('Recently Added sorts tracks chronologically descending', () {
      final recents = SmartPlaylistType.recentlyAdded.filter(testTracks);
      expect(recents.first.id, 'track_3');
      expect(recents[1].id, 'track_2');
      expect(recents.last.id, 'track_1');
    });

    test('LibraryAudioFilter matches correct audio format profiles', () {
      expect(LibraryAudioFilter.all.matches(testTracks[0]), isTrue);
      expect(LibraryAudioFilter.all.matches(testTracks[1]), isTrue);

      expect(LibraryAudioFilter.hiRes.matches(testTracks[0]), isTrue);
      expect(LibraryAudioFilter.hiRes.matches(testTracks[1]), isFalse);

      expect(LibraryAudioFilter.lossless.matches(testTracks[0]), isTrue);
      expect(LibraryAudioFilter.lossless.matches(testTracks[1]), isFalse);
      expect(LibraryAudioFilter.lossless.matches(testTracks[2]), isTrue);

      expect(LibraryAudioFilter.standard.matches(testTracks[1]), isTrue);
      expect(LibraryAudioFilter.standard.matches(testTracks[0]), isFalse);
    });
  });

  group('Phase 08: Database Playlist CRUD & Reordering Integration', () {
    late AppDatabase db;
    late DriftLibraryRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = DriftLibraryRepository(database: db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'Create, populate, reorder, and remove tracks in custom playlist',
      () async {
        final now = DateTime.now();

        // Seed 3 tracks
        await repo.database.batchInsertTracks([
          TracksCompanion.insert(
            id: 'song_a',
            sourceUri: 'file:///song_a.flac',
            filePath: '/storage/song_a.flac',
            title: 'Song Alpha',
            artist: 'Artist A',
            album: 'Album 1',
            durationMs: 180000,
            fileExtension: 'flac',
            fileSizeBytes: 20000000,
            dateAdded: now,
          ),
          TracksCompanion.insert(
            id: 'song_b',
            sourceUri: 'file:///song_b.flac',
            filePath: '/storage/song_b.flac',
            title: 'Song Beta',
            artist: 'Artist B',
            album: 'Album 2',
            durationMs: 200000,
            fileExtension: 'flac',
            fileSizeBytes: 22000000,
            dateAdded: now,
          ),
          TracksCompanion.insert(
            id: 'song_c',
            sourceUri: 'file:///song_c.flac',
            filePath: '/storage/song_c.flac',
            title: 'Song Gamma',
            artist: 'Artist C',
            album: 'Album 3',
            durationMs: 240000,
            fileExtension: 'flac',
            fileSizeBytes: 25000000,
            dateAdded: now,
          ),
        ]);

        // 1. Create playlist
        final playlist = await repo.createPlaylist('Late Night Listening');
        expect(playlist.name, 'Late Night Listening');

        // 2. Add tracks in initial order (Alpha, Beta, Gamma)
        await repo.addTrackToPlaylist(playlist.id, 'song_a');
        await repo.addTrackToPlaylist(playlist.id, 'song_b');
        await repo.addTrackToPlaylist(playlist.id, 'song_c');

        var playlistTracks = await repo.getTracksForPlaylist(playlist.id);
        expect(playlistTracks.length, 3);
        expect(playlistTracks.map((t) => t.id).toList(), [
          'song_a',
          'song_b',
          'song_c',
        ]);

        // 3. Reorder tracks to Gamma, Alpha, Beta
        await repo.reorderPlaylistTracks(playlist.id, [
          'song_c',
          'song_a',
          'song_b',
        ]);

        playlistTracks = await repo.getTracksForPlaylist(playlist.id);
        expect(playlistTracks.map((t) => t.id).toList(), [
          'song_c',
          'song_a',
          'song_b',
        ]);

        // 4. Remove Song Alpha
        await repo.removeTrackFromPlaylist(playlist.id, 'song_a');
        playlistTracks = await repo.getTracksForPlaylist(playlist.id);
        expect(playlistTracks.length, 2);
        expect(playlistTracks.map((t) => t.id).toList(), ['song_c', 'song_b']);

        // 5. Rename playlist
        await repo.renamePlaylist(playlist.id, 'Midnight Audiophile Session');
        final allPlaylists = await repo.database.watchAllPlaylists().first;
        expect(allPlaylists.first.name, 'Midnight Audiophile Session');

        // 6. Delete playlist
        await repo.deletePlaylist(playlist.id);
        final remainingPlaylists = await repo.database
            .watchAllPlaylists()
            .first;
        expect(remainingPlaylists, isEmpty);
      },
    );
  });

  group('Phase 08: Widget & UI Personalization Verification', () {
    testWidgets(
      'SettingsScreen allows tapping and selecting audiophile accent color',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Audiophile Accent'), findsOneWidget);
        expect(find.text('Amber Warmth'), findsOneWidget);

        // Verify all 5 accents are rendered
        for (final accent in ThemeAccent.values) {
          expect(find.byTooltip(accent.name), findsOneWidget);
        }

        // Tap Emerald Velvet
        await tester.tap(find.byTooltip('Emerald Velvet'));
        await tester.pumpAndSettle();

        expect(container.read(themeAccentProvider), ThemeAccent.emeraldVelvet);
        expect(find.text('Emerald Velvet'), findsOneWidget);
      },
    );

    testWidgets(
      'LibraryScreen Playlists tab renders Smart Collections and Custom Playlists',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final db = AppDatabase(NativeDatabase.memory());
        final fake = FakeAudioPlayerFacade();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              audioPlayerFacadeProvider.overrideWithValue(fake),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const LibraryScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Navigate to Playlists tab
        await tester.tap(find.text('Playlists'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Create New Playlist'), findsOneWidget);
        expect(find.text('Smart Collections'), findsOneWidget);
        expect(find.text('Favorites'), findsOneWidget);
        expect(find.text('Hi-Res Studio Masters'), findsOneWidget);
        expect(find.text('Recently Added'), findsOneWidget);
        expect(find.text('Lossless Vault'), findsOneWidget);
        expect(find.text('Custom Playlists'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
        await db.close();
      },
    );

    testWidgets(
      'PlaylistDetailScreen renders custom playlist with controls and drag handles',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final db = AppDatabase(NativeDatabase.memory());
        final repo = DriftLibraryRepository(database: db);
        final fake = FakeAudioPlayerFacade();
        final now = DateTime.now();

        await repo.database.batchInsertTracks([
          TracksCompanion.insert(
            id: 't1',
            sourceUri: 'file:///t1.flac',
            filePath: '/storage/t1.flac',
            title: 'Track One',
            artist: 'Artist One',
            album: 'Album One',
            durationMs: 180000,
            fileExtension: 'flac',
            fileSizeBytes: 20000000,
            dateAdded: now,
          ),
          TracksCompanion.insert(
            id: 't2',
            sourceUri: 'file:///t2.flac',
            filePath: '/storage/t2.flac',
            title: 'Track Two',
            artist: 'Artist Two',
            album: 'Album Two',
            durationMs: 210000,
            fileExtension: 'flac',
            fileSizeBytes: 24000000,
            dateAdded: now,
          ),
        ]);

        final p = await repo.createPlaylist('Acoustic Masterworks');
        await repo.addTrackToPlaylist(p.id, 't1');
        await repo.addTrackToPlaylist(p.id, 't2');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              musicLibraryRepositoryProvider.overrideWithValue(repo),
              audioPlayerFacadeProvider.overrideWithValue(fake),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: PlaylistDetailScreen(
                playlistId: p.id,
                initialTitle: 'Acoustic Masterworks',
                isSmart: false,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Acoustic Masterworks'), findsWidgets);
        expect(find.text('Play All'), findsOneWidget);
        expect(find.text('Shuffle'), findsOneWidget);
        expect(find.text('Track One'), findsOneWidget);
        expect(find.text('Track Two'), findsOneWidget);
        expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(2));

        // Clean unmount to drain Drift stream timers
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
        await db.close();
      },
    );

    testWidgets(
      'LibraryScreen Songs tab displays format filter chips and updates active filter',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final db = AppDatabase(NativeDatabase.memory());
        final repo = DriftLibraryRepository(database: db);
        final fake = FakeAudioPlayerFacade();

        // Seed a Hi-Res track and a standard MP3
        await repo.database.batchInsertTracks([
          TracksCompanion.insert(
            id: 's1',
            sourceUri: 'file:///s1.flac',
            filePath: '/storage/s1.flac',
            title: 'Master Symphony',
            artist: 'Orchestra',
            album: 'Audiophile Collection',
            durationMs: 300000,
            fileExtension: 'flac',
            fileSizeBytes: 45000000,
            sampleRateHz: const Value(96000),
            bitDepth: const Value(24),
            dateAdded: DateTime.now(),
          ),
          TracksCompanion.insert(
            id: 's2',
            sourceUri: 'file:///s2.mp3',
            filePath: '/storage/s2.mp3',
            title: 'Compressed MP3 Track',
            artist: 'Band',
            album: 'Demo Album',
            durationMs: 180000,
            fileExtension: 'mp3',
            fileSizeBytes: 5000000,
            sampleRateHz: const Value(44100),
            bitDepth: const Value(16),
            dateAdded: DateTime.now(),
          ),
        ]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              musicLibraryRepositoryProvider.overrideWithValue(repo),
              audioPlayerFacadeProvider.overrideWithValue(fake),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const LibraryScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify format filter chips are rendered
        expect(find.text('All'), findsOneWidget);
        expect(find.text('Hi-Res'), findsOneWidget);
        expect(find.text('Lossless'), findsOneWidget);
        expect(find.text('Standard'), findsOneWidget);

        // Both tracks present under 'All'
        expect(find.text('Master Symphony'), findsOneWidget);
        expect(find.text('Compressed MP3 Track'), findsOneWidget);

        // Tap 'Hi-Res' chip
        await tester.tap(find.text('Hi-Res'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Only Hi-Res track should remain visible
        expect(find.text('Master Symphony'), findsOneWidget);
        expect(find.text('Compressed MP3 Track'), findsNothing);

        // Clean unmount
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
        await db.close();
      },
    );

    testWidgets(
      'HomeScreen renders dynamic Curated Playlists cards for Favorites and Hi-Res Masters',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final db = AppDatabase(NativeDatabase.memory());
        final repo = DriftLibraryRepository(database: db);
        final fake = FakeAudioPlayerFacade();

        await repo.database.batchInsertTracks([
          TracksCompanion.insert(
            id: 'f1',
            sourceUri: 'file:///f1.flac',
            filePath: '/storage/f1.flac',
            title: 'Favorite Masterpiece',
            artist: 'Acoustic Trio',
            album: 'Pure Sound',
            durationMs: 250000,
            fileExtension: 'flac',
            fileSizeBytes: 40000000,
            sampleRateHz: const Value(96000),
            bitDepth: const Value(24),
            isFavorite: const Value(true),
            dateAdded: DateTime.now(),
          ),
        ]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              musicLibraryRepositoryProvider.overrideWithValue(repo),
              audioPlayerFacadeProvider.overrideWithValue(fake),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const HomeScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify Curated Playlists cards
        expect(find.text('Curated Playlists'), findsOneWidget);
        expect(find.text('Favorites'), findsOneWidget);
        expect(find.text('Hi-Res Masters'), findsOneWidget);
        expect(find.text('1 starred tracks'), findsOneWidget);
        expect(find.text('1 lossless tracks'), findsOneWidget);

        // Clean unmount
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
        await db.close();
      },
    );
  });
}
