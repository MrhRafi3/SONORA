import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../data/drift_library_repository.dart';
import '../domain/entities.dart';
import '../domain/library_repository.dart';
import '../domain/smart_playlist.dart';

/// Provider for the singleton Drift SQLite database instance.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Provider for the music library repository.
final musicLibraryRepositoryProvider = Provider<MusicLibraryRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftLibraryRepository(database: db);
});

/// Active sort column for the tracks list.
class LibrarySortNotifier extends Notifier<String> {
  @override
  String build() => 'title';

  void setSort(String sortBy) => state = sortBy;
}

final librarySortProvider = NotifierProvider<LibrarySortNotifier, String>(
  LibrarySortNotifier.new,
);

/// Sort ascending or descending.
class LibrarySortAscendingNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
  void setAscending(bool asc) => state = asc;
}

final librarySortAscendingProvider =
    NotifierProvider<LibrarySortAscendingNotifier, bool>(
      LibrarySortAscendingNotifier.new,
    );

/// Active format filter on tracks list.
class LibraryAudioFilterNotifier extends Notifier<LibraryAudioFilter> {
  @override
  LibraryAudioFilter build() => LibraryAudioFilter.all;

  void setFilter(LibraryAudioFilter filter) => state = filter;
}

final libraryAudioFilterProvider =
    NotifierProvider<LibraryAudioFilterNotifier, LibraryAudioFilter>(
      LibraryAudioFilterNotifier.new,
    );

/// Reactive stream of tracks matching the active sorting.
final tracksStreamProvider = StreamProvider<List<AudioTrack>>((ref) {
  final repo = ref.watch(musicLibraryRepositoryProvider);
  final sortBy = ref.watch(librarySortProvider);
  final ascending = ref.watch(librarySortAscendingProvider);
  return repo.watchTracks(sortBy: sortBy, ascending: ascending);
});

/// Filtered tracks provider combining sort + format filter.
final filteredTracksProvider = Provider<List<AudioTrack>>((ref) {
  final tracksAsync = ref.watch(tracksStreamProvider);
  final tracks = tracksAsync.asData?.value ?? [];
  final filter = ref.watch(libraryAudioFilterProvider);

  if (filter == LibraryAudioFilter.all) return tracks;
  return tracks.where(filter.matches).toList();
});

/// Smart playlist tracks provider.
final smartPlaylistTracksProvider =
    Provider.family<List<AudioTrack>, SmartPlaylistType>((ref, type) {
      final tracksAsync = ref.watch(tracksStreamProvider);
      final tracks = tracksAsync.asData?.value ?? [];
      return type.filter(tracks);
    });

/// Reactive stream of tracks for a specific custom playlist.
final playlistTracksStreamProvider =
    StreamProvider.family<List<AudioTrack>, String>((ref, playlistId) {
      final repo = ref.watch(musicLibraryRepositoryProvider);
      return repo.watchTracksForPlaylist(playlistId);
    });

/// Stream of recently added tracks.
final recentlyAddedTracksStreamProvider = StreamProvider<List<AudioTrack>>((
  ref,
) {
  final repo = ref.watch(musicLibraryRepositoryProvider);
  return repo.watchRecentlyAddedTracks(limit: 20);
});

/// Albums derived from real indexed tracks.
final albumsProvider = FutureProvider<List<AudioAlbum>>((ref) async {
  // Re-fetch whenever tracks stream updates
  ref.watch(tracksStreamProvider);
  final repo = ref.watch(musicLibraryRepositoryProvider);
  return repo.getAlbums();
});

/// Artists derived from real indexed tracks.
final artistsProvider = FutureProvider<List<AudioArtist>>((ref) async {
  ref.watch(tracksStreamProvider);
  final repo = ref.watch(musicLibraryRepositoryProvider);
  return repo.getArtists();
});

/// Reactive stream of playlists.
final playlistsStreamProvider = StreamProvider<List<AudioPlaylist>>((ref) {
  final repo = ref.watch(musicLibraryRepositoryProvider);
  return repo.watchPlaylists();
});

/// Reactive stream of favorite tracks.
final favoritesStreamProvider = StreamProvider<List<AudioTrack>>((ref) {
  final repo = ref.watch(musicLibraryRepositoryProvider);
  return repo.watchFavorites();
});

/// Active search query in the search screen.
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

/// Search results queried directly from the SQLite index.
final searchResultsProvider = FutureProvider<List<AudioTrack>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];

  final repo = ref.watch(musicLibraryRepositoryProvider);
  return repo.searchTracks(query);
});

/// Library stats summary.
class LibraryStats {
  const LibraryStats({
    required this.trackCount,
    required this.albumCount,
    required this.artistCount,
    required this.totalBytes,
  });

  final int trackCount;
  final int albumCount;
  final int artistCount;
  final int totalBytes;

  String get formattedStorageSize {
    if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    } else if (totalBytes < 1024 * 1024 * 1024) {
      return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}

final libraryStatsProvider = Provider<LibraryStats>((ref) {
  final tracksAsync = ref.watch(tracksStreamProvider);
  final tracks = tracksAsync.asData?.value ?? [];

  final uniqueAlbums = tracks
      .map((t) => '${t.displayAlbum}__${t.displayArtist}')
      .toSet();
  final uniqueArtists = tracks.map((t) => t.displayArtist).toSet();
  final totalBytes = tracks.fold<int>(0, (sum, t) => sum + t.fileSizeBytes);

  return LibraryStats(
    trackCount: tracks.length,
    albumCount: uniqueAlbums.length,
    artistCount: uniqueArtists.length,
    totalBytes: totalBytes,
  );
});

/// Scan / Import Status state machine.
enum ScanProgressState { idle, scanning, completed, error }

class ScanStatus {
  const ScanStatus({
    this.state = ScanProgressState.idle,
    this.message,
    this.summary,
  });

  final ScanProgressState state;
  final String? message;
  final ScanSummary? summary;

  bool get isScanning => state == ScanProgressState.scanning;
}

class ScanStatusNotifier extends Notifier<ScanStatus> {
  @override
  ScanStatus build() => const ScanStatus();

  Future<ScanSummary> startAndroidScan() async {
    state = const ScanStatus(
      state: ScanProgressState.scanning,
      message: 'Scanning Android MediaStore audio index...',
    );

    final repo = ref.read(musicLibraryRepositoryProvider);
    final summary = await repo.scanAndroidMediaStore();

    if (summary.isSuccess) {
      state = ScanStatus(
        state: ScanProgressState.completed,
        message: 'Discovered ${summary.newlyAddedCount} tracks.',
        summary: summary,
      );
    } else {
      state = ScanStatus(
        state: ScanProgressState.error,
        message: summary.errorMessage ?? 'Audio scan failed.',
        summary: summary,
      );
    }

    return summary;
  }

  Future<ScanSummary> startIosImport() async {
    state = const ScanStatus(
      state: ScanProgressState.scanning,
      message: 'Importing selected audio files...',
    );

    final repo = ref.read(musicLibraryRepositoryProvider);
    final summary = await repo.importIosAudioFiles();

    if (summary.isSuccess) {
      state = ScanStatus(
        state: ScanProgressState.completed,
        message: 'Imported ${summary.newlyAddedCount} audio files.',
        summary: summary,
      );
    } else {
      state = ScanStatus(
        state: ScanProgressState.error,
        message: summary.errorMessage ?? 'File import failed.',
        summary: summary,
      );
    }

    return summary;
  }

  void reset() => state = const ScanStatus();
}

final scanStatusProvider = NotifierProvider<ScanStatusNotifier, ScanStatus>(
  ScanStatusNotifier.new,
);
