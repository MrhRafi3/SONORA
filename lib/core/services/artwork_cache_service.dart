import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Service responsible for managing cached album artwork on local disk and in-memory.
class ArtworkCacheService {
  const ArtworkCacheService({this.customCacheDir});

  /// Optional custom cache directory, primarily for testing or sandboxed storage.
  final Directory? customCacheDir;

  /// Default upper disk limit for cached artwork (150 MB).
  static const int defaultMaxDiskBytes = 150 * 1024 * 1024;

  /// Max entries retained in memory cache.
  static const int maxMemoryEntries = 500;

  /// Fast in-memory lookup cache to bypass file system stat overhead on rapid scrolling.
  static final Map<String, String> _memoryPathCache = {};

  Future<Directory> get _artworkDir async {
    if (customCacheDir != null) {
      if (!await customCacheDir!.exists()) {
        await customCacheDir!.create(recursive: true);
      }
      return customCacheDir!;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'sonora_artwork_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Generates a SHA-1 hash for a cache key.
  String hashKey(String cacheKey) {
    return sha1.convert(utf8.encode(cacheKey)).toString();
  }

  /// Caches image bytes to disk using a hash of the [cacheKey] (e.g. album name or track ID).
  ///
  /// Returns the absolute path of the cached image file, or null if [bytes] is empty.
  Future<String?> saveArtworkBytes(
    String cacheKey,
    Uint8List? bytes, {
    String extension = 'jpg',
    int maxDiskBytes = defaultMaxDiskBytes,
  }) async {
    if (bytes == null || bytes.isEmpty) return null;

    final dir = await _artworkDir;
    final hash = hashKey(cacheKey);
    final file = File(p.join(dir.path, '$hash.$extension'));

    if (await file.exists()) {
      _recordInMemoryCache(cacheKey, file.path);
      return file.path;
    }

    await file.writeAsBytes(bytes, flush: true);
    _recordInMemoryCache(cacheKey, file.path);

    // Asynchronously prune cache if it exceeds max size threshold
    await pruneDiskCache(maxBytes: maxDiskBytes);

    return file.path;
  }

  /// Checks if artwork for [cacheKey] is already cached in memory or on disk.
  Future<String?> getCachedArtworkPath(
    String cacheKey, {
    String extension = 'jpg',
  }) async {
    // 1. Fast in-memory check
    if (_memoryPathCache.containsKey(cacheKey)) {
      final cachedPath = _memoryPathCache[cacheKey]!;
      if (File(cachedPath).existsSync()) {
        return cachedPath;
      }
      _memoryPathCache.remove(cacheKey);
    }

    // 2. Disk check
    final dir = await _artworkDir;
    final hash = hashKey(cacheKey);
    final file = File(p.join(dir.path, '$hash.$extension'));
    if (await file.exists()) {
      _recordInMemoryCache(cacheKey, file.path);
      return file.path;
    }

    return null;
  }

  /// Calculates total bytes used by the on-disk artwork cache.
  Future<int> getDiskUsage() async {
    final dir = await _artworkDir;
    if (!await dir.exists()) return 0;

    int totalBytes = 0;
    try {
      await for (final entity in dir.list(
        recursive: false,
        followLinks: false,
      )) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }
    } catch (_) {}
    return totalBytes;
  }

  /// Prunes oldest cached files until disk usage drops below [maxBytes].
  Future<void> pruneDiskCache({int maxBytes = defaultMaxDiskBytes}) async {
    final dir = await _artworkDir;
    if (!await dir.exists()) return;

    try {
      final files = <File>[];
      int totalBytes = 0;

      await for (final entity in dir.list(
        recursive: false,
        followLinks: false,
      )) {
        if (entity is File) {
          files.add(entity);
          totalBytes += await entity.length();
        }
      }

      if (totalBytes <= maxBytes) return;

      // Sort files by last modified ascending (oldest first)
      final fileTimestamps = <File, DateTime>{};
      for (final f in files) {
        fileTimestamps[f] = await f.lastModified();
      }
      files.sort((a, b) => fileTimestamps[a]!.compareTo(fileTimestamps[b]!));

      for (final file in files) {
        if (totalBytes <= maxBytes) break;
        final size = await file.length();
        await file.delete();
        totalBytes -= size;
      }
    } catch (_) {}
  }

  void _recordInMemoryCache(String key, String path) {
    if (_memoryPathCache.length >= maxMemoryEntries) {
      _memoryPathCache.remove(_memoryPathCache.keys.first);
    }
    _memoryPathCache[key] = path;
  }

  /// Clears all cached artwork images from memory and disk.
  Future<void> clearCache() async {
    _memoryPathCache.clear();
    final dir = await _artworkDir;
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
