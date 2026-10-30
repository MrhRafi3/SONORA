import 'dart:async';
import '../domain/audio_player_facade.dart';

/// Test fake implementing [AudioPlayerFacade] in pure Dart without platform channels.
class FakeAudioPlayerFacade implements AudioPlayerFacade {
  FakeAudioPlayerFacade({Duration? defaultDuration})
    : _duration = defaultDuration;

  final StreamController<bool> _playingController =
      StreamController<bool>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();
  final StreamController<Duration> _bufferedPositionController =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _bufferingController =
      StreamController<bool>.broadcast();
  final StreamController<void> _completedController =
      StreamController<void>.broadcast();

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  Duration _bufferedPosition = Duration.zero;
  bool _isBuffering = false;
  double _volume = 1.0;

  String? lastLoadedSource;
  bool lastLoadedIsUri = false;
  bool shouldFailLoad = false;
  int loadCount = 0;
  int playCount = 0;
  int pauseCount = 0;
  int seekCount = 0;
  int stopCount = 0;

  @override
  Stream<bool> get isPlayingStream => _playingController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Stream<Duration> get bufferedPositionStream =>
      _bufferedPositionController.stream;

  @override
  Stream<bool> get isBufferingStream => _bufferingController.stream;

  @override
  Stream<void> get playbackCompletedStream => _completedController.stream;

  @override
  Duration get position => _position;

  @override
  Duration? get duration => _duration;

  @override
  bool get isPlaying => _isPlaying;

  double get volume => _volume;
  Duration get bufferedPosition => _bufferedPosition;
  bool get isBuffering => _isBuffering;

  @override
  Future<void> load(String source, {bool isUri = false}) async {
    loadCount++;
    lastLoadedSource = source;
    lastLoadedIsUri = isUri;

    if (shouldFailLoad) {
      throw Exception('Failed to load audio source: $source');
    }

    _position = Duration.zero;
    _positionController.add(_position);
    _durationController.add(_duration);
  }

  @override
  Future<void> play() async {
    playCount++;
    _isPlaying = true;
    _playingController.add(true);
  }

  @override
  Future<void> pause() async {
    pauseCount++;
    _isPlaying = false;
    _playingController.add(false);
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _isPlaying = false;
    _position = Duration.zero;
    _playingController.add(false);
    _positionController.add(Duration.zero);
  }

  @override
  Future<void> seek(Duration position) async {
    seekCount++;
    _position = position;
    _positionController.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
  }

  /// Simulation helpers for testing
  void simulatePosition(Duration pos) {
    _position = pos;
    _positionController.add(pos);
  }

  void simulateDuration(Duration? dur) {
    _duration = dur;
    _durationController.add(dur);
  }

  void simulateBuffering(bool buffering) {
    _isBuffering = buffering;
    _bufferingController.add(buffering);
  }

  void simulateBufferedPosition(Duration bufPos) {
    _bufferedPosition = bufPos;
    _bufferedPositionController.add(bufPos);
  }

  void simulateCompletion() {
    _isPlaying = false;
    _playingController.add(false);
    _completedController.add(null);
  }

  @override
  Future<void> dispose() async {
    await _playingController.close();
    await _positionController.close();
    await _durationController.close();
    await _bufferedPositionController.close();
    await _bufferingController.close();
    await _completedController.close();
  }
}
