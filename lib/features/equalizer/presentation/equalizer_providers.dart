import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonora_audio_engine/sonora_audio_engine.dart';
import '../domain/equalizer_preset.dart';

/// Immutable state container for the equalizer and native DSP subsystem.
@immutable
class EqualizerState {
  const EqualizerState({
    this.isEnabled = true,
    this.bandCount = 10,
    required this.bands,
    this.activePreset = 'Flat',
    this.preampGain = 0.0,
    this.bassEnhancement = 0.0,
    this.isLimiterActive = true,
    this.customPresets = const [],
    this.isNativeEngineConnected = false,
  });

  /// Factory initializing default 10-band flat equalizer state.
  factory EqualizerState.initial() {
    final bands = List.generate(
      EqualizerPreset.k10BandFrequencies.length,
      (i) => EqualizerBand(
        index: i,
        frequency: EqualizerPreset.k10BandFrequencies[i],
        gain: 0.0,
        label: EqualizerPreset.k10BandLabels[i],
      ),
    );

    return EqualizerState(
      isEnabled: true,
      bandCount: 10,
      bands: bands,
      activePreset: 'Flat',
      preampGain: 0.0,
      bassEnhancement: 0.0,
      isLimiterActive: true,
      customPresets: const [],
      isNativeEngineConnected: false,
    );
  }

  final bool isEnabled;
  final int bandCount; // 5 or 10
  final List<EqualizerBand> bands;
  final String activePreset;
  final double preampGain; // -12.0 to +12.0 dB
  final double bassEnhancement; // 0.0 to +10.0 dB (sub-bass low shelf)
  final bool isLimiterActive;
  final List<EqualizerPreset> customPresets;
  final bool isNativeEngineConnected;

  EqualizerState copyWith({
    bool? isEnabled,
    int? bandCount,
    List<EqualizerBand>? bands,
    String? activePreset,
    double? preampGain,
    double? bassEnhancement,
    bool? isLimiterActive,
    List<EqualizerPreset>? customPresets,
    bool? isNativeEngineConnected,
  }) {
    return EqualizerState(
      isEnabled: isEnabled ?? this.isEnabled,
      bandCount: bandCount ?? this.bandCount,
      bands: bands ?? this.bands,
      activePreset: activePreset ?? this.activePreset,
      preampGain: preampGain ?? this.preampGain,
      bassEnhancement: bassEnhancement ?? this.bassEnhancement,
      isLimiterActive: isLimiterActive ?? this.isLimiterActive,
      customPresets: customPresets ?? this.customPresets,
      isNativeEngineConnected:
          isNativeEngineConnected ?? this.isNativeEngineConnected,
    );
  }

  /// Calculates composite frequency response gain in dB at an arbitrary frequency [freqHz].
  ///
  /// Evaluates peaking filter bell responses around each band center frequency,
  /// plus sub-bass enhancement and preamp gain offset.
  double calculateResponseAt(double freqHz) {
    if (!isEnabled) return 0.0;

    double totalDb = preampGain;

    // Bass enhancement modeling (sub-bass low shelf below 160Hz)
    if (bassEnhancement > 0.0) {
      final bassRatio = 120.0 / (freqHz + 20.0);
      totalDb += bassEnhancement * math.min(1.0, bassRatio * bassRatio);
    }

    // Accumulate band filter contributions
    for (final band in bands) {
      if (band.gain.abs() < 0.01) continue;

      // Approximate standard peaking filter bell response
      // bandwidth Q ~= 1.414 (about 1 octave)
      final f0 = band.frequency;
      final q = (bandCount == 5) ? 0.707 : 1.414;
      final ratio = freqHz / f0 - f0 / freqHz;
      final attenuation = 1.0 / (1.0 + (ratio * ratio * q * q));
      totalDb += band.gain * attenuation;
    }

    // Soft-knee limiter ceiling prevents visual graph clipping
    return totalDb.clamp(-18.0, 18.0);
  }
}

/// Riverpod Notifier managing Equalizer and native C++ engine parameters.
class EqualizerNotifier extends Notifier<EqualizerState> {
  SonoraAudioEngine? _nativeEngine;

  @override
  EqualizerState build() {
    _initNativeEngineSafe();
    ref.onDispose(() {
      _nativeEngine?.dispose();
      _nativeEngine = null;
    });
    return EqualizerState.initial().copyWith(
      isNativeEngineConnected: _nativeEngine != null,
    );
  }

  void _initNativeEngineSafe() {
    try {
      _nativeEngine = SonoraAudioEngine.create(sampleRate: 48000, channels: 2);
      _nativeEngine?.initStandardEq(numBands: 10);
      _nativeEngine?.isEqEnabled = true;
      _nativeEngine?.isLimiterEnabled = true;
    } catch (_) {
      // Safe fallback when native library is not available in non-native test environments
      _nativeEngine = null;
    }
  }

  /// Toggles master equalizer bypass / active state.
  void toggleEnabled() {
    final next = !state.isEnabled;
    try {
      _nativeEngine?.isEqEnabled = next;
    } catch (_) {}
    state = state.copyWith(isEnabled: next);
  }

  /// Sets active band layout (5-band graphic or 10-band ISO standard).
  void setBandCount(int count) {
    if (count != 5 && count != 10) return;
    if (state.bandCount == count) return;

    final List<double> freqs = (count == 5)
        ? EqualizerPreset.k5BandFrequencies
        : EqualizerPreset.k10BandFrequencies;

    final List<String> labels = (count == 5)
        ? EqualizerPreset.k5BandLabels
        : EqualizerPreset.k10BandLabels;

    try {
      _nativeEngine?.initStandardEq(numBands: count);
    } catch (_) {}

    // Find current preset or match gains
    final activePresetObj = EqualizerPreset.builtInPresets.firstWhere(
      (p) => p.name == state.activePreset,
      orElse: () => EqualizerPreset.builtInPresets.first,
    );

    final gains = (count == 5)
        ? activePresetObj.fiveBandGains
        : activePresetObj.tenBandGains;

    final newBands = List.generate(
      count,
      (i) => EqualizerBand(
        index: i,
        frequency: freqs[i],
        gain: (i < gains.length) ? gains[i] : 0.0,
        label: labels[i],
      ),
    );

    for (int i = 0; i < count; i++) {
      try {
        _nativeEngine?.setEqBandGain(i, newBands[i].gain);
      } catch (_) {}
    }

    state = state.copyWith(bandCount: count, bands: newBands);
  }

  /// Sets gain in decibels (-12.0 dB to +12.0 dB) for a specific band index.
  void setBandGain(int index, double gainDb) {
    if (index < 0 || index >= state.bands.length) return;

    final clampedGain = gainDb.clamp(-12.0, 12.0);
    final updatedBands = List<EqualizerBand>.from(state.bands);
    updatedBands[index] = updatedBands[index].copyWith(gain: clampedGain);

    try {
      _nativeEngine?.setEqBandGain(index, clampedGain);
    } catch (_) {}

    state = state.copyWith(bands: updatedBands, activePreset: 'Custom');
  }

  /// Sets master preamp gain (-12.0 dB to +12.0 dB).
  void setPreampGain(double gainDb) {
    final clamped = gainDb.clamp(-12.0, 12.0);
    try {
      _nativeEngine?.preampGain = clamped;
    } catch (_) {}
    state = state.copyWith(preampGain: clamped);
  }

  /// Sets sub-bass enhancement gain (0.0 dB to +10.0 dB).
  void setBassEnhancement(double gainDb) {
    final clamped = gainDb.clamp(0.0, 10.0);
    state = state.copyWith(bassEnhancement: clamped);
  }

  /// Toggles output soft-knee limiter.
  void toggleLimiter() {
    final next = !state.isLimiterActive;
    try {
      _nativeEngine?.isLimiterEnabled = next;
    } catch (_) {}
    state = state.copyWith(isLimiterActive: next);
  }

  /// Applies a named built-in or custom preset.
  void applyPreset(String presetName) {
    final allPresets = [
      ...EqualizerPreset.builtInPresets,
      ...state.customPresets,
    ];

    final preset = allPresets.firstWhere(
      (p) => p.name == presetName,
      orElse: () => EqualizerPreset.builtInPresets.first,
    );

    final gains = (state.bandCount == 5)
        ? preset.fiveBandGains
        : preset.tenBandGains;

    final updatedBands = List.generate(state.bands.length, (i) {
      final gain = (i < gains.length) ? gains[i] : 0.0;
      try {
        _nativeEngine?.setEqBandGain(i, gain);
      } catch (_) {}
      return state.bands[i].copyWith(gain: gain);
    });

    state = state.copyWith(activePreset: presetName, bands: updatedBands);
  }

  /// Resets all bands and preamp to 0.0 dB flat.
  void resetAllToFlat() {
    applyPreset('Flat');
    setPreampGain(0.0);
    setBassEnhancement(0.0);
  }

  /// Saves current band configuration as a user custom preset.
  void saveCustomPreset(String name) {
    if (name.trim().isEmpty) return;

    final trimmedName = name.trim();
    final currentGains = state.bands.map((b) => b.gain).toList();

    // Preserve 5 or 10 band layout
    final fiveGains = (state.bandCount == 5)
        ? currentGains
        : [
            currentGains[1], // ~60Hz
            currentGains[3], // ~250Hz
            currentGains[5], // ~1kHz
            currentGains[7], // ~4kHz
            currentGains[9], // ~16kHz
          ];

    final tenGains = (state.bandCount == 10)
        ? currentGains
        : [
            currentGains[0] * 0.8,
            currentGains[0],
            currentGains[1] * 0.9,
            currentGains[1],
            currentGains[2] * 0.9,
            currentGains[2],
            currentGains[3] * 0.9,
            currentGains[3],
            currentGains[4] * 0.9,
            currentGains[4],
          ];

    final newPreset = EqualizerPreset(
      name: trimmedName,
      isBuiltIn: false,
      fiveBandGains: fiveGains,
      tenBandGains: tenGains,
    );

    final updated = List<EqualizerPreset>.from(state.customPresets)
      ..removeWhere((p) => p.name == trimmedName)
      ..add(newPreset);

    state = state.copyWith(customPresets: updated, activePreset: trimmedName);
  }

  /// Deletes a user custom preset.
  void deleteCustomPreset(String name) {
    final updated = List<EqualizerPreset>.from(state.customPresets)
      ..removeWhere((p) => p.name == name);

    state = state.copyWith(
      customPresets: updated,
      activePreset: state.activePreset == name ? 'Flat' : state.activePreset,
    );
  }
}

/// Global Riverpod provider for the Equalizer subsystem.
final equalizerProvider = NotifierProvider<EqualizerNotifier, EqualizerState>(
  EqualizerNotifier.new,
);
