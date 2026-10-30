import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Drift SQLite AppDatabase Tests', () {
    test('Inserts a track and retrieves it by id and sourceUri', () async {
      final now = DateTime.now();
      await db.insertTrack(
        TracksCompanion.insert(
          id: 'track-1',
          sourceUri: 'content://media/external/audio/media/100',
          filePath: '/storage/emulated/0/Music/track1.flac',
          title: 'Symphony No. 5 in C Minor',
          artist: 'Ludwig van Beethoven',
          album: 'Beethoven: The Symphonies',
          durationMs: 442000,
          fileExtension: 'flac',
          fileSizeBytes: 45000000,
          bitrateKbps: const Value(1411),
          sampleRateHz: const Value(96000),
          bitDepth: const Value(24),
          trackNumber: const Value(1),
          dateAdded: now,
        ),
      );

      final track = await db.getTrackById('track-1');
      expect(track, isNotNull);
      expect(track!.title, 'Symphony No. 5 in C Minor');
      expect(track.artist, 'Ludwig van Beethoven');
      expect(track.album, 'Beethoven: The Symphonies');
      expect(track.sampleRateHz, 96000);
      expect(track.bitDepth, 24);

      final byUri = await db.getTrackBySourceUri(
        'content://media/external/audio/media/100',
      );
      expect(byUri?.id, 'track-1');
    });

    test(
      'On conflict update updates existing track without duplicating',
      () async {
        final now = DateTime.now();
        await db.insertTrack(
          TracksCompanion.insert(
            id: 'track-dup',
            sourceUri: 'file:///var/mobile/track.mp3',
            filePath: '/var/mobile/track.mp3',
            title: 'Original Title',
            artist: 'Original Artist',
            album: 'Original Album',
            durationMs: 180000,
            fileExtension: 'mp3',
            fileSizeBytes: 5000000,
            dateAdded: now,
          ),
        );

        // Re-insert with updated title
        await db.insertTrack(
          TracksCompanion.insert(
            id: 'track-dup',
            sourceUri: 'file:///var/mobile/track.mp3',
            filePath: '/var/mobile/track.mp3',
            title: 'Updated Title',
            artist: 'Original Artist',
            album: 'Original Album',
            durationMs: 180000,
            fileExtension: 'mp3',
            fileSizeBytes: 5000000,
            dateAdded: now,
          ),
        );

        final allTracks = await db.getAllTracks();
        expect(allTracks.length, 1);
        expect(allTracks.first.title, 'Updated Title');
      },
    );

    test(
      'Search tracks matches title, artist, album, and genre case-insensitively',
      () async {
        final now = DateTime.now();
        await db.batchInsertTracks([
          TracksCompanion.insert(
            id: 't-1',
            sourceUri: 'uri-1',
            filePath: '/path/1.flac',
            title: 'Clair de Lune',
            artist: 'Claude Debussy',
            album: 'Suite Bergamasque',
            genre: const Value('Impressionist Classical'),
            durationMs: 300000,
            fileExtension: 'flac',
            fileSizeBytes: 20000000,
            dateAdded: now,
          ),
          TracksCompanion.insert(
            id: 't-2',
            sourceUri: 'uri-2',
            filePath: '/path/2.mp3',
            title: 'So What',
            artist: 'Miles Davis',
            album: 'Kind of Blue',
            genre: const Value('Modal Jazz'),
            durationMs: 560000,
            fileExtension: 'mp3',
            fileSizeBytes: 12000000,
            dateAdded: now,
          ),
        ]);

        // Search by title
        final r1 = await db.searchTracks('clair');
        expect(r1.length, 1);
        expect(r1.first.id, 't-1');

        // Search by artist
        final r2 = await db.searchTracks('miles');
        expect(r2.length, 1);
        expect(r2.first.id, 't-2');

        // Search by album
        final r3 = await db.searchTracks('bergamasque');
        expect(r3.length, 1);
        expect(r3.first.id, 't-1');

        // Search by genre
        final r4 = await db.searchTracks('jazz');
        expect(r4.length, 1);
        expect(r4.first.id, 't-2');

        // Non-matching search
        final r5 = await db.searchTracks('nonexistent');
        expect(r5, isEmpty);
      },
    );

    test('Sorting by artist, title, dateAdded, and duration', () async {
      final now = DateTime.now();
      await db.batchInsertTracks([
        TracksCompanion.insert(
          id: 'b-track',
          sourceUri: 'uri-b',
          filePath: '/path/b.flac',
          title: 'Bravo Track',
          artist: 'Zack',
          album: 'Album Z',
          durationMs: 100000,
          fileExtension: 'flac',
          fileSizeBytes: 1000,
          dateAdded: now.subtract(const Duration(days: 2)),
        ),
        TracksCompanion.insert(
          id: 'a-track',
          sourceUri: 'uri-a',
          filePath: '/path/a.flac',
          title: 'Alpha Track',
          artist: 'Alice',
          album: 'Album A',
          durationMs: 200000,
          fileExtension: 'flac',
          fileSizeBytes: 2000,
          dateAdded: now,
        ),
      ]);

      // Sort by title ascending
      final byTitle = await db
          .watchAllTracks(sortBy: 'title', ascending: true)
          .first;
      expect(byTitle.first.title, 'Alpha Track');
      expect(byTitle.last.title, 'Bravo Track');

      // Sort by title descending
      final byTitleDesc = await db
          .watchAllTracks(sortBy: 'title', ascending: false)
          .first;
      expect(byTitleDesc.first.title, 'Bravo Track');
      expect(byTitleDesc.last.title, 'Alpha Track');

      // Sort by artist ascending
      final byArtist = await db
          .watchAllTracks(sortBy: 'artist', ascending: true)
          .first;
      expect(byArtist.first.artist, 'Alice');

      // Sort by duration descending
      final byDurationDesc = await db
          .watchAllTracks(sortBy: 'duration', ascending: false)
          .first;
      expect(byDurationDesc.first.durationMs, 200000);
    });

    test('Favorites toggling and filtering', () async {
      final now = DateTime.now();
      await db.insertTrack(
        TracksCompanion.insert(
          id: 'fav-1',
          sourceUri: 'uri-fav',
          filePath: '/path/fav.flac',
          title: 'Favorite Track',
          artist: 'Sample Artist',
          album: 'Sample Album',
          durationMs: 200000,
          fileExtension: 'flac',
          fileSizeBytes: 1000,
          dateAdded: now,
        ),
      );

      var favorites = await db.watchFavoriteTracks().first;
      expect(favorites, isEmpty);

      // Mark as favorite
      await db.setFavorite('fav-1', true);
      favorites = await db.watchFavoriteTracks().first;
      expect(favorites.length, 1);
      expect(favorites.first.title, 'Favorite Track');

      // Unmark
      await db.setFavorite('fav-1', false);
      favorites = await db.watchFavoriteTracks().first;
      expect(favorites, isEmpty);
    });

    test('Playlists CRUD and track associations', () async {
      final now = DateTime.now();
      await db.insertTrack(
        TracksCompanion.insert(
          id: 'pl-track-1',
          sourceUri: 'uri-pl-1',
          filePath: '/path/pl1.flac',
          title: 'Acoustic Guitar Prelude',
          artist: 'Julian Bream',
          album: 'Classical Guitar Masters',
          durationMs: 150000,
          fileExtension: 'flac',
          fileSizeBytes: 1000,
          dateAdded: now,
        ),
      );

      // Create playlist
      await db.createPlaylist('pl-1', 'Acoustic Evenings');
      final playlists = await db.watchAllPlaylists().first;
      expect(playlists.length, 1);
      expect(playlists.first.name, 'Acoustic Evenings');

      // Add track to playlist
      await db.addTrackToPlaylist('pl-1', 'pl-track-1', 0);
      final plTracks = await db.getTracksForPlaylist('pl-1');
      expect(plTracks.length, 1);
      expect(plTracks.first.title, 'Acoustic Guitar Prelude');

      // Delete playlist
      await db.deletePlaylist('pl-1');
      final emptyPlaylists = await db.watchAllPlaylists().first;
      expect(emptyPlaylists, isEmpty);
    });
  });
}
