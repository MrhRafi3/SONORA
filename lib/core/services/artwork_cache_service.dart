import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Service responsible for managing cached album artwork on local disk.
class ArtworkCacheService {
  const ArtworkCacheService();

  Future<Directory> get _artworkDir async {
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
  }) async {
    if (bytes == null || bytes.isEmpty) return null;

    final dir = await _artworkDir;
    final hash = sha1.convert(utf8.encode(cacheKey)).toString();
    final file = File(p.join(dir.path, '$hash.$extension'));

    if (await file.exists()) {
      return file.path;
    }

    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Checks if artwork for [cacheKey] is already cached on disk.
  Future<String?> getCachedArtworkPath(
    String cacheKey, {
    String extension = 'jpg',
  }) async {
    final dir = await _artworkDir;
    final hash = sha1.convert(utf8.encode(cacheKey)).toString();
    final file = File(p.join(dir.path, '$hash.$extension'));
    return (await file.exists()) ? file.path : null;
  }

  /// Clears all cached artwork images from disk.
  Future<void> clearCache() async {
    final dir = await _artworkDir;
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
