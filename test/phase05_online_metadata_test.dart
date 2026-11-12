import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonora/app/theme/app_theme.dart';
import 'package:sonora/core/database/app_database.dart';
import 'package:sonora/core/services/artwork_cache_service.dart';
import 'package:sonora/features/metadata/data/datasources/lrclib_client.dart';
import 'package:sonora/features/metadata/data/datasources/online_artwork_client.dart';
import 'package:sonora/features/metadata/data/repositories/metadata_repository.dart';
import 'package:sonora/features/metadata/domain/models/artwork_match.dart';
import 'package:sonora/features/metadata/domain/models/lyrics_model.dart';
import 'package:sonora/features/metadata/presentation/widgets/artwork_selector_dialog.dart';
import 'package:sonora/features/metadata/presentation/widgets/lyrics_preview_dialog.dart';
import 'package:sonora/features/player/domain/ui_track.dart';
import 'package:sonora/features/player/presentation/widgets/lyrics_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tempCacheDir;
  late ArtworkCacheService artworkCache;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tempCacheDir = await Directory.systemTemp.createTemp('sonora_meta_test_');
    artworkCache = ArtworkCacheService(customCacheDir: tempCacheDir);
  });

  tearDown(() async {
    await db.close();
    if (await tempCacheDir.exists()) {
      await tempCacheDir.delete(recursive: true);
    }
  });

  group('1. Lyrics Parsing & Model Tests', () {
    test(
      'Parses synchronized LRC strings with milliseconds and multiple timestamps',
      () {
        const sampleLrc = '''
[ti:Clair de Lune]
[ar:Claude Debussy]
[al:Suite Bergamasque]
[00:14.25]Votre âme est un paysage choisi
[00:28.50][00:35.00]Que vont charmant masques et bergamasques
[01:10.800]Tout en chantant sur le mode mineur
''';

        final lines = TrackLyricsData.parseLrcString(sampleLrc);

        // Should skip 3 metadata header tags and extract 4 timed lyric lines
        expect(lines.length, 4);

        // Line 1: 14s 250ms
        expect(
          lines[0].timestamp,
          const Duration(seconds: 14, milliseconds: 250),
        );
        expect(lines[0].text, 'Votre âme est un paysage choisi');

        // Line 2 & 3 from multiple timestamps
        expect(
          lines[1].timestamp,
          const Duration(seconds: 28, milliseconds: 500),
        );
        expect(lines[1].text, 'Que vont charmant masques et bergamasques');
        expect(lines[2].timestamp, const Duration(seconds: 35));
        expect(lines[2].text, 'Que vont charmant masques et bergamasques');

        // Line 4: 1m 10s 800ms
        expect(
          lines[3].timestamp,
          const Duration(minutes: 1, seconds: 10, milliseconds: 800),
        );
        expect(lines[3].text, 'Tout en chantant sur le mode mineur');
      },
    );

    test('Parses plain text lyrics when synchronized LRC is not present', () {
      const plain = '''
First verse line
Second verse line
Chorus starts here
''';

      final data = TrackLyricsData(
        trackId: 'track-test-1',
        plainLyrics: plain,
        updatedAt: DateTime.now(),
      );

      final lines = data.parseLines();
      expect(lines.length, 3);
      expect(lines.first.text, 'First verse line');
      expect(lines.first.timestamp, Duration.zero);
      expect(lines.last.text, 'Chorus starts here');
    });

    test(
      'LrclibSearchResult calculates exact match and confidence score accurately',
      () {
        const result = LrclibSearchResult(
          id: 101,
          trackName: 'Midnight Analog Drift',
          artistName: 'Sora Soundworks',
          albumName: 'Vacuum Tube Sessions Vol. 2',
          duration: 368.0, // 6m 8s
          syncedLyrics: '[00:15.00]Synthesizer starts',
        );

        // Exact match test
        final isExact = result.isExactMatch(
          targetTitle: 'Midnight Analog Drift (Remastered)',
          targetArtist: 'Sora Soundworks',
          targetDuration: const Duration(minutes: 6, seconds: 8),
        );
        expect(isExact, isTrue);

        final score = result.calculateMatchScore(
          targetTitle: 'Midnight Analog Drift',
          targetArtist: 'Sora Soundworks',
          targetDuration: const Duration(minutes: 6, seconds: 8),
        );
        expect(score, greaterThanOrEqualTo(0.90));

        // Mismatched artist test
        final mismatched = result.isExactMatch(
          targetTitle: 'Midnight Analog Drift',
          targetArtist: 'Completely Different Artist',
          targetDuration: const Duration(minutes: 6, seconds: 8),
        );
        expect(mismatched, isFalse);
      },
    );
  });

  group('2. LRCLIB HTTP Client & Offline Handling Tests', () {
    test('getExactLyrics parses 200 response correctly', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/get')) {
          expect(request.url.queryParameters['track_name'], 'Nocturne');
          expect(request.url.queryParameters['artist_name'], 'Chopin');
          return http.Response(
            jsonEncode({
              'id': 202,
              'trackName': 'Nocturne',
              'artistName': 'Chopin',
              'albumName': 'Piano Masterpieces',
              'duration': 275.0,
              'instrumental': true,
              'plainLyrics': '',
              'syncedLyrics': '',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = LrclibClient(httpClient: mockClient);
      final res = await client.getExactLyrics(
        title: 'Nocturne',
        artist: 'Chopin',
      );

      expect(res, isNotNull);
      expect(res!.id, 202);
      expect(res.instrumental, isTrue);
    });

    test(
      'getExactLyrics returns null on 404 or network error gracefully',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"error": "Not Found"}', 404);
        });

        final client = LrclibClient(httpClient: mockClient);
        final res = await client.getExactLyrics(
          title: 'Unknown',
          artist: 'Unknown',
        );
        expect(res, isNull);
      },
    );
  });

  group('3. SQLite Persistence & Offline Retrieval Tests', () {
    test(
      'Persists, retrieves and deletes lyrics via MetadataRepository',
      () async {
        final repo = MetadataRepository(
          database: db,
          artworkCacheService: artworkCache,
        );

        // Verify empty initially
        final initial = await repo.getCachedLyrics('track-10');
        expect(initial, isNull);

        // Save lyrics
        await repo.saveLyrics(
          trackId: 'track-10',
          plainLyrics: 'Line 1\nLine 2',
          syncedLyrics: '[00:10.00]Line 1\n[00:20.00]Line 2',
          source: 'lrclib_test',
        );

        // Retrieve offline
        final saved = await repo.getCachedLyrics('track-10');
        expect(saved, isNotNull);
        expect(saved!.trackId, 'track-10');
        expect(saved.hasSynced, isTrue);
        expect(saved.source, 'lrclib_test');

        final lines = saved.parseLines();
        expect(lines.length, 2);
        expect(lines[0].text, 'Line 1');
        expect(lines[0].timestamp, const Duration(seconds: 10));

        // Delete lyrics
        await repo.removeLyrics('track-10');
        final afterDelete = await repo.getCachedLyrics('track-10');
        expect(afterDelete, isNull);
      },
    );
  });

  group('4. Artwork Matching & Confidence Calculation Tests', () {
    test(
      'calculateConfidence verifies artist and album match; rejects title-only',
      () {
        // High confidence: both match closely
        final highConf = ArtworkMatch.calculateConfidence(
          targetArtist: 'Pink Floyd',
          targetAlbum: 'The Dark Side of the Moon',
          candidateArtist: 'Pink Floyd',
          candidateAlbum: 'Dark Side of the Moon (Remastered)',
        );
        expect(highConf, greaterThanOrEqualTo(0.85));

        // Low confidence: artist is totally different (title/album alone cannot match)
        final wrongArtist = ArtworkMatch.calculateConfidence(
          targetArtist: 'Pink Floyd',
          targetAlbum: 'The Dark Side of the Moon',
          candidateArtist: 'London Symphony Orchestra',
          candidateAlbum: 'The Dark Side of the Moon',
        );
        expect(wrongArtist, lessThan(0.70));
      },
    );

    test(
      'Normalizes album titles by removing parenthesized and bracketed tags',
      () {
        expect(
          ArtworkMatch.normalize('Abbey Road [2019 Mix] (Super Deluxe)'),
          'abbey road',
        );
      },
    );
  });

  group('5. Embedded Artwork Priority & Album-Level Reuse Tests', () {
    test(
      'Embedded artwork priority: uses local file and bypasses network',
      () async {
        // Create a fake embedded artwork file
        final dummyArt = File('${tempCacheDir.path}/embedded.jpg');
        await dummyArt.writeAsBytes(List.filled(2048, 42));

        final repo = MetadataRepository(
          database: db,
          artworkCacheService: artworkCache,
        );

        final resolved = await repo.resolveAlbumArtwork(
          artist: 'The Beatles',
          album: 'Abbey Road',
          currentTrackArtworkPath: dummyArt.path,
          allowOnlineFetch: false,
        );

        expect(resolved, dummyArt.path);
      },
    );

    test(
      'Album-level reuse: reuses existing sibling track artwork without network',
      () async {
        final dummyArt = File('${tempCacheDir.path}/sibling_art.jpg');
        await dummyArt.writeAsBytes(List.filled(2048, 99));

        // Insert sibling track with embedded artwork in database
        await db.insertTrack(
          TracksCompanion.insert(
            id: 'track-sibling-1',
            sourceUri: 'file:///sibling1.flac',
            filePath: '/sibling1.flac',
            title: 'Come Together',
            artist: 'The Beatles',
            album: 'Abbey Road',
            durationMs: 259000,
            fileExtension: 'flac',
            fileSizeBytes: 15000000,
            dateAdded: DateTime.now(),
            artworkPath: Value(dummyArt.path),
          ),
        );

        final repo = MetadataRepository(
          database: db,
          artworkCacheService: artworkCache,
        );

        // Resolve artwork for a new track from same album that has NO artwork
        final resolved = await repo.resolveAlbumArtwork(
          artist: 'The Beatles',
          album: 'Abbey Road',
          currentTrackArtworkPath: null,
          allowOnlineFetch: false,
        );

        expect(resolved, dummyArt.path);
      },
    );

    test(
      'Prevention of incorrect artwork replacement: never overwrites existing embedded artwork',
      () async {
        final embeddedArt = File('${tempCacheDir.path}/keep_embedded.jpg');
        await embeddedArt.writeAsBytes(List.filled(2048, 1));

        // Track 1 has embedded artwork
        await db.insertTrack(
          TracksCompanion.insert(
            id: 'track-with-art',
            sourceUri: 'file:///song1.flac',
            filePath: '/song1.flac',
            title: 'Song 1',
            artist: 'Artist A',
            album: 'Album X',
            durationMs: 200000,
            fileExtension: 'flac',
            fileSizeBytes: 1000000,
            dateAdded: DateTime.now(),
            artworkPath: Value(embeddedArt.path),
          ),
        );

        // Track 2 lacks artwork
        await db.insertTrack(
          TracksCompanion.insert(
            id: 'track-without-art',
            sourceUri: 'file:///song2.flac',
            filePath: '/song2.flac',
            title: 'Song 2',
            artist: 'Artist A',
            album: 'Album X',
            durationMs: 210000,
            fileExtension: 'flac',
            fileSizeBytes: 1000000,
            dateAdded: DateTime.now(),
          ),
        );

        // Update album tracks artwork
        const newOnlineArt = '/path/to/downloaded_online_art.jpg';
        final updatedCount = await db.updateAlbumTracksArtwork(
          artist: 'Artist A',
          album: 'Album X',
          artworkPath: newOnlineArt,
        );

        // Should only update track 2
        expect(updatedCount, 1);

        final track1 = await db.getTrackById('track-with-art');
        final track2 = await db.getTrackById('track-without-art');

        // Track 1 retained original embedded artwork
        expect(track1!.artworkPath, embeddedArt.path);
        // Track 2 updated with the new artwork
        expect(track2!.artworkPath, newOnlineArt);
      },
    );
  });

  group('6. Online Artwork Client & Provider Tests', () {
    test(
      'OnlineArtworkClient searches iTunes with upgraded image resolution',
      () async {
        final mockClient = MockClient((request) async {
          if (request.url.host == 'itunes.apple.com') {
            return http.Response(
              jsonEncode({
                'resultCount': 1,
                'results': [
                  {
                    'artistName': 'Daft Punk',
                    'collectionName': 'Discovery',
                    'artworkUrl100':
                        'https://is1-ssl.mzstatic.com/image/thumb/100x100bb.jpg',
                    'releaseDate': '2001-03-12T08:00:00Z',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        });

        final client = OnlineArtworkClient(httpClient: mockClient);
        final results = await client.searchArtwork(
          artist: 'Daft Punk',
          album: 'Discovery',
        );

        expect(results.isNotEmpty, isTrue);
        final first = results.first;
        expect(first.artist, 'Daft Punk');
        expect(first.album, 'Discovery');
        expect(first.imageUrl, contains('600x600bb.jpg'));
        expect(first.isHighConfidence, isTrue);
      },
    );

    test(
      'downloadImageBytes returns Uint8List on valid response and null on error',
      () async {
        final fakeBytes = Uint8List.fromList(List.filled(2048, 77));
        final mockClient = MockClient((request) async {
          if (request.url.path.endsWith('cover.jpg')) {
            return http.Response.bytes(fakeBytes, 200);
          }
          return http.Response('Failed', 500);
        });

        final client = OnlineArtworkClient(httpClient: mockClient);
        final bytes = await client.downloadImageBytes(
          'https://example.com/cover.jpg',
        );
        expect(bytes, isNotNull);
        expect(bytes!.length, 2048);

        final failBytes = await client.downloadImageBytes(
          'https://example.com/missing.jpg',
        );
        expect(failBytes, isNull);
      },
    );
  });

  group('7. UI & Interaction Tests', () {
    testWidgets(
      'LyricsPreviewDialog displays parsed lines and triggers apply callback',
      (tester) async {
        bool applied = false;
        const testResult = LrclibSearchResult(
          id: 999,
          trackName: 'Test Song',
          artistName: 'Test Artist',
          albumName: 'Test Album',
          duration: 180,
          syncedLyrics: '[00:10.00]Line 1\n[00:20.00]Line 2',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: LyricsPreviewDialog(
                result: testResult,
                onApply: () => applied = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Test Song'), findsOneWidget);
        expect(find.text('LRC Synced'), findsOneWidget);
        expect(find.text('Line 1'), findsOneWidget);
        expect(find.text('Line 2'), findsOneWidget);

        await tester.tap(find.text('Save & Apply'));
        await tester.pumpAndSettle();

        expect(applied, isTrue);
      },
    );

    testWidgets('ArtworkSelectorDialog displays candidates and providers', (
      tester,
    ) async {
      const match = ArtworkMatch(
        album: 'Kind of Blue',
        artist: 'Miles Davis',
        imageUrl: 'https://example.com/kind_of_blue.jpg',
        provider: ArtworkProvider.itunes,
        confidence: 0.95,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: ArtworkSelectorDialog(
                artist: 'Miles Davis',
                album: 'Kind of Blue',
                initialMatches: const [match],
                onArtworkApplied: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select Album Artwork'), findsOneWidget);
      expect(find.text('Kind of Blue'), findsNWidgets(2));
      expect(find.text('Miles Davis'), findsNWidgets(2));
      expect(find.text('Apple iTunes'), findsOneWidget);
      expect(find.text('95% match'), findsOneWidget);
    });

    testWidgets('LyricsSheet switches between lyrics and online search view', (
      tester,
    ) async {
      const testTrack = UiTrack(
        id: 'track-ui-sample',
        title: 'Autumn Leaves',
        artist: 'Bill Evans',
        album: 'Portrait in Jazz',
        duration: Duration(minutes: 5, seconds: 25),
        audioFormat: 'FLAC',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: LyricsSheet(track: testTrack)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Synced Lyrics'), findsOneWidget);
      expect(find.text('Autumn Leaves'), findsOneWidget);

      // Tap search online icon (header icon)
      final searchIcons = find.byIcon(Icons.travel_explore_rounded);
      expect(searchIcons, findsAtLeastNWidgets(1));
      await tester.tap(searchIcons.first);
      await tester.pumpAndSettle();

      // Should now render the search bar
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
