import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/features/player/data/fake_audio_player_facade.dart';
import 'package:sonora/features/player/data/sonora_audio_handler.dart';
import 'package:sonora/features/player/domain/ui_track.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SonoraAudioHandler — MediaItem & PlaybackState Unit Tests', () {
    late SonoraAudioHandler handler;

    setUp(() {
      handler = SonoraAudioHandler();
    });

    tearDown(() async {
      // Do not call disposeHandler if player wasn't initialized with mock
    });

    const sampleTrackWithArt = UiTrack(
      id: 'track-101',
      title: 'Nocturne in E-flat Major',
      artist: 'Frédéric Chopin',
      album: 'Complete Nocturnes',
      duration: Duration(minutes: 4, seconds: 30),
      audioFormat: 'FLAC',
      sampleRate: '96 kHz',
      bitDepth: '24-bit',
      artworkPath: '/var/mobile/Containers/Data/Application/art.jpg',
      sourceUri: 'content://media/external/audio/media/101',
      filePath: '/storage/emulated/0/Music/chopin.flac',
    );

    const sampleTrackNoArt = UiTrack(
      id: 'track-102',
      title: 'Gymnopédie No. 1',
      artist: 'Erik Satie',
      album: 'Piano Works',
      duration: Duration(minutes: 3, seconds: 10),
      audioFormat: 'MP3',
      sampleRate: '44.1 kHz',
      bitDepth: '320 kbps',
      artworkPath: null,
      sourceUri: null,
      filePath: '/storage/emulated/0/Music/satie.mp3',
    );

    test('1. Converts UiTrack to MediaItem with artwork URI and extras', () {
      final mediaItem = handler.trackToMediaItem(sampleTrackWithArt);

      expect(mediaItem.id, equals('track-101'));
      expect(mediaItem.title, equals('Nocturne in E-flat Major'));
      expect(mediaItem.artist, equals('Frédéric Chopin'));
      expect(mediaItem.album, equals('Complete Nocturnes'));
      expect(
        mediaItem.duration,
        equals(const Duration(minutes: 4, seconds: 30)),
      );
      expect(
        mediaItem.artUri,
        equals(Uri.file('/var/mobile/Containers/Data/Application/art.jpg')),
      );
      expect(mediaItem.extras?['audioFormat'], equals('FLAC'));
      expect(mediaItem.extras?['sampleRate'], equals('96 kHz'));
      expect(mediaItem.extras?['bitDepth'], equals('24-bit'));
      expect(
        mediaItem.extras?['sourceUri'],
        equals('content://media/external/audio/media/101'),
      );
      expect(
        mediaItem.extras?['filePath'],
        equals('/storage/emulated/0/Music/chopin.flac'),
      );
    });

    test('2. Converts UiTrack with missing artwork without crashing', () {
      final mediaItem = handler.trackToMediaItem(sampleTrackNoArt);

      expect(mediaItem.id, equals('track-102'));
      expect(mediaItem.title, equals('Gymnopédie No. 1'));
      expect(mediaItem.artUri, isNull);
      expect(mediaItem.extras?['audioFormat'], equals('MP3'));
    });

    test('3. updateActiveTrack broadcasts MediaItem event', () async {
      handler.updateActiveTrack(sampleTrackWithArt);

      expect(handler.mediaItem.value, isNotNull);
      expect(handler.mediaItem.value!.id, equals('track-101'));
      expect(
        handler.mediaItem.value!.title,
        equals('Nocturne in E-flat Major'),
      );
    });

    test('4. updateActiveQueue updates system queue stream', () async {
      handler.updateActiveQueue([sampleTrackWithArt, sampleTrackNoArt]);

      expect(handler.queue.value.length, equals(2));
      expect(handler.queue.value[0].id, equals('track-101'));
      expect(handler.queue.value[1].id, equals('track-102'));
    });

    test('5. Remote skipToNext delegates to registered callback', () async {
      var nextCalled = false;
      handler.onSkipToNext = () {
        nextCalled = true;
      };

      await handler.skipToNext();
      expect(nextCalled, isTrue);
    });

    test('6. Remote skipToPrevious delegates to registered callback', () async {
      var prevCalled = false;
      handler.onSkipToPrevious = () {
        prevCalled = true;
      };

      await handler.skipToPrevious();
      expect(prevCalled, isTrue);
    });

    test('7. Remote skipToQueueItem delegates with correct index', () async {
      int? requestedIndex;
      handler.onSkipToQueueItem = (index) {
        requestedIndex = index;
      };

      await handler.skipToQueueItem(3);
      expect(requestedIndex, equals(3));
    });

    test('8. Remote setRepeatMode delegates correctly', () async {
      AudioServiceRepeatMode? repeatMode;
      handler.onSetRepeatMode = (mode) {
        repeatMode = mode;
      };

      await handler.setRepeatMode(AudioServiceRepeatMode.all);
      expect(repeatMode, equals(AudioServiceRepeatMode.all));
    });

    test('9. Remote setShuffleMode delegates correctly', () async {
      AudioServiceShuffleMode? shuffleMode;
      handler.onSetShuffleMode = (mode) {
        shuffleMode = mode;
      };

      await handler.setShuffleMode(AudioServiceShuffleMode.all);
      expect(shuffleMode, equals(AudioServiceShuffleMode.all));
    });

    test(
      '10. FakeAudioPlayerFacade preserves in-memory test contracts',
      () async {
        final fake = FakeAudioPlayerFacade();
        expect(fake.isPlaying, isFalse);

        await fake.load('content://media/external/audio/media/1');
        expect(fake.loadCount, equals(1));
        expect(
          fake.lastLoadedSource,
          equals('content://media/external/audio/media/1'),
        );

        await fake.play();
        expect(fake.isPlaying, isTrue);

        await fake.pause();
        expect(fake.isPlaying, isFalse);

        await fake.dispose();
      },
    );
  });
}
