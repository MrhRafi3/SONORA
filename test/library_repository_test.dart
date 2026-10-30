import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/database/app_database.dart';
import 'package:sonora/features/library/data/drift_library_repository.dart';

void main() {
  late AppDatabase db;
  late DriftLibraryRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftLibraryRepository(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DriftLibraryRepository Domain Logic Tests', () {
    test('getAlbums aggregates unique albums and artists correctly', () async {
      final now = DateTime.now();
      await db.batchInsertTracks([
        TracksCompanion.insert(
          id: 't1',
          sourceUri: 'u1',
          filePath: '/p1.flac',
          title: 'Track 1',
          artist: 'Pink Floyd',
          album: 'The Dark Side of the Moon',
          durationMs: 200000,
          fileExtension: 'flac',
          fileSizeBytes: 30000000,
          dateAdded: now,
        ),
        TracksCompanion.insert(
          id: 't2',
          sourceUri: 'u2',
          filePath: '/p2.flac',
          title: 'Track 2',
          artist: 'Pink Floyd',
          album: 'The Dark Side of the Moon',
          durationMs: 220000,
          fileExtension: 'flac',
          fileSizeBytes: 32000000,
          dateAdded: now,
        ),
        TracksCompanion.insert(
          id: 't3',
          sourceUri: 'u3',
          filePath: '/p3.flac',
          title: 'Wish You Were Here',
          artist: 'Pink Floyd',
          album: 'Wish You Were Here',
          durationMs: 330000,
          fileExtension: 'flac',
          fileSizeBytes: 40000000,
          dateAdded: now,
        ),
      ]);

      final albums = await repo.getAlbums();
      expect(albums.length, 2);

      final darkSide = albums.firstWhere(
        (a) => a.name == 'The Dark Side of the Moon',
      );
      expect(darkSide.artist, 'Pink Floyd');
      expect(darkSide.trackCount, 2);

      final wish = albums.firstWhere((a) => a.name == 'Wish You Were Here');
      expect(wish.trackCount, 1);
    });

    test(
      'getArtists aggregates unique artists and counts albums correctly',
      () async {
        final now = DateTime.now();
        await db.batchInsertTracks([
          TracksCompanion.insert(
            id: 't1',
            sourceUri: 'u1',
            filePath: '/p1.flac',
            title: 'Track 1',
            artist: 'Miles Davis',
            album: 'Kind of Blue',
            durationMs: 200000,
            fileExtension: 'flac',
            fileSizeBytes: 30000000,
            dateAdded: now,
          ),
          TracksCompanion.insert(
            id: 't2',
            sourceUri: 'u2',
            filePath: '/p2.flac',
            title: 'Track 2',
            artist: 'Miles Davis',
            album: 'Bitches Brew',
            durationMs: 400000,
            fileExtension: 'flac',
            fileSizeBytes: 45000000,
            dateAdded: now,
          ),
          TracksCompanion.insert(
            id: 't3',
            sourceUri: 'u3',
            filePath: '/p3.flac',
            title: 'Track 3',
            artist: 'John Coltrane',
            album: 'A Love Supreme',
            durationMs: 350000,
            fileExtension: 'flac',
            fileSizeBytes: 38000000,
            dateAdded: now,
          ),
        ]);

        final artists = await repo.getArtists();
        expect(artists.length, 2);

        final miles = artists.firstWhere((a) => a.name == 'Miles Davis');
        expect(miles.trackCount, 2);
        expect(miles.albumCount, 2);

        final coltrane = artists.firstWhere((a) => a.name == 'John Coltrane');
        expect(coltrane.trackCount, 1);
        expect(coltrane.albumCount, 1);
      },
    );

    test('Create playlist, add tracks and query playlist tracks', () async {
      final now = DateTime.now();
      await db.insertTrack(
        TracksCompanion.insert(
          id: 'track-jazz-1',
          sourceUri: 'uri-jazz',
          filePath: '/p/jazz.flac',
          title: 'Blue in Green',
          artist: 'Miles Davis',
          album: 'Kind of Blue',
          durationMs: 337000,
          fileExtension: 'flac',
          fileSizeBytes: 25000000,
          dateAdded: now,
        ),
      );

      final playlist = await repo.createPlaylist('Late Night Jazz');
      expect(playlist.name, 'Late Night Jazz');

      await repo.addTrackToPlaylist(playlist.id, 'track-jazz-1');

      final tracks = await repo.getTracksForPlaylist(playlist.id);
      expect(tracks.length, 1);
      expect(tracks.first.title, 'Blue in Green');
      expect(tracks.first.displayArtist, 'Miles Davis');
    });
  });
}
