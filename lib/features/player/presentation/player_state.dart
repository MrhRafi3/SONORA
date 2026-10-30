import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../library/presentation/library_providers.dart';
import '../data/fake_audio_player_facade.dart';
import '../data/just_audio_player_facade.dart';
import '../domain/audio_player_facade.dart';
import '../domain/ui_track.dart';

enum PlaybackRepeatMode { off, all, one }

/// Provider for the audio player abstraction facade.
///
/// Automatically instantiates [FakeAudioPlayerFacade] in test environments
/// to prevent native platform channel invocations or hardware failures.
final audioPlayerFacadeProvider = Provider<AudioPlayerFacade>((ref) {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    final fake = FakeAudioPlayerFacade();
    ref.onDispose(fake.dispose);
    return fake;
  }
  final player = JustAudioPlayerFacade();
  ref.onDispose(player.dispose);
  return player;
});

/// Showcase catalog of audiophile tracks for UI design system inspection.
final List<UiTrack> kShowcaseTracks = [
  const UiTrack(
    id: 'track-1',
    title: 'Clair de Lune (Audiophile Re-Master)',
    artist: 'Claude Debussy • Philharmonia',
    album: 'Suite Bergamasque (Direct-to-DSD)',
    duration: Duration(minutes: 5, seconds: 12),
    audioFormat: 'FLAC',
    sampleRate: '96 kHz',
    bitDepth: '24-bit',
    artworkColor: Color(0xFF1B263B),
    accentColor: Color(0xFFE59866),
  ),
  const UiTrack(
    id: 'track-2',
    title: 'Acoustic Resonance in D Minor',
    artist: 'Julian Bream & John Williams',
    album: 'Together Across Master Tapes',
    duration: Duration(minutes: 4, seconds: 45),
    audioFormat: 'FLAC',
    sampleRate: '192 kHz',
    bitDepth: '24-bit',
    artworkColor: Color(0xFF2C1E18),
    accentColor: Color(0xFFF0B27A),
  ),
  const UiTrack(
    id: 'track-3',
    title: 'Midnight Analog Drift',
    artist: 'Sora Soundworks',
    album: 'Vacuum Tube Sessions Vol. 2',
    duration: Duration(minutes: 6, seconds: 08),
    audioFormat: 'MP3',
    sampleRate: '44.1 kHz',
    bitDepth: '320 kbps',
    artworkColor: Color(0xFF1C2826),
    accentColor: Color(0xFFE5C07B),
  ),
  const UiTrack(
    id: 'track-4',
    title: 'Solitude by the River',
    artist: 'Norwegian Chamber Soloists',
    album: 'Nordic Soundscapes',
    duration: Duration(minutes: 3, seconds: 58),
    audioFormat: 'FLAC',
    sampleRate: '88.2 kHz',
    bitDepth: '24-bit',
    artworkColor: Color(0xFF242038),
    accentColor: Color(0xFFD4A373),
  ),
  const UiTrack(
    id: 'track-5',
    title: 'Warm Tube Harmonic Suite',
    artist: 'The Tokyo Brass Trio',
    album: 'Pure Ribbon Microphones',
    duration: Duration(minutes: 5, seconds: 34),
    audioFormat: 'FLAC',
    sampleRate: '96 kHz',
    bitDepth: '24-bit',
    artworkColor: Color(0xFF352220),
    accentColor: Color(0xFFE59866),
  ),
];

/// Immutable state for the interactive player surface in SONORA.
@immutable
class PlayerState {
  const PlayerState({
    this.track,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration,
    this.bufferedPosition = Duration.zero,
    this.isShuffle = false,
    this.repeatMode = PlaybackRepeatMode.off,
    this.queue = const [],
    this.queueIndex = 0,
    this.originalQueue = const [],
    this.playbackError,
  });

  final UiTrack? track;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration? duration;
  final Duration bufferedPosition;
  final bool isShuffle;
  final PlaybackRepeatMode repeatMode;
  final List<UiTrack> queue;
  final int queueIndex;
  final List<UiTrack> originalQueue;
  final String? playbackError;

  UiTrack? get currentTrack => track;
  bool get hasTrack => track != null;

  Duration get effectiveDuration =>
      duration ?? track?.duration ?? Duration.zero;

  double get progress {
    final totalMs = effectiveDuration.inMilliseconds;
    if (totalMs <= 0) return 0.0;
    final ratio = position.inMilliseconds / totalMs;
    return ratio.clamp(0.0, 1.0);
  }

  double get bufferedProgress {
    final totalMs = effectiveDuration.inMilliseconds;
    if (totalMs <= 0) return 0.0;
    final ratio = bufferedPosition.inMilliseconds / totalMs;
    return ratio.clamp(0.0, 1.0);
  }

  String get formattedPosition {
    final minutes = position.inMinutes;
    final seconds = position.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedRemaining {
    final total = effectiveDuration;
    if (total == Duration.zero) return '-0:00';
    final remaining = total - position;
    final safeRemaining = remaining.isNegative ? Duration.zero : remaining;
    final minutes = safeRemaining.inMinutes;
    final seconds = safeRemaining.inSeconds % 60;
    return '-$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  bool get hasNext {
    if (queue.isEmpty) return false;
    if (repeatMode != PlaybackRepeatMode.off) return true;
    return queueIndex < queue.length - 1;
  }

  bool get hasPrevious {
    if (queue.isEmpty) return false;
    if (position > const Duration(seconds: 3)) return true;
    if (repeatMode == PlaybackRepeatMode.all) return true;
    return queueIndex > 0;
  }

  PlayerState copyWith({
    UiTrack? track,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    bool? isShuffle,
    PlaybackRepeatMode? repeatMode,
    List<UiTrack>? queue,
    int? queueIndex,
    List<UiTrack>? originalQueue,
    String? playbackError,
    bool clearTrack = false,
    bool clearError = false,
  }) {
    return PlayerState(
      track: clearTrack ? null : (track ?? this.track),
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      isShuffle: isShuffle ?? this.isShuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      queue: queue ?? this.queue,
      queueIndex: queueIndex ?? this.queueIndex,
      originalQueue: originalQueue ?? this.originalQueue,
      playbackError: clearError ? null : (playbackError ?? this.playbackError),
    );
  }
}

/// Production-ready PlayerNotifier governing real audio playback and queue state.
class PlayerNotifier extends Notifier<PlayerState> {
  AudioPlayerFacade get _facade => ref.read(audioPlayerFacadeProvider);

  @override
  PlayerState build() {
    final facade = ref.watch(audioPlayerFacadeProvider);

    final subPlaying = facade.isPlayingStream.listen((playing) {
      if (state.isPlaying != playing) {
        state = state.copyWith(isPlaying: playing);
      }
    });

    final subPosition = facade.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });

    final subDuration = facade.durationStream.listen((dur) {
      if (dur != null) {
        state = state.copyWith(duration: dur);
      }
    });

    final subBuffered = facade.bufferedPositionStream.listen((buf) {
      state = state.copyWith(bufferedPosition: buf);
    });

    final subBuffering = facade.isBufferingStream.listen((buffering) {
      state = state.copyWith(isLoading: buffering);
    });

    final subCompleted = facade.playbackCompletedStream.listen((_) {
      _onPlaybackCompleted();
    });

    ref.onDispose(() {
      subPlaying.cancel();
      subPosition.cancel();
      subDuration.cancel();
      subBuffered.cancel();
      subBuffering.cancel();
      subCompleted.cancel();
    });

    return PlayerState(
      track: kShowcaseTracks.first,
      queue: List.unmodifiable(kShowcaseTracks),
      originalQueue: List.unmodifiable(kShowcaseTracks),
      queueIndex: 0,
      duration: kShowcaseTracks.first.duration,
    );
  }

  /// Plays a given track, optionally replacing the current queue.
  Future<void> playTrack(UiTrack track, {List<UiTrack>? queue}) async {
    List<UiTrack> updatedQueue;
    List<UiTrack> updatedOriginalQueue;
    int newIndex;

    if (queue != null && queue.isNotEmpty) {
      updatedOriginalQueue = List.unmodifiable(queue);
      if (state.isShuffle) {
        final rest = queue.where((t) => t.id != track.id).toList()..shuffle();
        updatedQueue = List.unmodifiable([track, ...rest]);
        newIndex = 0;
      } else {
        updatedQueue = List.unmodifiable(queue);
        newIndex = updatedQueue.indexWhere((t) => t.id == track.id);
        if (newIndex == -1) newIndex = 0;
      }
    } else {
      final currentQ = state.queue.isNotEmpty ? state.queue : [track];
      final existingIdx = currentQ.indexWhere((t) => t.id == track.id);
      if (existingIdx != -1) {
        updatedQueue = currentQ;
        updatedOriginalQueue = state.originalQueue.isNotEmpty
            ? state.originalQueue
            : currentQ;
        newIndex = existingIdx;
      } else {
        updatedQueue = List.unmodifiable([...currentQ, track]);
        updatedOriginalQueue = List.unmodifiable([
          ...state.originalQueue,
          track,
        ]);
        newIndex = updatedQueue.length - 1;
      }
    }

    state = state.copyWith(
      track: track,
      queue: updatedQueue,
      originalQueue: updatedOriginalQueue,
      queueIndex: newIndex,
      position: Duration.zero,
      duration: track.duration,
      isLoading: true,
      clearError: true,
    );

    await _loadAndPlay(track);
  }

  Future<void> _loadAndPlay(UiTrack track) async {
    try {
      final uri = track.sourceUri;
      final path = track.filePath;

      if (uri != null && uri.isNotEmpty) {
        await _facade.load(uri, isUri: true);
      } else if (path != null && path.isNotEmpty) {
        await _facade.load(path, isUri: false);
      } else {
        await _facade.load(track.id, isUri: false);
      }

      await _facade.play();
      state = state.copyWith(
        isPlaying: true,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isPlaying: false,
        isLoading: false,
        playbackError: e.toString(),
      );
    }
  }

  /// Sets the queue and original sequence directly.
  void setQueue(List<UiTrack> newQueue) {
    state = state.copyWith(
      queue: List.unmodifiable(newQueue),
      originalQueue: List.unmodifiable(newQueue),
      queueIndex: 0,
    );
  }

  /// Appends a single track to the end of the queue.
  void addToQueue(UiTrack track) {
    final updatedQueue = [...state.queue, track];
    final updatedOriginal = [...state.originalQueue, track];
    state = state.copyWith(
      queue: List.unmodifiable(updatedQueue),
      originalQueue: List.unmodifiable(updatedOriginal),
    );
  }

  /// Removes a track at [index] from the active queue.
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    final itemToRemove = state.queue[index];
    final updatedQueue = List<UiTrack>.from(state.queue)..removeAt(index);
    final updatedOriginal = List<UiTrack>.from(state.originalQueue)
      ..remove(itemToRemove);

    int newIndex = state.queueIndex;
    if (index < state.queueIndex) {
      newIndex--;
    } else if (index == state.queueIndex) {
      if (updatedQueue.isEmpty) {
        await dismissPlayer();
        return;
      }
      if (newIndex >= updatedQueue.length) {
        newIndex = updatedQueue.length - 1;
      }
      state = state.copyWith(
        queue: List.unmodifiable(updatedQueue),
        originalQueue: List.unmodifiable(updatedOriginal),
        queueIndex: newIndex,
      );
      await playQueueIndex(newIndex);
      return;
    }

    state = state.copyWith(
      queue: List.unmodifiable(updatedQueue),
      originalQueue: List.unmodifiable(updatedOriginal),
      queueIndex: newIndex,
    );
  }

  /// Plays a track at the given [index] in the active queue.
  Future<void> playQueueIndex(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    final track = state.queue[index];
    state = state.copyWith(
      track: track,
      queueIndex: index,
      position: Duration.zero,
      duration: track.duration,
      isLoading: true,
      clearError: true,
    );
    await _loadAndPlay(track);
  }

  /// Clears the entire queue and halts playback.
  Future<void> clearQueue() async {
    await _facade.stop();
    state = state.copyWith(
      queue: const [],
      originalQueue: const [],
      queueIndex: 0,
      clearTrack: true,
      isPlaying: false,
      position: Duration.zero,
    );
  }

  /// Toggles between playing and paused states.
  Future<void> togglePlayPause() async {
    if (state.track == null) {
      if (state.queue.isNotEmpty) {
        await playQueueIndex(0);
      }
      return;
    }

    if (state.isPlaying) {
      await _facade.pause();
      state = state.copyWith(isPlaying: false);
    } else {
      if (state.effectiveDuration > Duration.zero &&
          state.position >= state.effectiveDuration) {
        await _facade.seek(Duration.zero);
        state = state.copyWith(position: Duration.zero);
      }
      await _facade.play();
      state = state.copyWith(isPlaying: true);
    }
  }

  /// Seeks to a proportional ratio (0.0 to 1.0) of track duration.
  Future<void> seek(double ratio) async {
    if (state.track == null) return;
    final totalMs = state.effectiveDuration.inMilliseconds;
    final targetMs = (totalMs * ratio.clamp(0.0, 1.0)).toInt();
    final newPosition = Duration(milliseconds: targetMs);
    state = state.copyWith(position: newPosition);
    await _facade.seek(newPosition);
  }

  /// Seeks to a specific [target] duration.
  Future<void> seekTo(Duration target) async {
    state = state.copyWith(position: target);
    await _facade.seek(target);
  }

  /// Toggles the favorite status of the active track and updates the SQLite repository.
  Future<void> toggleFavorite() async {
    if (state.track == null) return;
    final newFavorite = !state.track!.isFavorite;
    final updated = state.track!.copyWith(isFavorite: newFavorite);
    state = state.copyWith(track: updated);

    try {
      final repo = ref.read(musicLibraryRepositoryProvider);
      await repo.toggleFavorite(state.track!.id, newFavorite);
    } catch (_) {
      // Ignore if not present in database
    }
  }

  /// Toggles shuffle mode, preserving original queue order when un-shuffling.
  void toggleShuffle() {
    if (!state.isShuffle) {
      final currentTrack = state.track;
      final baseList = state.originalQueue.isNotEmpty
          ? state.originalQueue
          : state.queue;
      if (baseList.isEmpty) {
        state = state.copyWith(isShuffle: true);
        return;
      }

      final rest = baseList.where((t) => t.id != currentTrack?.id).toList()
        ..shuffle();
      final newQueue = currentTrack != null
          ? List<UiTrack>.unmodifiable([currentTrack, ...rest])
          : List<UiTrack>.unmodifiable(rest);

      state = state.copyWith(
        isShuffle: true,
        originalQueue: List.unmodifiable(baseList),
        queue: newQueue,
        queueIndex: 0,
      );
    } else {
      final restoredQueue = state.originalQueue.isNotEmpty
          ? state.originalQueue
          : state.queue;
      final currentTrack = state.track;
      final restoredIndex = currentTrack != null
          ? restoredQueue.indexWhere((t) => t.id == currentTrack.id)
          : 0;

      state = state.copyWith(
        isShuffle: false,
        queue: restoredQueue,
        queueIndex: restoredIndex != -1 ? restoredIndex : 0,
      );
    }
  }

  /// Cycles repeat mode: off -> all -> one -> off.
  void toggleRepeat() {
    final nextMode = switch (state.repeatMode) {
      PlaybackRepeatMode.off => PlaybackRepeatMode.all,
      PlaybackRepeatMode.all => PlaybackRepeatMode.one,
      PlaybackRepeatMode.one => PlaybackRepeatMode.off,
    };
    state = state.copyWith(repeatMode: nextMode);
  }

  /// Advances to the next track in queue or wraps/stops based on repeat mode.
  Future<void> nextTrack({bool autoAdvance = false}) async {
    final activeQueue = state.queue.isNotEmpty ? state.queue : kShowcaseTracks;
    if (activeQueue.isEmpty) return;

    var nextIndex = state.queueIndex + 1;
    if (nextIndex >= activeQueue.length) {
      if (state.repeatMode == PlaybackRepeatMode.all) {
        nextIndex = 0;
      } else {
        if (autoAdvance) {
          await _facade.stop();
          state = state.copyWith(isPlaying: false, position: Duration.zero);
          return;
        } else {
          nextIndex = 0;
        }
      }
    }

    await playQueueIndex(nextIndex);
  }

  /// Goes to the previous track, or restarts current track if played > 3 seconds.
  Future<void> previousTrack() async {
    if (state.position > const Duration(seconds: 3)) {
      await _facade.seek(Duration.zero);
      state = state.copyWith(position: Duration.zero);
      return;
    }

    final activeQueue = state.queue.isNotEmpty ? state.queue : kShowcaseTracks;
    if (activeQueue.isEmpty) return;

    var prevIndex = state.queueIndex - 1;
    if (prevIndex < 0) {
      if (state.repeatMode == PlaybackRepeatMode.all) {
        prevIndex = activeQueue.length - 1;
      } else {
        prevIndex = 0;
      }
    }

    await playQueueIndex(prevIndex);
  }

  Future<void> _onPlaybackCompleted() async {
    if (state.repeatMode == PlaybackRepeatMode.one) {
      await _facade.seek(Duration.zero);
      await _facade.play();
    } else {
      await nextTrack(autoAdvance: true);
    }
  }

  /// Dismisses playback and clears current track.
  Future<void> dismissPlayer() async {
    await _facade.stop();
    state = state.copyWith(
      clearTrack: true,
      isPlaying: false,
      position: Duration.zero,
    );
  }
}

final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);

/// Provider to toggle between populated showcase UI and empty library state for testing.
class LibraryEmptyStateNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final libraryEmptyStateProvider =
    NotifierProvider<LibraryEmptyStateNotifier, bool>(
      LibraryEmptyStateNotifier.new,
    );
