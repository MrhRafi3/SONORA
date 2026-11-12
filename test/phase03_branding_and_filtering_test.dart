import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/database/app_database.dart';
import 'package:sonora/features/library/data/drift_library_repository.dart';
import 'package:sonora/features/library/data/music_file_filter.dart';

void main() {
  group('Phase 03: Music File & Directory Filtering Tests', () {
    late MusicFileFilter filter;

    setUp(() {
      filter = MusicFileFilter();
    });

    test('Excludes WhatsApp Voice Notes and Audio files', () {
      final paths = [
        '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Voice Notes/202340/PTT-20231012-WA0001.opus',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Voice Notes/PTT-20231101-WA0004.opus',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio/AUD-20231012-WA0002.mp3',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Documents/voice_sample.m4a',
        '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Voice Notes/PTT.opus',
      ];

      for (final p in paths) {
        expect(
          filter.isExcludedPath(p),
          isTrue,
          reason: 'Expected $p to be excluded',
        );
        expect(
          filter.isMusicFile(p),
          isFalse,
          reason: 'Expected $p not to be classified as a music file',
        );
      }
    });

    test('Excludes Telegram voice messages and audio', () {
      final paths = [
        '/storage/emulated/0/Telegram/Telegram Audio/voice_message_123.ogg',
        '/storage/emulated/0/Android/data/org.telegram.messenger/audio_543.ogg',
        '/storage/emulated/0/Telegram/Telegram Documents/audio_file.opus',
      ];

      for (final p in paths) {
        expect(
          filter.isExcludedPath(p),
          isTrue,
          reason: 'Expected $p to be excluded',
        );
        expect(
          filter.isMusicFile(p),
          isFalse,
          reason: 'Expected $p not to be classified as music file',
        );
      }
    });

    test('Excludes Call recordings and voice recorder directories', () {
      final paths = [
        '/storage/emulated/0/CallRecordings/Call_20231012.m4a',
        '/storage/emulated/0/Call Recordings/call@20231012.mp3',
        '/storage/emulated/0/Recordings/Call/rec_001.mp3',
        '/storage/emulated/0/SoundRecorder/voice_001.wav',
        '/storage/emulated/0/Voice Recorder/memo_01.m4a',
        '/storage/emulated/0/VoiceRecordings/rec_voice.aac',
      ];

      for (final p in paths) {
        expect(
          filter.isExcludedPath(p),
          isTrue,
          reason: 'Expected $p to be excluded',
        );
      }
    });

    test('Excludes System Ringtones, Notifications, and Alarms', () {
      final paths = [
        '/storage/emulated/0/Ringtones/marimba.mp3',
        '/storage/emulated/0/Notifications/pop.ogg',
        '/storage/emulated/0/Alarms/sunrise.mp3',
        '/system/media/audio/ringtones/ringtone.ogg',
        '/storage/emulated/0/media/audio/ui/click.ogg',
      ];

      for (final p in paths) {
        expect(
          filter.isExcludedPath(p),
          isTrue,
          reason: 'Expected $p to be excluded',
        );
      }
    });

    test('Excludes hidden files and hidden directories', () {
      final paths = [
        '/storage/emulated/0/.hidden/track.mp3',
        '/storage/emulated/0/Music/.trash/deleted.flac',
        '/storage/emulated/0/.thumbnails/audio_thumb.wav',
        '/storage/emulated/0/Music/._preview.mp3',
        '/storage/emulated/0/Music/.hidden_file.m4a',
      ];

      for (final p in paths) {
        expect(
          filter.isExcludedPath(p),
          isTrue,
          reason: 'Expected $p to be excluded',
        );
      }
    });

    test('Respects .nomedia marker in directory hierarchy', () {
      final mockExistingFiles = <String>{
        '/storage/emulated/0/AppFolder/.nomedia',
        '/storage/emulated/0/ParentFolder/.nomedia',
      };

      final customFilter = MusicFileFilter(
        fileExistsChecker: (path) => mockExistingFiles.contains(path),
      );

      // File directly in folder with .nomedia
      expect(
        customFilter.isExcludedPath('/storage/emulated/0/AppFolder/song.mp3'),
        isTrue,
      );

      // File in subdirectory of folder with .nomedia
      expect(
        customFilter.isExcludedPath(
          '/storage/emulated/0/ParentFolder/SubFolder/audio.flac',
        ),
        isTrue,
      );

      // File in folder without .nomedia
      expect(
        customFilter.isExcludedPath(
          '/storage/emulated/0/Music/album/track.flac',
        ),
        isFalse,
      );
    });

    test('Preserves legitimate audio files across all 7 supported formats', () {
      final validTracks = [
        '/storage/emulated/0/Music/Artist/Album/01_intro.mp3',
        '/storage/emulated/0/Music/Classical/Beethoven/Symphony_No_9.flac',
        '/storage/emulated/0/Music/Audiophile/Acoustic_Master.wav',
        '/storage/emulated/0/Music/Pop/Single_Track.m4a',
        '/storage/emulated/0/Music/Jazz/Miles_Davis.aac',
        '/storage/emulated/0/Music/Soundtracks/Epic_Score.ogg',
        '/storage/emulated/0/Music/Modern/High_Res.opus',
        '/storage/emulated/0/Download/purchased_track.mp3',
      ];

      for (final p in validTracks) {
        expect(
          filter.isExcludedPath(p),
          isFalse,
          reason: 'Expected legitimate music file $p to be preserved',
        );
        expect(
          filter.isMusicFile(p),
          isTrue,
          reason: 'Expected $p to be recognized as valid music file',
        );
      }
    });

    test('Prioritizes /Music/ folder over other directories', () {
      final musicScore = filter.getPriorityScore(
        '/storage/emulated/0/Music/song.flac',
      );
      final downloadScore = filter.getPriorityScore(
        '/storage/emulated/0/Download/song.flac',
      );
      final otherScore = filter.getPriorityScore(
        '/storage/emulated/0/Custom/song.flac',
      );

      expect(musicScore, greaterThan(downloadScore));
      expect(downloadScore, greaterThan(otherScore));
    });
  });

  group('Phase 03: Safe Library Index Cleanup & Preservation', () {
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
      'purgeNonMusicEntries removes pre-existing WhatsApp audio and non-music entries from SQLite safely',
      () async {
        final now = DateTime.now();

        // Populate database with legitimate music AND accidental voice notes / non-music entries
        await db.batchInsertTracks([
          TracksCompanion.insert(
            id: 'real_1',
            sourceUri: 'content://media/1',
            filePath:
                '/storage/emulated/0/Music/Pink Floyd/Comfortably Numb.flac',
            title: 'Comfortably Numb',
            artist: 'Pink Floyd',
            album: 'The Wall',
            durationMs: 382000,
            fileExtension: 'flac',
            fileSizeBytes: 45000000,
            dateAdded: now,
            isFavorite: const Value(true),
          ),
          TracksCompanion.insert(
            id: 'real_2',
            sourceUri: 'content://media/2',
            filePath:
                '/storage/emulated/0/Music/Radiohead/Paranoid Android.mp3',
            title: 'Paranoid Android',
            artist: 'Radiohead',
            album: 'OK Computer',
            durationMs: 387000,
            fileExtension: 'mp3',
            fileSizeBytes: 12000000,
            dateAdded: now,
          ),
          // Excluded entries
          TracksCompanion.insert(
            id: 'wa_voice_note_1',
            sourceUri: 'content://media/3',
            filePath:
                '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Voice Notes/202340/PTT-20231012-WA0001.opus',
            title: 'PTT-20231012-WA0001',
            artist: '',
            album: '',
            durationMs: 15000,
            fileExtension: 'opus',
            fileSizeBytes: 45000,
            dateAdded: now,
          ),
          TracksCompanion.insert(
            id: 'wa_audio_1',
            sourceUri: 'content://media/4',
            filePath:
                '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio/AUD-20231012-WA0002.mp3',
            title: 'AUD-20231012-WA0002',
            artist: '',
            album: '',
            durationMs: 45000,
            fileExtension: 'mp3',
            fileSizeBytes: 150000,
            dateAdded: now,
          ),
          TracksCompanion.insert(
            id: 'ringtone_1',
            sourceUri: 'content://media/5',
            filePath: '/storage/emulated/0/Ringtones/marimba.mp3',
            title: 'Marimba',
            artist: '',
            album: '',
            durationMs: 25000,
            fileExtension: 'mp3',
            fileSizeBytes: 80000,
            dateAdded: now,
          ),
          TracksCompanion.insert(
            id: 'call_rec_1',
            sourceUri: 'content://media/6',
            filePath: '/storage/emulated/0/CallRecordings/call_mom.m4a',
            title: 'Call Mom',
            artist: '',
            album: '',
            durationMs: 120000,
            fileExtension: 'm4a',
            fileSizeBytes: 500000,
            dateAdded: now,
          ),
        ]);

        // Create playlist with legitimate track
        final playlist = await repo.createPlaylist('Favorites Mix');
        await repo.addTrackToPlaylist(playlist.id, 'real_1');

        // Verify initial track count is 6
        final beforeTracks = await repo.getTracks();
        expect(beforeTracks.length, 6);

        // Run safe purge
        final purgedCount = await repo.purgeNonMusicEntries();
        expect(purgedCount, 4);

        // Verify only 2 legitimate music tracks remain
        final afterTracks = await repo.getTracks();
        expect(afterTracks.length, 2);
        expect(
          afterTracks.map((t) => t.id).toSet(),
          containsAll(['real_1', 'real_2']),
        );

        // Verify user favorites and playlists are strictly preserved
        final real1 = await repo.getTrackById('real_1');
        expect(real1?.isFavorite, isTrue);

        final playlistTracks = await repo.getTracksForPlaylist(playlist.id);
        expect(playlistTracks.length, 1);
        expect(playlistTracks.first.id, 'real_1');
      },
    );
  });

  group('Phase 03: Android Branding & Splash Assets Verification', () {
    test(
      'Android launcher icon assets exist across all required densities',
      () {
        final densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
        for (final density in densities) {
          final iconFile = File(
            'android/app/src/main/res/mipmap-$density/ic_launcher.png',
          );
          expect(
            iconFile.existsSync(),
            isTrue,
            reason:
                'Expected ic_launcher.png to exist for density mipmap-$density',
          );
          expect(
            iconFile.lengthSync(),
            greaterThan(0),
            reason: 'Expected mipmap-$density/ic_launcher.png to be non-empty',
          );
        }
      },
    );

    test('Android adaptive icon configuration exists in mipmap-anydpi-v26', () {
      final adaptiveXml = File(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      );
      expect(adaptiveXml.existsSync(), isTrue);

      final content = adaptiveXml.readAsStringSync();
      expect(content, contains('<adaptive-icon'));
      expect(content, contains('ic_launcher_background'));
      expect(content, contains('ic_launcher_foreground'));
    });

    test(
      'Android native splash screens configure SONORA logo and charcoal background',
      () {
        final launchBackground = File(
          'android/app/src/main/res/drawable/launch_background.xml',
        );
        expect(launchBackground.existsSync(), isTrue);
        final bgContent = launchBackground.readAsStringSync();
        expect(bgContent, contains('android:src="@drawable/splash"'));

        final stylesV31 = File(
          'android/app/src/main/res/values-v31/styles.xml',
        );
        expect(stylesV31.existsSync(), isTrue);
        final stylesContent = stylesV31.readAsStringSync();
        expect(
          stylesContent,
          contains('android:windowSplashScreenAnimatedIcon'),
        );
        expect(stylesContent, contains('android:windowSplashScreenBackground'));
        expect(stylesContent, contains('#171717'));
      },
    );

    test('Source branding logo asset exists and is non-empty', () {
      final logo = File('assets/branding/sonora_logo.png');
      expect(logo.existsSync(), isTrue);
      expect(logo.lengthSync(), greaterThan(1000));
    });
  });
}
