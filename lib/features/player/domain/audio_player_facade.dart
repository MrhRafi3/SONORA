import 'dart:async';

/// Clean Architecture domain facade for the audio player.
///
/// Decouples the presentation and state management layer from specific audio
/// libraries (like just_audio) or platform implementations, enabling complete
/// unit testability and test fakes without platform channel dependencies.
abstract class AudioPlayerFacade {
  /// Stream emitting whether audio is actively playing.
  Stream<bool> get isPlayingStream;

  /// Stream emitting current playback position.
  Stream<Duration> get positionStream;

  /// Stream emitting total track duration once known.
  Stream<Duration?> get durationStream;

  /// Stream emitting buffered position.
  Stream<Duration> get bufferedPositionStream;

  /// Stream emitting whether the player is buffering or loading.
  Stream<bool> get isBufferingStream;

  /// Stream emitting when playback reaches the end of the loaded track.
  Stream<void> get playbackCompletedStream;

  /// Current playback position.
  Duration get position;

  /// Total duration of the current audio track.
  Duration? get duration;

  /// Whether audio is actively playing.
  bool get isPlaying;

  /// Loads an audio track from a file path or URI.
  ///
  /// Set [isUri] to true if [source] is a URI (such as `content://` on Android).
  Future<void> load(String source, {bool isUri = false});

  /// Starts or resumes playback.
  Future<void> play();

  /// Pauses playback.
  Future<void> pause();

  /// Stops playback and resets position.
  Future<void> stop();

  /// Seeks to a specific [position].
  Future<void> seek(Duration position);

  /// Sets audio volume between 0.0 and 1.0.
  Future<void> setVolume(double volume);

  /// Releases resources held by the player.
  Future<void> dispose();
}
