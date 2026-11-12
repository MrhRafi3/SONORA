import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/artwork_cache_service.dart';
import '../../library/presentation/library_providers.dart';
import '../data/repositories/metadata_repository.dart';
import '../domain/models/artwork_match.dart';
import '../domain/models/lyrics_model.dart';

/// Provider for the singleton [MetadataRepository].
final metadataRepositoryProvider = Provider<MetadataRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  const cache = ArtworkCacheService();
  final repo = MetadataRepository(database: db, artworkCacheService: cache);
  ref.onDispose(repo.dispose);
  return repo;
});

/// Watches locally persisted lyrics for [trackId] from the SQLite database.
final trackLyricsProvider = FutureProvider.family<TrackLyricsData?, String>((
  ref,
  trackId,
) async {
  final repo = ref.watch(metadataRepositoryProvider);
  return repo.getCachedLyrics(trackId);
});

/// Set of normalized albumKeys currently being fetched over the network.
class ArtworkFetchingNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void markFetching(String albumKey) {
    state = {...state, albumKey};
  }

  void markComplete(String albumKey) {
    final next = Set<String>.from(state);
    next.remove(albumKey);
    state = next;
  }
}

final artworkFetchingProvider =
    NotifierProvider<ArtworkFetchingNotifier, Set<String>>(
      ArtworkFetchingNotifier.new,
    );

/// Boolean selector indicating if a specific album is currently fetching artwork.
final isAlbumArtworkFetchingProvider = Provider.family<bool, String>((
  ref,
  albumKey,
) {
  final fetchingSet = ref.watch(artworkFetchingProvider);
  return fetchingSet.contains(albumKey);
});

/// Interactive state for searching and previewing online lyrics from LRCLIB.
class LyricsSearchState {
  const LyricsSearchState({
    this.isLoading = false,
    this.results = const [],
    this.errorMessage,
    this.isOffline = false,
    this.hasSearched = false,
  });

  final bool isLoading;
  final List<LrclibSearchResult> results;
  final String? errorMessage;
  final bool isOffline;
  final bool hasSearched;

  LyricsSearchState copyWith({
    bool? isLoading,
    List<LrclibSearchResult>? results,
    String? errorMessage,
    bool? isOffline,
    bool? hasSearched,
  }) {
    return LyricsSearchState(
      isLoading: isLoading ?? this.isLoading,
      results: results ?? this.results,
      errorMessage: errorMessage,
      isOffline: isOffline ?? this.isOffline,
      hasSearched: hasSearched ?? this.hasSearched,
    );
  }
}

class LyricsSearchNotifier extends Notifier<LyricsSearchState> {
  @override
  LyricsSearchState build() => const LyricsSearchState();

  Future<void> search({
    required String trackId,
    required String title,
    required String artist,
    String? album,
    Duration? duration,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isOffline: false,
    );
    try {
      final repo = ref.read(metadataRepositoryProvider);
      final results = await repo.searchOnlineLyrics(
        trackId: trackId,
        title: title,
        artist: artist,
        album: album,
        duration: duration,
      );

      state = LyricsSearchState(
        isLoading: false,
        results: results,
        hasSearched: true,
      );
    } on SocketException catch (_) {
      state = state.copyWith(
        isLoading: false,
        isOffline: true,
        errorMessage:
            'Network unavailable. Connect to internet to search lyrics.',
        hasSearched: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to search lyrics: $e',
        hasSearched: true,
      );
    }
  }

  Future<void> applyResult(String trackId, LrclibSearchResult result) async {
    final repo = ref.read(metadataRepositoryProvider);
    await repo.saveLyrics(
      trackId: trackId,
      plainLyrics: result.plainLyrics,
      syncedLyrics: result.syncedLyrics,
      source: 'lrclib_manual',
    );
    ref.invalidate(trackLyricsProvider(trackId));
  }

  Future<void> removeLyrics(String trackId) async {
    final repo = ref.read(metadataRepositoryProvider);
    await repo.removeLyrics(trackId);
    ref.invalidate(trackLyricsProvider(trackId));
  }

  void clear() {
    state = const LyricsSearchState();
  }
}

final lyricsSearchProvider =
    NotifierProvider<LyricsSearchNotifier, LyricsSearchState>(
      LyricsSearchNotifier.new,
    );

/// State for manual album artwork lookup and selection.
class ArtworkSearchState {
  const ArtworkSearchState({
    this.isLoading = false,
    this.matches = const [],
    this.errorMessage,
    this.hasSearched = false,
  });

  final bool isLoading;
  final List<ArtworkMatch> matches;
  final String? errorMessage;
  final bool hasSearched;

  ArtworkSearchState copyWith({
    bool? isLoading,
    List<ArtworkMatch>? matches,
    String? errorMessage,
    bool? hasSearched,
  }) {
    return ArtworkSearchState(
      isLoading: isLoading ?? this.isLoading,
      matches: matches ?? this.matches,
      errorMessage: errorMessage,
      hasSearched: hasSearched ?? this.hasSearched,
    );
  }
}

class ArtworkSearchNotifier extends Notifier<ArtworkSearchState> {
  @override
  ArtworkSearchState build() => const ArtworkSearchState();

  Future<void> search({
    required String artist,
    required String album,
    String? trackTitle,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = ref.read(metadataRepositoryProvider);
      final matches = await repo.artworkClient.searchArtwork(
        artist: artist,
        album: album,
        trackTitle: trackTitle,
      );
      state = ArtworkSearchState(
        isLoading: false,
        matches: matches,
        hasSearched: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to find artwork: $e',
        hasSearched: true,
      );
    }
  }

  Future<String?> applyMatch({
    required String artist,
    required String album,
    required ArtworkMatch match,
  }) async {
    final repo = ref.read(metadataRepositoryProvider);
    return repo.applySelectedArtwork(
      artist: artist,
      album: album,
      match: match,
    );
  }

  void clear() {
    state = const ArtworkSearchState();
  }
}

final artworkSearchProvider =
    NotifierProvider<ArtworkSearchNotifier, ArtworkSearchState>(
      ArtworkSearchNotifier.new,
    );
