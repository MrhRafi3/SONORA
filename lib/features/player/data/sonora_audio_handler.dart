import 'dart:async';
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
  SonoraAudioHandler({ja.AudioPlayer? player})
    : _player = player ?? ja.AudioPlayer() {
    _initStreams();
  }

  final ja.AudioPlayer _player;

  /// Direct accessor for the shared production player instance.
  ja.AudioPlayer get player => _player;

  StreamSubscription<ja.PlaybackEvent>? _playbackEventSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<void>? _noisySubscription;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;

  bool _wasInterruptedPlaying = false;
  bool _audioSessionInitialized = false;

  /// External delegation callbacks to harmonize system remote events with
  /// Riverpod PlayerNotifier state.
  VoidCallback? onSkipToNext;
  VoidCallback? onSkipToPrevious;
  ValueChanged<int>? onSkipToQueueItem;
  ValueChanged<AudioServiceRepeatMode>? onSetRepeatMode;
  ValueChanged<AudioServiceShuffleMode>? onSetShuffleMode;

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
        pause();
      });

      // Handle phone call and navigation interruptions
      _interruptionSubscription = session.interruptionEventStream.listen((
        event,
      ) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(0.25);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              if (_player.playing) {
                _wasInterruptedPlaying = true;
                pause();
              }
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
              if (_wasInterruptedPlaying) {
                _wasInterruptedPlaying = false;
                play();
              }
              break;
            case AudioInterruptionType.unknown:
              _wasInterruptedPlaying = false;
              break;
          }
        }
      });
    } catch (e) {
      debugPrint('SonoraAudioHandler audio session init failed: $e');
    }
  }

  /// Maps [UiTrack] into system [MediaItem] with safe artwork URI conversion.
  MediaItem trackToMediaItem(UiTrack track) {
    Uri? artUri;
    if (track.artworkPath != null && track.artworkPath!.isNotEmpty) {
      artUri = Uri.file(track.artworkPath!);
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
  }

  /// Synchronizes current active playlist queue with system media browser.
  void updateActiveQueue(List<UiTrack> tracks) {
    queue.add(tracks.map(trackToMediaItem).toList());
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
  }

  /// Broadcasts the current player state to system notification and lock screen.
  void _broadcastState([ja.PlaybackEvent? event]) {
    final isPlaying = _player.playing;
    final processingState = _player.processingState;

    final controls = [
      MediaControl.skipToPrevious,
      if (isPlaying) MediaControl.pause else MediaControl.play,
      MediaControl.stop,
      MediaControl.skipToNext,
    ];

    playbackState.add(
      PlaybackState(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setRepeatMode,
          MediaAction.setShuffleMode,
        },
        androidCompactActionIndices: const [0, 1, 3],
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
        queueIndex: null,
      ),
    );
  }

  // --- Remote Media Control Handlers ---

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (onSkipToNext != null) {
      onSkipToNext!();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (onSkipToPrevious != null) {
      onSkipToPrevious!();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (onSkipToQueueItem != null) {
      onSkipToQueueItem!(index);
    }
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
