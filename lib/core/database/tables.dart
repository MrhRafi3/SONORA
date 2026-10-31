import 'package:drift/drift.dart';

/// Database table representing audio tracks in SONORA.
@TableIndex(name: 'idx_tracks_title', columns: {#title})
@TableIndex(name: 'idx_tracks_artist', columns: {#artist})
@TableIndex(name: 'idx_tracks_album', columns: {#album})
@TableIndex(name: 'idx_tracks_favorite', columns: {#isFavorite})
@TableIndex(name: 'idx_tracks_date_added', columns: {#dateAdded})
@TableIndex(name: 'idx_tracks_duration', columns: {#durationMs})
class Tracks extends Table {
  TextColumn get id => text()();
  TextColumn get sourceUri => text()();
  TextColumn get filePath => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get album => text()();
  TextColumn get albumArtist => text().nullable()();
  IntColumn get durationMs => integer()();
  TextColumn get fileExtension => text()();
  IntColumn get fileSizeBytes => integer()();
  IntColumn get bitrateKbps => integer().nullable()();
  IntColumn get sampleRateHz => integer().nullable()();
  IntColumn get bitDepth => integer().nullable()();
  IntColumn get trackNumber => integer().nullable()();
  IntColumn get discNumber => integer().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get genre => text().nullable()();
  TextColumn get artworkPath => text().nullable()();
  TextColumn get platformSource =>
      text().withDefault(const Constant('local'))();
  DateTimeColumn get dateAdded => dateTime()();
  DateTimeColumn get dateModified => dateTime().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Database table representing user playlists.
class Playlists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Junction table mapping tracks to playlists with ordering.
@TableIndex(
  name: 'idx_playlist_tracks_order',
  columns: {#playlistId, #sortOrder},
)
class PlaylistTracks extends Table {
  TextColumn get playlistId =>
      text().references(Playlists, #id, onDelete: KeyAction.cascade)();
  TextColumn get trackId =>
      text().references(Tracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column> get primaryKey => {playlistId, trackId};
}
