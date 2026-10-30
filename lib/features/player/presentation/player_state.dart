import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/ui_track.dart';

enum PlaybackRepeatMode { off, all, one }

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

/// Immutable state for the interactive player surface in Phase 02.
@immutable
class PlayerState {
  const PlayerState({
    this.track,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.isShuffle = false,
    this.repeatMode = PlaybackRepeatMode.off,
  });

  final UiTrack? track;
  final bool isPlaying;
  final Duration position;
  final bool isShuffle;
  final PlaybackRepeatMode repeatMode;

  double get progress {
    if (track == null || track!.duration.inMilliseconds == 0) return 0.0;
    final ratio = position.inMilliseconds / track!.duration.inMilliseconds;
    return ratio.clamp(0.0, 1.0);
  }

  String get formattedPosition {
    final minutes = position.inMinutes;
    final seconds = position.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedRemaining {
    if (track == null) return '-0:00';
    final remaining = track!.duration - position;
    final safeRemaining = remaining.isNegative ? Duration.zero : remaining;
    final minutes = safeRemaining.inMinutes;
    final seconds = safeRemaining.inSeconds % 60;
    return '-$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  PlayerState copyWith({
    UiTrack? track,
    bool? isPlaying,
    Duration? position,
    bool? isShuffle,
    PlaybackRepeatMode? repeatMode,
    bool clearTrack = false,
  }) {
    return PlayerState(
      track: clearTrack ? null : (track ?? this.track),
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      isShuffle: isShuffle ?? this.isShuffle,
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }
}

/// Notifier governing the UI player simulation during Phase 02.
class PlayerNotifier extends Notifier<PlayerState> {
  @override
  PlayerState build() {
    // Initialized with first showcase track in paused state for instant UI preview
    return PlayerState(
      track: kShowcaseTracks.first,
      isPlaying: false,
      position: const Duration(minutes: 1, seconds: 24),
    );
  }

  void playTrack(UiTrack track) {
    state = state.copyWith(
      track: track,
      isPlaying: true,
      position: Duration.zero,
    );
  }

  void togglePlayPause() {
    if (state.track == null && kShowcaseTracks.isNotEmpty) {
      state = state.copyWith(track: kShowcaseTracks.first, isPlaying: true);
    } else {
      state = state.copyWith(isPlaying: !state.isPlaying);
    }
  }

  void seek(double ratio) {
    if (state.track == null) return;
    final totalMs = state.track!.duration.inMilliseconds;
    final newPosition = Duration(milliseconds: (totalMs * ratio).toInt());
    state = state.copyWith(position: newPosition);
  }

  void toggleFavorite() {
    if (state.track == null) return;
    final updated = state.track!.copyWith(isFavorite: !state.track!.isFavorite);
    state = state.copyWith(track: updated);
  }

  void toggleShuffle() {
    state = state.copyWith(isShuffle: !state.isShuffle);
  }

  void toggleRepeat() {
    final nextMode = switch (state.repeatMode) {
      PlaybackRepeatMode.off => PlaybackRepeatMode.all,
      PlaybackRepeatMode.all => PlaybackRepeatMode.one,
      PlaybackRepeatMode.one => PlaybackRepeatMode.off,
    };
    state = state.copyWith(repeatMode: nextMode);
  }

  void nextTrack() {
    if (kShowcaseTracks.isEmpty) return;
    final currentIndex = state.track != null
        ? kShowcaseTracks.indexOf(state.track!)
        : -1;
    final nextIndex = (currentIndex + 1) % kShowcaseTracks.length;
    playTrack(kShowcaseTracks[nextIndex]);
  }

  void previousTrack() {
    if (kShowcaseTracks.isEmpty) return;
    final currentIndex = state.track != null
        ? kShowcaseTracks.indexOf(state.track!)
        : -1;
    final prevIndex = currentIndex <= 0
        ? kShowcaseTracks.length - 1
        : currentIndex - 1;
    playTrack(kShowcaseTracks[prevIndex]);
  }

  void dismissPlayer() {
    state = state.copyWith(clearTrack: true, isPlaying: false);
  }
}

final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);

/// Provider to toggle between populated showcase UI and empty library state for testing.
class LibraryEmptyStateNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final libraryEmptyStateProvider =
    NotifierProvider<LibraryEmptyStateNotifier, bool>(
      LibraryEmptyStateNotifier.new,
    );
