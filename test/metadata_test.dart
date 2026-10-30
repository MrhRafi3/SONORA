import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/constants/app_constants.dart';
import 'package:sonora/core/services/artwork_cache_service.dart';
import 'package:sonora/core/services/audio_metadata_service.dart';
import 'package:sonora/features/library/domain/entities.dart';

void main() {
  group('AudioMetadataService Tests', () {
    const service = AudioMetadataService();

    test(
      'Supported extensions include lossless and compressed audiophile formats',
      () {
        expect(AppConstants.supportedAudioExtensions, contains('flac'));
        expect(AppConstants.supportedAudioExtensions, contains('mp3'));
        expect(AppConstants.supportedAudioExtensions, contains('wav'));
        expect(AppConstants.supportedAudioExtensions, contains('m4a'));
        expect(AppConstants.supportedAudioExtensions, contains('aac'));
        expect(AppConstants.supportedAudioExtensions, contains('ogg'));
        expect(AppConstants.supportedAudioExtensions, contains('opus'));
      },
    );

    test('AudioTrack entity duration formatting formats correctly', () {
      final track = AudioTrack(
        id: 'test-1',
        sourceUri: 'uri',
        filePath: '/test.flac',
        title: 'Title',
        duration: const Duration(minutes: 5, seconds: 7),
        fileExtension: 'flac',
        fileSizeBytes: 1024,
        dateAdded: DateTime.now(),
      );

      expect(track.formattedDuration, '5:07');
    });

    test('AudioTrack entity format badge constructs hi-res label', () {
      final flacTrack = AudioTrack(
        id: 'test-flac',
        sourceUri: 'uri',
        filePath: '/test.flac',
        title: 'Title',
        duration: const Duration(minutes: 3),
        fileExtension: 'flac',
        fileSizeBytes: 1024,
        sampleRateHz: 96000,
        bitDepth: 24,
        dateAdded: DateTime.now(),
      );
      expect(flacTrack.formatBadge, 'FLAC • 24-bit/96 kHz');

      final mp3Track = AudioTrack(
        id: 'test-mp3',
        sourceUri: 'uri',
        filePath: '/test.mp3',
        title: 'Title',
        duration: const Duration(minutes: 3),
        fileExtension: 'mp3',
        fileSizeBytes: 1024,
        bitrateKbps: 320,
        dateAdded: DateTime.now(),
      );
      expect(mp3Track.formatBadge, 'MP3 • 320 kbps');
    });

    test(
      'Extract metadata from non-existent file returns filename fallback without crashing',
      () async {
        final tempFile = File(
          '/tmp/sonora_test_sample_Artist_Name_-_Song_Title.mp3',
        );
        final result = await service.extractMetadata(
          tempFile,
          extractArtwork: false,
        );

        expect(result.fileExtension, 'mp3');
        expect(result.title, isNotEmpty);
      },
    );
  });

  group('ArtworkCacheService Tests', () {
    const cacheService = ArtworkCacheService();

    test('Cache key sanitizes names into consistent SHA-1 hash strings', () {
      final key1 = cacheService.hashKey('Album One_Artist A');
      final key2 = cacheService.hashKey('Album One_Artist A');
      final key3 = cacheService.hashKey('Different Album_Artist B');

      expect(key1, isNotEmpty);
      expect(key1, equals(key2));
      expect(key1, isNot(equals(key3)));
    });
  });
}
