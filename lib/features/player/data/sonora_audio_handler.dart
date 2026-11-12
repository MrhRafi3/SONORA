import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import '../domain/ui_track.dart';

/// Single production audio handler integrating [just_audio] with the platform's
/// background audio subsystem and media session controls (Android MediaSessionCompat
/// & iOS MPRemoteCommandCenter / MPNowPlayingInfoCenter).
class SonoraAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  SonoraAudioHandler({
    ja.AudioPlayer? player,
    ja.AndroidEqualizer? equalizer,
    ja.AndroidLoudnessEnhancer? loudnessEnhancer,
  }) : this._internal(
         equalizer ??
             (defaultTargetPlatform == TargetPlatform.android &&
                     !kIsWeb &&
                     !Platform.environment.containsKey('FLUTTER_TEST')
                 ? ja.AndroidEqualizer()
                 : null),
         loudnessEnhancer ??
             (defaultTargetPlatform == TargetPlatform.android &&
                     !kIsWeb &&
                     !Platform.environment.containsKey('FLUTTER_TEST')
                 ? ja.AndroidLoudnessEnhancer()
                 : null),
         player,
       );

  SonoraAudioHandler._internal(
    this._equalizer,
    this._loudnessEnhancer,
    ja.AudioPlayer? player,
  ) : _player =
          player ??
          ja.AudioPlayer(
            handleInterruptions: false,
            audioPipeline: (_equalizer != null || _loudnessEnhancer != null)
                ? ja.AudioPipeline(
                    androidAudioEffects: [?_loudnessEnhancer, ?_equalizer],
                  )
                : null,
          ) {
    _initStreams();
  }

  final ja.AudioPlayer _player;
  final ja.AndroidEqualizer? _equalizer;
  final ja.AndroidLoudnessEnhancer? _loudnessEnhancer;

  /// Direct accessor for the shared production player instance.
  ja.AudioPlayer get player => _player;

  /// Optional accessor for the AndroidEqualizer audio effect.
  ja.AndroidEqualizer? get equalizer => _equalizer;

  /// Optional accessor for the AndroidLoudnessEnhancer audio effect.
  ja.AndroidLoudnessEnhancer? get loudnessEnhancer => _loudnessEnhancer;

  StreamSubscription<ja.PlaybackEvent>? _playbackEventSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<void>? _noisySubscription;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;

  bool _wasInterruptedPlaying = false;
  bool _isHandlingInterruption = false;
  bool _pauseOnBecomingNoisy = true;
  bool _audioSessionInitialized = false;
  int? _queueIndex;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  AudioServiceShuffleMode _shuffleMode = AudioServiceShuffleMode.none;

  /// External delegation callbacks to harmonize system remote events with
  /// Riverpod PlayerNotifier state.
  Future<void> Function()? onSkipToNext;
  Future<void> Function()? onSkipToPrevious;
  Future<void> Function(int index)? onSkipToQueueItem;
  ValueChanged<AudioServiceRepeatMode>? onSetRepeatMode;
  ValueChanged<AudioServiceShuffleMode>? onSetShuffleMode;

  /// Updates whether headphone/Bluetooth disconnects automatically pause playback.
  void setPauseOnBecomingNoisy(bool enabled) {
    _pauseOnBecomingNoisy = enabled;
  }

  void _initStreams() {
    // 1. Listen to just_audio playback events and broadcast PlaybackState
    _playbackEventSubscription = _player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object e, StackTrace st) {
        debugPrint('SonoraAudioHandler playbackEvent error: $e');
      },
    );

    // 2. Listen to duration changes and update current MediaItem
    _durationSubscription = _player.durationStream.listen((dur) {
      if (mediaItem.value != null && dur != null) {
        mediaItem.add(mediaItem.value!.copyWith(duration: dur));
      }
    });
  }

  /// Initializes the audio session for music playback, headphone disconnect events,
  /// and system audio interruptions (phone calls, navigation prompts).
  Future<void> initAudioSession() async {
    if (_audioSessionInitialized) return;
    _audioSessionInitialized = true;

    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      // Becoming noisy: Headphones unplugged or Bluetooth disconnected -> pause immediately
      _noisySubscription = session.becomingNoisyEventStream.listen((_) {
        if (_pauseOnBecomingNoisy) {
          pause();
        }
      });

      // Handle phone call and navigation interruptions
      _interruptionSubscription = session.interruptionEventStream.listen(
        handleAudioInterruption,
      );
    } catch (e) {
      debugPrint('SonoraAudioHandler audio session init failed: $e');
    }
  }

  /// Processes an [AudioInterruptionEvent] (exposed for deterministic unit testing).
  @visibleForTesting
  Future<void> handleAudioInterruption(AudioInterruptionEvent event) async {
    if (event.begin) {
      switch (event.type) {
        case AudioInterruptionType.duck:
          await _player.setVolume(0.25);
          break;
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          if (_player.playing) {
            _wasInterruptedPlaying = true;
            _isHandlingInterruption = true;
            try {
              await pause();
            } finally {
              _isHandlingInterruption = false;
            }
          }
          break;
      }
    } else {
      switch (event.type) {
        case AudioInterruptionType.duck:
          await _player.setVolume(1.0);
          break;
        case AudioInterruptionType.pause:
          if (_wasInterruptedPlaying) {
            _wasInterruptedPlaying = false;
            await play();
          }
          break;
        case AudioInterruptionType.unknown:
          _wasInterruptedPlaying = false;
          break;
      }
    }
  }

  /// Maps [UiTrack] into system [MediaItem] with safe artwork URI conversion.
  MediaItem trackToMediaItem(UiTrack track) {
    Uri? artUri;
    if (track.artworkPath != null && track.artworkPath!.isNotEmpty) {
      final file = File(track.artworkPath!);
      if (Platform.environment.containsKey('FLUTTER_TEST') ||
          file.existsSync()) {
        artUri = Uri.file(track.artworkPath!);
      }
    }

    return MediaItem(
      id: track.id,
      album: track.album,
      title: track.title,
      artist: track.artist,
      duration: track.duration,
      artUri: artUri,
      extras: <String, dynamic>{
        'audioFormat': track.audioFormat,
        'sampleRate': track.sampleRate,
        'bitDepth': track.bitDepth,
        if (track.sourceUri != null) 'sourceUri': track.sourceUri,
        if (track.filePath != null) 'filePath': track.filePath,
      },
    );
  }

  /// Synchronizes active track metadata with lock screen and notification shade.
  void updateActiveTrack(UiTrack track) {
    mediaItem.add(trackToMediaItem(track));
    _broadcastState();
  }

  /// Synchronizes current active playlist queue with system media browser.
  void updateActiveQueue(List<UiTrack> tracks) {
    queue.add(tracks.map(trackToMediaItem).toList());
    if (tracks.isEmpty) {
      _queueIndex = null;
    }
    _broadcastState();
  }

  /// Updates the active queue index broadcast in [PlaybackState].
  void updateQueueIndex(int? index) {
    _queueIndex = index;
    _broadcastState();
  }

  /// Synchronizes repeat and shuffle modes to system [PlaybackState] without
  /// triggering remote callbacks.
  void syncModes({
    AudioServiceRepeatMode? repeatMode,
    AudioServiceShuffleMode? shuffleMode,
  }) {
    if (repeatMode != null) _repeatMode = repeatMode;
    if (shuffleMode != null) _shuffleMode = shuffleMode;
    _broadcastState();
  }

  /// Loads an audio track from source URI or local file path into the single player.
  Future<void> load(String source, {bool isUri = false}) async {
    final uri = Uri.tryParse(source);
    final shouldUseUri =
        isUri || (uri != null && uri.hasScheme && uri.scheme != 'file');

    if (shouldUseUri) {
      await _player.setAudioSource(ja.AudioSource.uri(Uri.parse(source)));
    } else {
      final cleanPath = (uri != null && uri.scheme == 'file')
          ? uri.toFilePath()
          : source;
      await _player.setAudioSource(ja.AudioSource.file(cleanPath));
    }
    _broadcastState();
  }

  /// Broadcasts the current player state to system notification and lock screen.
  void _broadcastState([ja.PlaybackEvent? event]) {
    final isPlaying = _player.playing;
    final processingState = _player.processingState;

    final controls = [
      MediaControl.skipToPrevious,
      if (isPlaying) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
      MediaControl.stop,
    ];

    final currentQueueLength = queue.value.length;
    final safeQueueIndex =
        (_queueIndex != null &&
            _queueIndex! >= 0 &&
            _queueIndex! < currentQueueLength)
        ? _queueIndex
        : null;

    playbackState.add(
      PlaybackState(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.playPause,
          MediaAction.stop,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.setRepeatMode,
          MediaAction.setShuffleMode,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState:
            const {
              ja.ProcessingState.idle: AudioProcessingState.idle,
              ja.ProcessingState.loading: AudioProcessingState.loading,
              ja.ProcessingState.buffering: AudioProcessingState.buffering,
              ja.ProcessingState.ready: AudioProcessingState.ready,
              ja.ProcessingState.completed: AudioProcessingState.completed,
            }[processingState] ??
            AudioProcessingState.idle,
        playing: isPlaying,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: safeQueueIndex,
        repeatMode: _repeatMode,
        shuffleMode: _shuffleMode,
      ),
    );
  }

  // --- Remote Media Control Handlers ---

  @override
  Future<void> play() {
    _wasInterruptedPlaying = false;
    return _player.play();
  }

  @override
  Future<void> pause() {
    if (!_isHandlingInterruption) {
      _wasInterruptedPlaying = false;
    }
    return _player.pause();
  }

  @override
  Future<void> stop() async {
    _wasInterruptedPlaying = false;
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _broadcastState();
  }

  @override
  Future<void> skipToNext() async {
    if (onSkipToNext != null) {
      await onSkipToNext!();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (onSkipToPrevious != null) {
      await onSkipToPrevious!();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (onSkipToQueueItem != null) {
      await onSkipToQueueItem!(index);
    }
  }

  /// Sets master bypass / active state on the hardware AndroidEqualizer.
  Future<void> setEqualizerEnabled(bool enabled) async {
    try {
      await _equalizer?.setEnabled(enabled);
      await _loudnessEnhancer?.setEnabled(enabled);
    } catch (e) {
      debugPrint('SonoraAudioHandler setEqualizerEnabled error: $e');
    }
  }

  /// Interpolates and applies EQ band gains and preamp gain to Android AudioEffects.
  Future<void> setEqualizerBands({
    required List<double> frequencies,
    required List<double> gains,
    required double preampGain,
  }) async {
    if (_equalizer == null) return;
    try {
      final params = await _equalizer.parameters;
      for (final band in params.bands) {
        final targetGain = _interpolateGainForFrequency(
          band.centerFrequency,
          frequencies,
          gains,
        );
        final clampedGain = targetGain.clamp(
          params.minDecibels,
          params.maxDecibels,
        );
        await band.setGain(clampedGain);
      }
      if (_loudnessEnhancer != null) {
        final targetDb = preampGain.clamp(0.0, 12.0);
        await _loudnessEnhancer.setTargetGain(targetDb);
      }
    } catch (e) {
      debugPrint('SonoraAudioHandler setEqualizerBands error: $e');
    }
  }

  double _interpolateGainForFrequency(
    double centerFreq,
    List<double> freqs,
    List<double> gains,
  ) {
    if (freqs.isEmpty || gains.isEmpty) return 0.0;
    if (centerFreq <= freqs.first) return gains.first;
    if (centerFreq >= freqs.last) return gains.last;

    for (int i = 0; i < freqs.length - 1; i++) {
      if (centerFreq >= freqs[i] && centerFreq <= freqs[i + 1]) {
        final logF0 = math.log(freqs[i]);
        final logF1 = math.log(freqs[i + 1]);
        final logF = math.log(centerFreq);
        final t = (logF - logF0) / (logF1 - logF0);
        return gains[i] + t * (gains[i + 1] - gains[i]);
      }
    }
    return 0.0;
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    if (onSetRepeatMode != null) {
      onSetRepeatMode!(repeatMode);
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (onSetShuffleMode != null) {
      onSetShuffleMode!(shuffleMode);
    }
  }

  /// Cleanly closes all stream subscriptions and releases native resources.
  Future<void> disposeHandler() async {
    await _playbackEventSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _noisySubscription?.cancel();
    await _interruptionSubscription?.cancel();
    await _player.dispose();
  }
}
