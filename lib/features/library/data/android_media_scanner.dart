import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import '../../../core/services/artwork_cache_service.dart';
import '../../../core/services/audio_metadata_service.dart';

/// Service responsible for scanning the Android MediaStore audio index.
class AndroidMediaScanner {
  const AndroidMediaScanner({
    this.metadataService = const AudioMetadataService(),
    this.artworkCacheService = const ArtworkCacheService(),
    this.channel = const MethodChannel('com.mrhrafi3.sonora/mediastore'),
  });

  final AudioMetadataService metadataService;
  final ArtworkCacheService artworkCacheService;
  final MethodChannel channel;

  /// Requests the appropriate audio permission depending on Android API level.
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;

    // Android 13+ (API 33+) uses READ_MEDIA_AUDIO via Permission.audio
    var status = await Permission.audio.status;
    if (status.isGranted) return true;

    status = await Permission.audio.request();
    if (status.isGranted) return true;

    // Fallback for Android 12 and below using storage permission
    var storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) return true;

    storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  /// Discovers audio items from the Android MediaStore and parses audio metadata.
  Future<List<ExtractedScanItem>> scanMediaStore() async {
    if (!Platform.isAndroid) return [];

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      throw const ScanPermissionDeniedException(
        'Audio media permission is required to index device music.',
      );
    }

    final rawList = await channel.invokeMethod<List<dynamic>>(
      'queryAudioTracks',
    );
    if (rawList == null || rawList.isEmpty) return [];

    final items = <ExtractedScanItem>[];

    for (final raw in rawList) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);

      final id = map['id']?.toString() ?? '';
      final contentUri = map['contentUri']?.toString() ?? '';
      final filePath = map['filePath']?.toString() ?? '';
      final titleFromStore = map['title']?.toString() ?? '';
      final artistFromStore = map['artist']?.toString();
      final albumFromStore = map['album']?.toString();
      final durationMs = (map['duration'] as num?)?.toInt() ?? 0;
      final fileSizeBytes = (map['size'] as num?)?.toInt() ?? 0;
      final year = (map['year'] as num?)?.toInt();
      final trackNumber = (map['trackNumber'] as num?)?.toInt();

      final ext = p.extension(filePath).toLowerCase().replaceAll('.', '');
      final isSupported =
          metadataService.isSupportedAudioFile(filePath) ||
          ['mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg', 'opus'].contains(ext);

      if (!isSupported && ext.isNotEmpty) continue;

      // Extract deeper audio metadata and embedded artwork if file is accessible
      String? artworkPath;
      int? bitrateKbps;
      int? sampleRateHz;
      int? bitDepth;
      String title = titleFromStore;
      String? artist =
          (artistFromStore != null && artistFromStore != '<unknown>')
          ? artistFromStore
          : null;
      String? album = (albumFromStore != null && albumFromStore != '<unknown>')
          ? albumFromStore
          : null;

      final localFile = File(filePath);
      if (await localFile.exists()) {
        try {
          final meta = await metadataService.extractMetadata(
            localFile,
            extractArtwork: true,
          );
          if (meta.title.isNotEmpty && title.isEmpty) {
            title = meta.title;
          }
          artist ??= meta.artist;
          album ??= meta.album;
          bitrateKbps = meta.bitrateKbps;
          sampleRateHz = meta.sampleRateHz;
          bitDepth = meta.bitDepth;

          if (meta.artworkBytes != null && meta.artworkBytes!.isNotEmpty) {
            artworkPath = await artworkCacheService.saveArtworkBytes(
              '${album ?? title}_$artist',
              meta.artworkBytes,
            );
          }
        } catch (_) {
          // If metadata extraction fails on a file, keep the MediaStore provided tags
        }
      }

      items.add(
        ExtractedScanItem(
          id: 'android_$id',
          sourceUri: contentUri.isNotEmpty ? contentUri : filePath,
          filePath: filePath,
          title: title.isNotEmpty
              ? title
              : (p.basenameWithoutExtension(filePath)),
          artist: artist,
          album: album,
          duration: Duration(milliseconds: durationMs),
          fileExtension: ext.isNotEmpty ? ext : 'mp3',
          fileSizeBytes: fileSizeBytes,
          bitrateKbps: bitrateKbps,
          sampleRateHz: sampleRateHz,
          bitDepth: bitDepth,
          trackNumber: trackNumber,
          year: year,
          artworkPath: artworkPath,
          platformSource: 'android_mediastore',
        ),
      );
    }

    return items;
  }
}

class ExtractedScanItem {
  const ExtractedScanItem({
    required this.id,
    required this.sourceUri,
    required this.filePath,
    required this.title,
    this.artist,
    this.album,
    this.albumArtist,
    required this.duration,
    required this.fileExtension,
    required this.fileSizeBytes,
    this.bitrateKbps,
    this.sampleRateHz,
    this.bitDepth,
    this.trackNumber,
    this.discNumber,
    this.year,
    this.genre,
    this.artworkPath,
    required this.platformSource,
  });

  final String id;
  final String sourceUri;
  final String filePath;
  final String title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final Duration duration;
  final String fileExtension;
  final int fileSizeBytes;
  final int? bitrateKbps;
  final int? sampleRateHz;
  final int? bitDepth;
  final int? trackNumber;
  final int? discNumber;
  final int? year;
  final String? genre;
  final String? artworkPath;
  final String platformSource;
}

class ScanPermissionDeniedException implements Exception {
  const ScanPermissionDeniedException(this.message);
  final String message;

  @override
  String toString() => message;
}
