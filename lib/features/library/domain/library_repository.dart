import 'entities.dart';

/// Clean Architecture repository contract for the SONORA offline music library.
abstract class MusicLibraryRepository {
  Stream<List<AudioTrack>> watchTracks({
    String sortBy = 'title',
    bool ascending = true,
  });

  Future<List<AudioTrack>> getTracks();

  Future<AudioTrack?> getTrackById(String id);

  Future<List<AudioTrack>> searchTracks(String query);

  Stream<List<AudioTrack>> watchFavorites();

  Future<void> toggleFavorite(String trackId, bool isFavorite);

  Future<List<AudioAlbum>> getAlbums();

  Future<List<AudioArtist>> getArtists();

  Stream<List<AudioPlaylist>> watchPlaylists();

  Future<AudioPlaylist> createPlaylist(String name);

  Future<void> deletePlaylist(String id);

  Future<void> addTrackToPlaylist(String playlistId, String trackId);

  Future<List<AudioTrack>> getTracksForPlaylist(String playlistId);

  Future<ScanSummary> scanAndroidMediaStore();

  Future<ScanSummary> importIosAudioFiles();

  Future<void> deleteTrack(String id);
}

