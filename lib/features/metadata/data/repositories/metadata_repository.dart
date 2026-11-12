import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/artwork_cache_service.dart';
import '../../domain/models/artwork_match.dart';
import '../../domain/models/lyrics_model.dart';
import '../datasources/lrclib_client.dart';
import '../datasources/online_artwork_client.dart';

/// Repository managing online metadata lookup, local SQLite persistence,
/// disk caching, and deduplication for lyrics and album artwork.
class MetadataRepository {
  MetadataRepository({
    required this.database,
    required this.artworkCacheService,
    LrclibClient? lrclibClient,
    OnlineArtworkClient? artworkClient,
  }) : lrclibClient = lrclibClient ?? LrclibClient(),
       artworkClient = artworkClient ?? OnlineArtworkClient();

  final AppDatabase database;
  final ArtworkCacheService artworkCacheService;
  final LrclibClient lrclibClient;
  final OnlineArtworkClient artworkClient;

  /// In-flight deduplication maps to prevent redundant simultaneous network requests.
  final Map<String, Future<String?>> _inFlightArtworkFetches = {};
  final Map<String, Future<List<LrclibSearchResult>>> _inFlightLyricsSearches =
      {};

  /// Negative cache timestamps (query key -> expiry timestamp) to avoid spamming failed lookups.
  final Map<String, DateTime> _artworkNegativeCache = {};
  static const Duration _negativeCacheDuration = Duration(minutes: 5);

  /// Stored uncertain matches awaiting explicit user selection.
  final Map<String, List<ArtworkMatch>> _uncertainArtworkMatches = {};

  // ==========================================
  // Lyrics Operations
  // ==========================================

  /// Returns locally cached/persisted lyrics for [trackId], if any.
  Future<TrackLyricsData?> getCachedLyrics(String trackId) async {
    final row = await database.getLyricsForTrack(trackId);
    if (row == null) return null;
    return _mapRowToLyrics(row);
  }

  /// Watches persistent lyrics for [trackId]. Emits offline whenever database updates.
  Stream<TrackLyricsData?> watchLyrics(String trackId) {
    return database.watchLyricsForTrack(trackId).map((row) {
      if (row == null) return null;
      return _mapRowToLyrics(row);
    });
  }

  /// Searches LRCLIB for candidate lyrics matching track metadata.
  Future<List<LrclibSearchResult>> searchOnlineLyrics({
    required String trackId,
    required String title,
    required String artist,
    String? album,
    Duration? duration,
  }) async {
    final searchKey =
        '${title.toLowerCase().trim()}__${artist.toLowerCase().trim()}';
    if (_inFlightLyricsSearches.containsKey(searchKey)) {
      return _inFlightLyricsSearches[searchKey]!;
    }

    final future = lrclibClient.searchLyrics(
      title: title,
      artist: artist,
      album: album,
      duration: duration,
    );

    _inFlightLyricsSearches[searchKey] = future;
    try {
      final results = await future;
      return results;
    } finally {
      _inFlightLyricsSearches.remove(searchKey);
    }
  }

  /// Attempts exact match query on LRCLIB and automatically saves only if confidence is exact.
  /// Never auto-applies uncertain lyrics.
  Future<TrackLyricsData?> fetchAndSaveExactLyrics({
    required String trackId,
    required String title,
    required String artist,
    String? album,
    Duration? duration,
  }) async {
    final exact = await lrclibClient.getExactLyrics(
      title: title,
      artist: artist,
      album: album,
      duration: duration,
    );

    if (exact != null &&
        exact.isExactMatch(
          targetTitle: title,
          targetArtist: artist,
          targetDuration: duration,
        )) {
      await saveLyrics(
        trackId: trackId,
        plainLyrics: exact.plainLyrics,
        syncedLyrics: exact.syncedLyrics,
        source: 'lrclib_exact',
      );
      return getCachedLyrics(trackId);
    }

    return null;
  }

  /// Persists lyrics to the local SQLite database for offline viewing.
  Future<void> saveLyrics({
    required String trackId,
    String? plainLyrics,
    String? syncedLyrics,
    String source = 'lrclib',
  }) async {
    await database.saveLyrics(
      trackId: trackId,
      plainLyrics: plainLyrics,
      syncedLyrics: syncedLyrics,
      source: source,
    );
  }

  /// Removes persisted lyrics for [trackId].
  Future<void> removeLyrics(String trackId) async {
    await database.deleteLyricsForTrack(trackId);
  }

  TrackLyricsData _mapRowToLyrics(TrackLyric row) {
    return TrackLyricsData(
      trackId: row.trackId,
      plainLyrics: row.plainLyrics,
      syncedLyrics: row.syncedLyrics,
      source: row.source,
      updatedAt: row.updatedAt,
    );
  }

  // ==========================================
  // Album Artwork Operations
  // ==========================================

  /// Builds a deterministic, normalized key for an album (artist + album name).
  String getAlbumKey(String artist, String album) {
    final cleanArtist = ArtworkMatch.normalize(artist);
    final cleanAlbum = ArtworkMatch.normalize(album);
    return '${cleanArtist}__$cleanAlbum';
  }

  /// Resolves album artwork following strict priority order:
  /// 1. Existing embedded artwork in the audio file.
  /// 2. Previously downloaded local artwork cache or existing album tracks in DB.
  /// 3. Online artwork lookup (automatic only when high confidence >= 0.85).
  ///
  /// Never overwrites existing embedded artwork.
  Future<String?> resolveAlbumArtwork({
    required String artist,
    required String album,
    String? trackTitle,
    String? currentTrackArtworkPath,
    bool allowOnlineFetch = true,
  }) async {
    // -----------------------------------------------------------------
    // Priority 1: Existing embedded artwork in current track
    // -----------------------------------------------------------------
    if (currentTrackArtworkPath != null && currentTrackArtworkPath.isNotEmpty) {
      if (File(currentTrackArtworkPath).existsSync()) {
        return currentTrackArtworkPath;
      }
    }

    final albumKey = getAlbumKey(artist, album);

    // -----------------------------------------------------------------
    // Priority 2: Previously downloaded local artwork cache
    // -----------------------------------------------------------------
    // A) Check Drift AlbumArtworks table
    final dbArtwork = await database.getArtworkForAlbum(albumKey);
    if (dbArtwork != null && dbArtwork.artworkPath.isNotEmpty) {
      if (File(dbArtwork.artworkPath).existsSync()) {
        return dbArtwork.artworkPath;
      }
    }

    // B) Check disk cache
    final diskCachedPath = await artworkCacheService.getCachedArtworkPath(
      'album_$albumKey',
    );
    if (diskCachedPath != null && File(diskCachedPath).existsSync()) {
      // Re-link in DB
      await database.saveAlbumArtwork(
        albumKey: albumKey,
        album: album,
        artist: artist,
        artworkPath: diskCachedPath,
        source: 'cache',
      );
      return diskCachedPath;
    }

    // C) Check if any track from the same album already has embedded artwork
    final allTracks = await database.getAllTracks();
    for (final t in allTracks) {
      if (t.artist.toLowerCase().trim() == artist.toLowerCase().trim() &&
          t.album.toLowerCase().trim() == album.toLowerCase().trim() &&
          t.artworkPath != null &&
          t.artworkPath!.isNotEmpty) {
        if (File(t.artworkPath!).existsSync()) {
          // Found embedded artwork from sibling track in the same album
          await database.saveAlbumArtwork(
            albumKey: albumKey,
            album: album,
            artist: artist,
            artworkPath: t.artworkPath!,
            source: 'embedded_sibling',
          );
          return t.artworkPath!;
        }
      }
    }

    if (!allowOnlineFetch) return null;

    // Check negative cache cooldown
    final negativeExpiry = _artworkNegativeCache[albumKey];
    if (negativeExpiry != null && DateTime.now().isBefore(negativeExpiry)) {
      return null;
    }

    // Deduplicate in-flight requests
    if (_inFlightArtworkFetches.containsKey(albumKey)) {
      return _inFlightArtworkFetches[albumKey]!;
    }

    final future = _executeOnlineArtworkFetch(
      albumKey: albumKey,
      artist: artist,
      album: album,
      trackTitle: trackTitle,
    );

    _inFlightArtworkFetches[albumKey] = future;
    try {
      final result = await future;
      return result;
    } finally {
      _inFlightArtworkFetches.remove(albumKey);
    }
  }

  Future<String?> _executeOnlineArtworkFetch({
    required String albumKey,
    required String artist,
    required String album,
    String? trackTitle,
  }) async {
    try {
      final matches = await artworkClient.searchArtwork(
        artist: artist,
        album: album,
        trackTitle: trackTitle,
      );

      if (matches.isEmpty) {
        _artworkNegativeCache[albumKey] = DateTime.now().add(
          _negativeCacheDuration,
        );
        return null;
      }

      final bestMatch = matches.first;

      // Strictly verify confidence before automatic download
      if (bestMatch.isHighConfidence) {
        final downloadedPath = await _downloadAndPersistArtwork(
          albumKey: albumKey,
          artist: artist,
          album: album,
          match: bestMatch,
        );
        return downloadedPath;
      } else {
        // Multiple uncertain matches exist: store for manual user selection
        _uncertainArtworkMatches[albumKey] = matches;
        return null;
      }
    } catch (e) {
      debugPrint('[MetadataRepository] _executeOnlineArtworkFetch error: $e');
      _artworkNegativeCache[albumKey] = DateTime.now().add(
        _negativeCacheDuration,
      );
      return null;
    }
  }

  /// Downloads and caches artwork for an album, then updates matching tracks in SQLite.
  /// Never overwrites existing embedded artwork on tracks.
  Future<String?> _downloadAndPersistArtwork({
    required String albumKey,
    required String artist,
    required String album,
    required ArtworkMatch match,
  }) async {
    final Uint8List? bytes = await artworkClient.downloadImageBytes(
      match.imageUrl,
    );
    if (bytes == null || bytes.isEmpty) return null;

    final cachedPath = await artworkCacheService.saveArtworkBytes(
      'album_$albumKey',
      bytes,
    );
    if (cachedPath == null) return null;

    // 1. Record album association
    await database.saveAlbumArtwork(
      albumKey: albumKey,
      album: album,
      artist: artist,
      artworkPath: cachedPath,
      source: match.provider.name,
    );

    // 2. Update tracks of this album that currently lack artwork
    // (Preserves existing embedded artwork)
    await database.updateAlbumTracksArtwork(
      artist: artist,
      album: album,
      artworkPath: cachedPath,
    );

    _uncertainArtworkMatches.remove(albumKey);
    return cachedPath;
  }

  /// Returns any pending uncertain matches stored for an album.
  List<ArtworkMatch> getUncertainMatches(String albumKey) {
    return _uncertainArtworkMatches[albumKey] ?? const [];
  }

  /// Allows explicit user selection of an artwork match (for uncertain matches or manual override).
  Future<String?> applySelectedArtwork({
    required String artist,
    required String album,
    required ArtworkMatch match,
  }) async {
    final albumKey = getAlbumKey(artist, album);
    return _downloadAndPersistArtwork(
      albumKey: albumKey,
      artist: artist,
      album: album,
      match: match,
    );
  }

  /// Clears in-flight or cached state.
  void dispose() {
    lrclibClient.close();
    artworkClient.close();
  }
}
