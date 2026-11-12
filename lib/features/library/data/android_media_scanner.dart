import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import '../../../core/services/artwork_cache_service.dart';
import '../../../core/services/audio_metadata_service.dart';
import 'music_file_filter.dart';

/// Service responsible for scanning the Android MediaStore audio index.
class AndroidMediaScanner {
  AndroidMediaScanner({
    this.metadataService = const AudioMetadataService(),
    this.artworkCacheService = const ArtworkCacheService(),
    this.channel = const MethodChannel('com.mrhrafi3.sonora/mediastore'),
    MusicFileFilter? fileFilter,
  }) : fileFilter = fileFilter ?? MusicFileFilter();

  final AudioMetadataService metadataService;
  final ArtworkCacheService artworkCacheService;
  final MethodChannel channel;
  final MusicFileFilter fileFilter;

  static bool _notificationPromptedThisSession = false;

  /// Queries the running Android API level (e.g. 30, 31, 33, 34).
  Future<int?> getAndroidSdkInt() async {
    if (!Platform.isAndroid) return null;
    try {
      return await channel.invokeMethod<int>('getSdkInt');
    } catch (_) {
      return null;
    }
  }

  /// Requests the appropriate audio permission depending on Android API level.
  ///
  /// Throws [ScanPermissionDeniedException] with [isPermanentlyDenied] when denied.
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;

    final sdkInt = await getAndroidSdkInt();

    if (sdkInt == null || sdkInt >= 33) {
      // Android 13+ (API 33+) strictly uses READ_MEDIA_AUDIO.
      var status = await Permission.audio.status;
      if (status.isGranted) return true;

      if (!status.isPermanentlyDenied) {
        status = await Permission.audio.request();
        if (status.isGranted) return true;
      }

      if (sdkInt != null && sdkInt >= 33) {
        if (status.isPermanentlyDenied) {
          throw const ScanPermissionDeniedException(
            'Audio permission was permanently denied. Enable Music & Audio access in Android Settings.',
            isPermanentlyDenied: true,
          );
        }
        return false;
      }

      // Fallback only if SDK level could not be determined (e.g. legacy/test).
      var storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) return true;
      if (!storageStatus.isPermanentlyDenied) {
        storageStatus = await Permission.storage.request();
        if (storageStatus.isGranted) return true;
      }
      if (status.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
        throw const ScanPermissionDeniedException(
          'Storage permission was permanently denied. Enable access in Android Settings.',
          isPermanentlyDenied: true,
        );
      }
      return false;
    }

    // Android 12 and below (API <= 32) use READ_EXTERNAL_STORAGE.
    var storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) return true;
    if (!storageStatus.isPermanentlyDenied) {
      storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) return true;
    }
    if (storageStatus.isPermanentlyDenied) {
      throw const ScanPermissionDeniedException(
        'Storage permission was permanently denied. Enable Storage access in Android Settings.',
        isPermanentlyDenied: true,
      );
    }
    return false;
  }

  /// Best-effort runtime notification permission request for Android 13+ (API 33+)
  /// so system media controls appear in the notification shade and lock screen.
  Future<void> ensureNotificationPermissionIfNeeded() async {
    if (!Platform.isAndroid || _notificationPromptedThisSession) return;
    final sdkInt = await getAndroidSdkInt();
    if (sdkInt != null && sdkInt < 33) return;

    _notificationPromptedThisSession = true;
    try {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        await Permission.notification.request();
      }
    } catch (_) {
      // Never block scanning or playback if notification permission prompt fails.
    }
  }

  /// Discovers audio items from the Android MediaStore and parses audio metadata
  /// on background isolates without blocking the UI thread.
  Future<List<ExtractedScanItem>> scanMediaStore() async {
    if (!Platform.isAndroid) return [];

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      throw const ScanPermissionDeniedException(
        'Audio media permission is required to index device music.',
      );
    }

    await ensureNotificationPermissionIfNeeded();

    final rawList = await channel.invokeMethod<List<dynamic>>(
      'queryAudioTracks',
    );
    if (rawList == null || rawList.isEmpty) return [];

    // Filter candidate MediaStore entries before spawning isolate parsing.
    final rawCandidates = <_RawMediaStoreEntry>[];
    for (final raw in rawList) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final filePath = map['filePath']?.toString() ?? '';
      final displayName = map['displayName']?.toString() ?? '';
      final mimeType = map['mimeType']?.toString() ?? '';
      final durationMs = (map['duration'] as num?)?.toInt() ?? 0;
      final ext = _resolveExtension(filePath, displayName, mimeType);
      final isSupported =
          metadataService.isSupportedAudioFile(filePath) ||
          MusicFileFilter.supportedExtensions.contains(ext);

      if (!isSupported && ext.isNotEmpty) continue;

      // Filter out WhatsApp voice notes, Telegram audio, call recordings,
      // ringtones, alarms, notifications, hidden folders, and .nomedia files.
      if (fileFilter.isExcludedPath(
        filePath,
        displayName: displayName,
        durationMs: durationMs,
      )) {
        continue;
      }

      rawCandidates.add(
        _RawMediaStoreEntry(
          id: map['id']?.toString() ?? '',
          contentUri: map['contentUri']?.toString() ?? '',
          filePath: filePath,
          displayName: displayName,
          titleFromStore: map['title']?.toString() ?? '',
          artistFromStore: map['artist']?.toString(),
          albumFromStore: map['album']?.toString(),
          durationMs: durationMs,
          fileSizeBytes: (map['size'] as num?)?.toInt() ?? 0,
          year: (map['year'] as num?)?.toInt(),
          trackNumber: (map['trackNumber'] as num?)?.toInt(),
          ext: ext,
        ),
      );
    }

    if (rawCandidates.isEmpty) return [];

    // Prioritize standard Music directories (/Music/) over /Download/ and generic dirs
    rawCandidates.sort((a, b) {
      final scoreA = fileFilter.getPriorityScore(a.filePath);
      final scoreB = fileFilter.getPriorityScore(b.filePath);
      return scoreB.compareTo(scoreA);
    });

    // Deduplicate candidate tracks by canonical file path, contentUri, and normalized metadata
    final candidates = <_RawMediaStoreEntry>[];
    final seenPaths = <String>{};
    final seenContentUris = <String>{};
    final seenMetadataKeys = <String>{};

    for (final entry in rawCandidates) {
      final canonicalPath = entry.filePath.replaceAll('\\', '/').toLowerCase();
      if (canonicalPath.isNotEmpty && !seenPaths.add(canonicalPath)) {
        continue;
      }
      if (entry.contentUri.isNotEmpty &&
          !seenContentUris.add(entry.contentUri)) {
        continue;
      }

      // Avoid duplicate tracks with identical metadata and duration (within 1s)
      final title = entry.titleFromStore.trim().toLowerCase();
      final artist = (entry.artistFromStore ?? '').trim().toLowerCase();
      if (title.isNotEmpty && artist.isNotEmpty && artist != '<unknown>') {
        final durationBucket = (entry.durationMs / 1000).round();
        final metaKey = '$title::$artist::$durationBucket';
        if (!seenMetadataKeys.add(metaKey)) {
          continue;
        }
      }

      candidates.add(entry);
    }

    if (candidates.isEmpty) return [];

    // Offload synchronous file tag & artwork parsing to worker isolates in chunks.
    final items = <ExtractedScanItem>[];
    final writtenArtKeys = <String, String>{};
    const chunkSize = 25;

    for (var start = 0; start < candidates.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, candidates.length);
      final chunk = candidates.sublist(start, end);
      final paths = chunk.map((c) => c.filePath).toList(growable: false);

      final parsedBatch = await Isolate.run(
        () => _extractMetadataBatchInIsolate(paths),
      );

      for (var i = 0; i < chunk.length; i++) {
        final entry = chunk[i];
        final meta = parsedBatch[i];

        var title = entry.titleFromStore;
        String? artist =
            (entry.artistFromStore != null &&
                entry.artistFromStore != '<unknown>')
            ? entry.artistFromStore
            : null;
        String? album =
            (entry.albumFromStore != null &&
                entry.albumFromStore != '<unknown>')
            ? entry.albumFromStore
            : null;
        var durationMs = entry.durationMs;
        int? bitrateKbps;
        int? sampleRateHz;
        int? bitDepth;
        String? artworkPath;

        if (meta != null) {
          if (meta.title.isNotEmpty && title.isEmpty) {
            title = meta.title;
          }
          artist ??= meta.artist;
          album ??= meta.album;
          if (durationMs <= 0 && meta.durationMs > 0) {
            durationMs = meta.durationMs;
          }
          bitrateKbps = meta.bitrateKbps;
          sampleRateHz = meta.sampleRateHz;
          bitDepth = meta.bitDepth;

          if (meta.artworkBytes != null && meta.artworkBytes!.isNotEmpty) {
            final artKey = '${album ?? title}_$artist';
            if (writtenArtKeys.containsKey(artKey)) {
              artworkPath = writtenArtKeys[artKey];
            } else {
              artworkPath = await artworkCacheService.saveArtworkBytes(
                artKey,
                meta.artworkBytes,
                prune: false,
              );
              if (artworkPath != null) {
                writtenArtKeys[artKey] = artworkPath;
              }
            }
          }
        }

        final fallbackName = entry.filePath.isNotEmpty
            ? p.basenameWithoutExtension(entry.filePath)
            : p.basenameWithoutExtension(entry.displayName);

        items.add(
          ExtractedScanItem(
            id: 'android_${entry.id}',
            sourceUri: entry.contentUri.isNotEmpty
                ? entry.contentUri
                : entry.filePath,
            filePath: entry.filePath,
            title: title.isNotEmpty ? title : fallbackName,
            artist: artist,
            album: album,
            duration: Duration(milliseconds: durationMs),
            fileExtension: entry.ext.isNotEmpty ? entry.ext : 'mp3',
            fileSizeBytes: entry.fileSizeBytes,
            bitrateKbps: bitrateKbps,
            sampleRateHz: sampleRateHz,
            bitDepth: bitDepth,
            trackNumber: (entry.trackNumber != null && entry.trackNumber! > 0)
                ? entry.trackNumber
                : null,
            year: (entry.year != null && entry.year! > 0) ? entry.year : null,
            artworkPath: artworkPath,
            platformSource: 'android_mediastore',
          ),
        );
      }
    }

    if (writtenArtKeys.isNotEmpty) {
      await artworkCacheService.pruneDiskCache();
    }

    return items;
  }

  static String _resolveExtension(
    String filePath,
    String displayName,
    String mimeType,
  ) {
    final fromPath = p.extension(filePath).toLowerCase().replaceAll('.', '');
    if (fromPath.isNotEmpty) return fromPath;

    final fromDisplay = p
        .extension(displayName)
        .toLowerCase()
        .replaceAll('.', '');
    if (fromDisplay.isNotEmpty) return fromDisplay;

    return switch (mimeType.toLowerCase()) {
      'audio/mpeg' => 'mp3',
      'audio/flac' || 'audio/x-flac' => 'flac',
      'audio/wav' || 'audio/x-wav' || 'audio/vnd.wave' => 'wav',
      'audio/mp4' || 'audio/m4a' || 'audio/x-m4a' => 'm4a',
      'audio/aac' || 'audio/aac-adts' => 'aac',
      'audio/ogg' || 'application/ogg' => 'ogg',
      'audio/opus' => 'opus',
      _ => '',
    };
  }
}

class _RawMediaStoreEntry {
  const _RawMediaStoreEntry({
    required this.id,
    required this.contentUri,
    required this.filePath,
    required this.displayName,
    required this.titleFromStore,
    this.artistFromStore,
    this.albumFromStore,
    required this.durationMs,
    required this.fileSizeBytes,
    this.year,
    this.trackNumber,
    required this.ext,
  });

  final String id;
  final String contentUri;
  final String filePath;
  final String displayName;
  final String titleFromStore;
  final String? artistFromStore;
  final String? albumFromStore;
  final int durationMs;
  final int fileSizeBytes;
  final int? year;
  final int? trackNumber;
  final String ext;
}

class _IsolateMetaResult {
  const _IsolateMetaResult({
    required this.title,
    this.artist,
    this.album,
    required this.durationMs,
    this.bitrateKbps,
    this.sampleRateHz,
    this.bitDepth,
    this.artworkBytes,
  });

  final String title;
  final String? artist;
  final String? album;
  final int durationMs;
  final int? bitrateKbps;
  final int? sampleRateHz;
  final int? bitDepth;
  final Uint8List? artworkBytes;
}

Future<List<_IsolateMetaResult?>> _extractMetadataBatchInIsolate(
  List<String> filePaths,
) async {
  const service = AudioMetadataService();
  final results = <_IsolateMetaResult?>[];
  for (final path in filePaths) {
    if (path.isEmpty) {
      results.add(null);
      continue;
    }
    final file = File(path);
    if (!file.existsSync()) {
      results.add(null);
      continue;
    }
    try {
      final meta = await service.extractMetadata(file, extractArtwork: true);
      results.add(
        _IsolateMetaResult(
          title: meta.title,
          artist: meta.artist,
          album: meta.album,
          durationMs: meta.duration.inMilliseconds,
          bitrateKbps: meta.bitrateKbps,
          sampleRateHz: meta.sampleRateHz,
          bitDepth: meta.bitDepth,
          artworkBytes: meta.artworkBytes,
        ),
      );
    } catch (_) {
      results.add(null);
    }
  }
  return results;
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
  const ScanPermissionDeniedException(
    this.message, {
    this.isPermanentlyDenied = false,
  });

  final String message;
  final bool isPermanentlyDenied;

  @override
  String toString() => message;
}
