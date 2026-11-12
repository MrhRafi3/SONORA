import 'dart:io';
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../domain/entities.dart';
import '../domain/library_repository.dart';
import 'android_media_scanner.dart';
import 'ios_file_importer.dart';
import 'music_file_filter.dart';

/// Production implementation of [MusicLibraryRepository] backed by Drift SQLite database.
class DriftLibraryRepository implements MusicLibraryRepository {
  DriftLibraryRepository({
    required this.database,
    AndroidMediaScanner? androidScanner,
    this.iosImporter = const IosFileImporter(),
    MusicFileFilter? fileFilter,
  }) : fileFilter = fileFilter ?? MusicFileFilter(),
       androidScanner = androidScanner ?? AndroidMediaScanner();

  final AppDatabase database;
  final AndroidMediaScanner androidScanner;
  final IosFileImporter iosImporter;
  final MusicFileFilter fileFilter;

  @override
  Stream<List<AudioTrack>> watchTracks({
    String sortBy = 'title',
    bool ascending = true,
  }) {
    return database
        .watchAllTracks(sortBy: sortBy, ascending: ascending)
        .map((rows) => rows.map(_mapToEntity).toList());
  }

  @override
  Future<List<AudioTrack>> getTracks() async {
    final rows = await database.getAllTracks();
    return rows.map(_mapToEntity).toList();
  }

  @override
  Future<AudioTrack?> getTrackById(String id) async {
    final row = await database.getTrackById(id);
    return row != null ? _mapToEntity(row) : null;
  }

  @override
  Future<List<AudioTrack>> searchTracks(String query) async {
    if (query.trim().isEmpty) return [];
    final rows = await database.searchTracks(query.trim());
    return rows.map(_mapToEntity).toList();
  }

  @override
  Stream<List<AudioTrack>> watchFavorites() {
    return database.watchFavoriteTracks().map(
      (rows) => rows.map(_mapToEntity).toList(),
    );
  }

  @override
  Future<void> toggleFavorite(String trackId, bool isFavorite) async {
    await database.setFavorite(trackId, isFavorite);
  }

  @override
  Future<List<AudioAlbum>> getAlbums() async {
    final tracks = await getTracks();
    final albumMap = <String, List<AudioTrack>>{};

    for (final track in tracks) {
      final key = '${track.displayAlbum}__${track.displayArtist}';
      albumMap.putIfAbsent(key, () => []).add(track);
    }

    return albumMap.entries.map((entry) {
      final albumTracks = entry.value;
      final first = albumTracks.first;
      String? artwork;
      for (final t in albumTracks) {
        if (t.artworkPath != null && t.artworkPath!.isNotEmpty) {
          artwork = t.artworkPath;
          break;
        }
      }

      return AudioAlbum(
        name: first.displayAlbum,
        artist: first.displayArtist,
        year: first.year,
        trackCount: albumTracks.length,
        artworkPath: artwork,
      );
    }).toList();
  }

  @override
  Future<List<AudioArtist>> getArtists() async {
    final tracks = await getTracks();
    final artistMap = <String, List<AudioTrack>>{};

    for (final track in tracks) {
      artistMap.putIfAbsent(track.displayArtist, () => []).add(track);
    }

    return artistMap.entries.map((entry) {
      final artistTracks = entry.value;
      final uniqueAlbums = artistTracks.map((t) => t.displayAlbum).toSet();

      return AudioArtist(
        name: entry.key,
        trackCount: artistTracks.length,
        albumCount: uniqueAlbums.length,
      );
    }).toList();
  }

  @override
  Stream<List<AudioPlaylist>> watchPlaylists() {
    return database.watchAllPlaylists().map((rows) {
      return rows.map((r) {
        return AudioPlaylist(
          id: r.id,
          name: r.name,
          createdAt: r.createdAt,
          updatedAt: r.updatedAt,
        );
      }).toList();
    });
  }

  @override
  Future<AudioPlaylist> createPlaylist(String name) async {
    final id = 'playlist_${DateTime.now().millisecondsSinceEpoch}';
    await database.createPlaylist(id, name.trim());
    final now = DateTime.now();
    return AudioPlaylist(
      id: id,
      name: name.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<void> deletePlaylist(String id) async {
    await database.deletePlaylist(id);
  }

  @override
  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    final existing = await database.getTracksForPlaylist(playlistId);
    await database.addTrackToPlaylist(playlistId, trackId, existing.length);
  }

  @override
  Future<List<AudioTrack>> getTracksForPlaylist(String playlistId) async {
    final rows = await database.getTracksForPlaylist(playlistId);
    return rows.map(_mapToEntity).toList();
  }

  @override
  Stream<List<AudioTrack>> watchTracksForPlaylist(String playlistId) {
    return database
        .watchTracksForPlaylist(playlistId)
        .map((rows) => rows.map(_mapToEntity).toList());
  }

  @override
  Future<void> removeTrackFromPlaylist(
    String playlistId,
    String trackId,
  ) async {
    await database.removeTrackFromPlaylist(playlistId, trackId);
  }

  @override
  Future<void> reorderPlaylistTracks(
    String playlistId,
    List<String> trackIdsInOrder,
  ) async {
    await database.reorderPlaylistTracks(playlistId, trackIdsInOrder);
  }

  @override
  Future<void> renamePlaylist(String playlistId, String newName) async {
    await database.renamePlaylist(playlistId, newName);
  }

  @override
  Stream<List<AudioTrack>> watchRecentlyAddedTracks({int limit = 20}) {
    return database
        .watchRecentlyAddedTracks(limit: limit)
        .map((rows) => rows.map(_mapToEntity).toList());
  }

  @override
  Future<ScanSummary> scanAndroidMediaStore() async {
    if (!Platform.isAndroid) {
      return const ScanSummary(
        scannedCount: 0,
        newlyAddedCount: 0,
        failedCount: 0,
        errorMessage:
            'Android MediaStore scanning is only supported on Android devices.',
      );
    }

    try {
      // Safely purge pre-existing non-music entries from SQLite index without deleting files
      await purgeNonMusicEntries();

      final scanItems = await androidScanner.scanMediaStore();
      final companions = scanItems.map(_mapScanItemToCompanion).toList();
      final stats = await database.reconcilePlatformTracks(
        platformSource: 'android_mediastore',
        scannedEntries: companions,
      );

      return ScanSummary(
        scannedCount: scanItems.length,
        newlyAddedCount: stats.newlyAddedCount,
        failedCount: 0,
      );
    } on ScanPermissionDeniedException catch (e) {
      return ScanSummary(
        scannedCount: 0,
        newlyAddedCount: 0,
        failedCount: 0,
        errorMessage: e.message,
        permissionPermanentlyDenied: e.isPermanentlyDenied,
      );
    } catch (e) {
      return ScanSummary(
        scannedCount: 0,
        newlyAddedCount: 0,
        failedCount: 1,
        errorMessage: e.toString(),
      );
    }
  }

  @override
  Future<int> purgeNonMusicEntries() async {
    return await database.purgeNonMusicTracks((track) {
      return fileFilter.isExcludedPath(
        track.filePath,
        displayName: track.title,
        durationMs: track.durationMs,
      );
    });
  }

  @override
  Future<ScanSummary> importIosAudioFiles() async {
    try {
      final rawImportedItems = await iosImporter.pickAndImportAudioFiles();
      if (rawImportedItems.isEmpty) {
        return const ScanSummary(
          scannedCount: 0,
          newlyAddedCount: 0,
          failedCount: 0,
        );
      }

      final importedItems = rawImportedItems
          .where(
            (item) => fileFilter.isMusicFile(
              item.filePath,
              displayName: item.title,
              durationMs: item.duration.inMilliseconds,
            ),
          )
          .toList();

      if (importedItems.isEmpty) {
        return const ScanSummary(
          scannedCount: 0,
          newlyAddedCount: 0,
          failedCount: 0,
        );
      }

      final companions = importedItems.map(_mapScanItemToCompanion).toList();
      await database.batchInsertTracks(companions);

      return ScanSummary(
        scannedCount: importedItems.length,
        newlyAddedCount: importedItems.length,
        failedCount: 0,
      );
    } catch (e) {
      return ScanSummary(
        scannedCount: 0,
        newlyAddedCount: 0,
        failedCount: 1,
        errorMessage: e.toString(),
      );
    }
  }

  @override
  Future<void> deleteTrack(String id) async {
    await database.deleteTrack(id);
  }

  // --- Entity & Companion Mappings ---

  AudioTrack _mapToEntity(Track row) {
    return AudioTrack(
      id: row.id,
      sourceUri: row.sourceUri,
      filePath: row.filePath,
      title: row.title,
      artist: row.artist.isNotEmpty ? row.artist : null,
      album: row.album.isNotEmpty ? row.album : null,
      albumArtist: row.albumArtist,
      duration: Duration(milliseconds: row.durationMs),
      fileExtension: row.fileExtension,
      fileSizeBytes: row.fileSizeBytes,
      bitrateKbps: row.bitrateKbps,
      sampleRateHz: row.sampleRateHz,
      bitDepth: row.bitDepth,
      trackNumber: row.trackNumber,
      discNumber: row.discNumber,
      year: row.year,
      genre: row.genre,
      artworkPath: row.artworkPath,
      platformSource: row.platformSource,
      dateAdded: row.dateAdded,
      dateModified: row.dateModified,
      isFavorite: row.isFavorite,
      isAvailable: row.isAvailable,
    );
  }

  TracksCompanion _mapScanItemToCompanion(ExtractedScanItem item) {
    return TracksCompanion.insert(
      id: item.id,
      sourceUri: item.sourceUri,
      filePath: item.filePath,
      title: item.title,
      artist: item.artist ?? '',
      album: item.album ?? '',
      albumArtist: Value(item.albumArtist),
      durationMs: item.duration.inMilliseconds,
      fileExtension: item.fileExtension,
      fileSizeBytes: item.fileSizeBytes,
      bitrateKbps: Value(item.bitrateKbps),
      sampleRateHz: Value(item.sampleRateHz),
      bitDepth: Value(item.bitDepth),
      trackNumber: Value(item.trackNumber),
      discNumber: Value(item.discNumber),
      year: Value(item.year),
      genre: Value(item.genre),
      artworkPath: Value(item.artworkPath),
      platformSource: Value(item.platformSource),
      dateAdded: DateTime.now(),
      isAvailable: const Value(true),
    );
  }
}
