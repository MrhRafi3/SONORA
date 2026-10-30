import 'dart:async';
import 'package:just_audio/just_audio.dart' as ja;
import '../domain/audio_player_facade.dart';

/// Concrete implementation of [AudioPlayerFacade] powered by `just_audio`.
class JustAudioPlayerFacade implements AudioPlayerFacade {
  JustAudioPlayerFacade({ja.AudioPlayer? player})
    : _player = player ?? ja.AudioPlayer();

  final ja.AudioPlayer _player;

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
    final uri = Uri.tryParse(source);
    final shouldUseUri =
        isUri || (uri != null && uri.hasScheme && uri.scheme != 'file');

    if (shouldUseUri) {
      await _player.setAudioSource(ja.AudioSource.uri(Uri.parse(source)));
    } else {
      await _player.setAudioSource(ja.AudioSource.file(source));
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() => _player.dispose();
}
