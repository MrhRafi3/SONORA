import 'dart:async';
import 'package:just_audio/just_audio.dart' as ja;
import '../domain/audio_player_facade.dart';
import 'sonora_audio_handler.dart';

/// Concrete implementation of [AudioPlayerFacade] delegating to the single
/// shared [SonoraAudioHandler], ensuring exactly one production [ja.AudioPlayer]
/// instance operates across the entire application lifecycle.
class JustAudioPlayerFacade implements AudioPlayerFacade {
  JustAudioPlayerFacade({required SonoraAudioHandler audioHandler})
    : _audioHandler = audioHandler,
      _player = audioHandler.player;

  final SonoraAudioHandler _audioHandler;
  final ja.AudioPlayer _player;

  /// Direct accessor for the underlying [SonoraAudioHandler].
  SonoraAudioHandler get audioHandler => _audioHandler;

  @override
  Stream<bool> get isPlayingStream => _player.playingStream;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  @override
  Stream<bool> get isBufferingStream => _player.playerStateStream.map(
    (state) =>
        state.processingState == ja.ProcessingState.buffering ||
        state.processingState == ja.ProcessingState.loading,
  );

  @override
  Stream<void> get playbackCompletedStream => _player.playerStateStream
      .where((state) => state.processingState == ja.ProcessingState.completed)
      .map((_) {});

  @override
  Duration get position => _player.position;

  @override
  Duration? get duration => _player.duration;

  @override
  bool get isPlaying => _player.playing;

  @override
  Future<void> load(String source, {bool isUri = false}) async {
    await _audioHandler.load(source, isUri: isUri);
  }

  @override
  Future<void> play() => _audioHandler.play();

  @override
  Future<void> pause() => _audioHandler.pause();

  @override
  Future<void> stop() => _audioHandler.stop();

  @override
  Future<void> seek(Duration position) => _audioHandler.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() => _audioHandler.disposeHandler();
}
