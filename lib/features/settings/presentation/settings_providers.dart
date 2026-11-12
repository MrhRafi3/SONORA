import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/app_preferences_service.dart';

/// Immutable container holding user playback, audio processing, and system preferences.
@immutable
class SettingsState {
  const SettingsState({
    this.bitPerfectOutput = true,
    this.replayGain = true,
    this.gaplessPlayback = true,
    this.crossfadeSeconds = 2.0,
    this.pauseOnDisconnect = true,
    this.highResDirectDac = true,
    this.systemMediaControls = true,
    this.lockScreenArtwork = true,
  });

  final bool bitPerfectOutput;
  final bool replayGain;
  final bool gaplessPlayback;
  final double crossfadeSeconds;
  final bool pauseOnDisconnect;
  final bool highResDirectDac;
  final bool systemMediaControls;
  final bool lockScreenArtwork;

  SettingsState copyWith({
    bool? bitPerfectOutput,
    bool? replayGain,
    bool? gaplessPlayback,
    double? crossfadeSeconds,
    bool? pauseOnDisconnect,
    bool? highResDirectDac,
    bool? systemMediaControls,
    bool? lockScreenArtwork,
  }) {
    return SettingsState(
      bitPerfectOutput: bitPerfectOutput ?? this.bitPerfectOutput,
      replayGain: replayGain ?? this.replayGain,
      gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
      crossfadeSeconds: crossfadeSeconds ?? this.crossfadeSeconds,
      pauseOnDisconnect: pauseOnDisconnect ?? this.pauseOnDisconnect,
      highResDirectDac: highResDirectDac ?? this.highResDirectDac,
      systemMediaControls: systemMediaControls ?? this.systemMediaControls,
      lockScreenArtwork: lockScreenArtwork ?? this.lockScreenArtwork,
    );
  }
}

/// StateNotifier managing app-wide settings persistence and reactive updates.
class SettingsNotifier extends Notifier<SettingsState> {
  static const _pauseOnDisconnectKey = 'pause_on_disconnect';
  bool _hasPauseOnDisconnectOverride = false;

  @override
  SettingsState build() {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      unawaited(_hydrate());
    }
    return const SettingsState();
  }

  Future<void> _hydrate() async {
    final prefs = await const AppPreferencesService().loadAll();
    if (!ref.mounted || _hasPauseOnDisconnectOverride) return;
    final pauseOnDisconnect = prefs[_pauseOnDisconnectKey];
    if (pauseOnDisconnect is bool) {
      state = state.copyWith(pauseOnDisconnect: pauseOnDisconnect);
    }
  }

  void setBitPerfect(bool enabled) {
    state = state.copyWith(bitPerfectOutput: enabled);
  }

  void setReplayGain(bool enabled) {
    state = state.copyWith(replayGain: enabled);
  }

  void setGapless(bool enabled) {
    state = state.copyWith(gaplessPlayback: enabled);
  }

  void setCrossfade(double seconds) {
    state = state.copyWith(crossfadeSeconds: seconds.clamp(0.0, 8.0));
  }

  void setPauseOnDisconnect(bool enabled) {
    _hasPauseOnDisconnectOverride = true;
    state = state.copyWith(pauseOnDisconnect: enabled);
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      unawaited(
        const AppPreferencesService().updateKey(_pauseOnDisconnectKey, enabled),
      );
    }
  }

  void setHighResDirectDac(bool enabled) {
    state = state.copyWith(highResDirectDac: enabled);
  }

  void setSystemMediaControls(bool enabled) {
    state = state.copyWith(systemMediaControls: enabled);
  }

  void setLockScreenArtwork(bool enabled) {
    state = state.copyWith(lockScreenArtwork: enabled);
  }
}

/// Provider exposing reactive settings state.
final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
