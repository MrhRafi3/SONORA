import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Tracks, Playlists, PlaylistTracks])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? _openConnection()) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return NativeDatabase.memory();
    }
    return driftDatabase(name: 'sonora_db');
  }

  // --- Track Operations ---

  Stream<List<Track>> watchAllTracks({
    String sortBy = 'title',
    bool ascending = true,
  }) {
    final query = select(tracks)..where((tbl) => tbl.isAvailable.equals(true));

    switch (sortBy) {
      case 'artist':
        query.orderBy([
          (t) => OrderingTerm(
            expression: t.artist.collate(Collate.noCase),
            mode: ascending ? OrderingMode.asc : OrderingMode.desc,
          ),
          (t) => OrderingTerm(
            expression: t.title.collate(Collate.noCase),
            mode: OrderingMode.asc,
          ),
        ]);
      case 'album':
        query.orderBy([
          (t) => OrderingTerm(
            expression: t.album.collate(Collate.noCase),
            mode: ascending ? OrderingMode.asc : OrderingMode.desc,
          ),
          (t) =>
              OrderingTerm(expression: t.trackNumber, mode: OrderingMode.asc),
        ]);
      case 'dateAdded':
        query.orderBy([
          (t) => OrderingTerm(
            expression: t.dateAdded,
            mode: ascending ? OrderingMode.asc : OrderingMode.desc,
          ),
        ]);
      case 'duration':
        query.orderBy([
          (t) => OrderingTerm(
            expression: t.durationMs,
            mode: ascending ? OrderingMode.asc : OrderingMode.desc,
          ),
        ]);
      case 'title':
      default:
        query.orderBy([
          (t) => OrderingTerm(
            expression: t.title.collate(Collate.noCase),
            mode: ascending ? OrderingMode.asc : OrderingMode.desc,
          ),
        ]);
    }

    return query.watch();
  }

  Future<List<Track>> getAllTracks() async {
    return (select(tracks)..where((tbl) => tbl.isAvailable.equals(true))).get();
  }

  Future<Track?> getTrackById(String id) {
    return (select(tracks)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<Track?> getTrackBySourceUri(String sourceUri) {
    return (select(
      tracks,
    )..where((t) => t.sourceUri.equals(sourceUri))).getSingleOrNull();
  }

  Future<int> insertTrack(TracksCompanion entry) {
    return into(tracks).insertOnConflictUpdate(entry);
  }

  Future<void> batchInsertTracks(List<TracksCompanion> entries) {
    return batch((batch) {
      batch.insertAllOnConflictUpdate(tracks, entries);
    });
  }

  Future<int> setFavorite(String id, bool isFavorite) {
    return (update(tracks)..where((t) => t.id.equals(id))).write(
      TracksCompanion(isFavorite: Value(isFavorite)),
    );
  }

  Future<List<Track>> searchTracks(String queryTerm) {
    final term = '%$queryTerm%';
    return (select(tracks)
          ..where(
            (t) =>
                t.title.like(term) |
                t.artist.like(term) |
                t.album.like(term) |
                t.genre.like(term),
          )
          ..orderBy([
            (t) => OrderingTerm(expression: t.title.collate(Collate.noCase)),
          ]))
        .get();
  }

  Stream<List<Track>> watchFavoriteTracks() {
    return (select(tracks)
          ..where((t) => t.isFavorite.equals(true) & t.isAvailable.equals(true))
          ..orderBy([
            (t) => OrderingTerm(expression: t.title.collate(Collate.noCase)),
          ]))
        .watch();
  }

  Future<int> deleteTrack(String id) {
    return (delete(tracks)..where((t) => t.id.equals(id))).go();
  }

  Future<int> clearAllTracks() {
    return delete(tracks).go();
  }

  // --- Playlist Operations ---

  Stream<List<Playlist>> watchAllPlaylists() {
    return (select(
      playlists,
    )..orderBy([(p) => OrderingTerm.desc(p.updatedAt)])).watch();
  }

  Future<int> createPlaylist(String id, String name) {
    final now = DateTime.now();
    return into(playlists).insert(
      PlaylistsCompanion.insert(
        id: id,
        name: name,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<int> deletePlaylist(String id) {
    return (delete(playlists)..where((p) => p.id.equals(id))).go();
  }

  Future<void> addTrackToPlaylist(
    String playlistId,
    String trackId,
    int order,
  ) {
    return into(playlistTracks).insertOnConflictUpdate(
      PlaylistTracksCompanion.insert(
        playlistId: playlistId,
        trackId: trackId,
        sortOrder: order,
      ),
    );
  }

  Future<List<Track>> getTracksForPlaylist(String playlistId) {
    final query =
        select(tracks).join([
            innerJoin(
              playlistTracks,
              playlistTracks.trackId.equalsExp(tracks.id),
            ),
          ])
          ..where(playlistTracks.playlistId.equals(playlistId))
          ..orderBy([OrderingTerm.asc(playlistTracks.sortOrder)]);

    return query.map((row) => row.readTable(tracks)).get();
  }

  Stream<List<Track>> watchTracksForPlaylist(String playlistId) {
    final query =
        select(tracks).join([
            innerJoin(
              playlistTracks,
              playlistTracks.trackId.equalsExp(tracks.id),
            ),
          ])
          ..where(playlistTracks.playlistId.equals(playlistId))
          ..orderBy([OrderingTerm.asc(playlistTracks.sortOrder)]);

    return query.map((row) => row.readTable(tracks)).watch();
  }

  Future<int> removeTrackFromPlaylist(String playlistId, String trackId) {
    return (delete(playlistTracks)..where(
          (pt) => pt.playlistId.equals(playlistId) & pt.trackId.equals(trackId),
        ))
        .go();
  }

  Future<void> reorderPlaylistTracks(
    String playlistId,
    List<String> trackIdsInOrder,
  ) async {
    await transaction(() async {
      for (var i = 0; i < trackIdsInOrder.length; i++) {
        await (update(playlistTracks)..where(
              (pt) =>
                  pt.playlistId.equals(playlistId) &
                  pt.trackId.equals(trackIdsInOrder[i]),
            ))
            .write(PlaylistTracksCompanion(sortOrder: Value(i)));
      }
      await (update(playlists)..where((p) => p.id.equals(playlistId))).write(
        PlaylistsCompanion(updatedAt: Value(DateTime.now())),
      );
    });
  }

  Future<int> renamePlaylist(String playlistId, String newName) {
    return (update(playlists)..where((p) => p.id.equals(playlistId))).write(
      PlaylistsCompanion(
        name: Value(newName),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Stream<List<Track>> watchRecentlyAddedTracks({int limit = 20}) {
    return (select(tracks)
          ..where((tbl) => tbl.isAvailable.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.dateAdded)])
          ..limit(limit))
        .watch();
  }
}
