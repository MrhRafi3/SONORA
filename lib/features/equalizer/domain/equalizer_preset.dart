import 'package:flutter/foundation.dart';

/// Represents a single equalizer band with frequency, gain, and display label.
@immutable
class EqualizerBand {
  const EqualizerBand({
    required this.index,
    required this.frequency,
    required this.gain,
    required this.label,
  });

  final int index;
  final double frequency; // Frequency in Hz
  final double gain; // Gain in dB (-12.0 to +12.0)
  final String label; // Display label (e.g., "60 Hz", "1 kHz")

  EqualizerBand copyWith({
    int? index,
    double? frequency,
    double? gain,
    String? label,
  }) {
    return EqualizerBand(
      index: index ?? this.index,
      frequency: frequency ?? this.frequency,
      gain: gain ?? this.gain,
      label: label ?? this.label,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EqualizerBand &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          frequency == other.frequency &&
          gain == other.gain &&
          label == other.label;

  @override
  int get hashCode => Object.hash(index, frequency, gain, label);
}

/// Equalizer preset definition with predefined frequency response profiles.
@immutable
class EqualizerPreset {
  const EqualizerPreset({
    required this.name,
    required this.isBuiltIn,
    required this.fiveBandGains,
    required this.tenBandGains,
  });

  final String name;
  final bool isBuiltIn;
  final List<double> fiveBandGains;
  final List<double> tenBandGains;

  // Standard 5-band ISO center frequencies
  static const List<double> k5BandFrequencies = [
    60.0,
    230.0,
    910.0,
    3600.0,
    14000.0,
  ];

  static const List<String> k5BandLabels = [
    '60 Hz',
    '230 Hz',
    '910 Hz',
    '3.6 kHz',
    '14 kHz',
  ];

  // Standard 10-band ISO center frequencies
  static const List<double> k10BandFrequencies = [
    31.25,
    62.5,
    125.0,
    250.0,
    500.0,
    1000.0,
    2000.0,
    4000.0,
    8000.0,
    16000.0,
  ];

  static const List<String> k10BandLabels = [
    '31 Hz',
    '62 Hz',
    '125 Hz',
    '250 Hz',
    '500 Hz',
    '1 kHz',
    '2 kHz',
    '4 kHz',
    '8 kHz',
    '16 kHz',
  ];

  static List<EqualizerPreset> get builtInPresets => const [
    EqualizerPreset(
      name: 'Flat',
      isBuiltIn: true,
      fiveBandGains: [0.0, 0.0, 0.0, 0.0, 0.0],
      tenBandGains: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    ),
    EqualizerPreset(
      name: 'Bass Boost',
      isBuiltIn: true,
      fiveBandGains: [5.5, 3.0, 0.0, -1.0, 0.5],
      tenBandGains: [6.0, 5.5, 4.0, 2.0, 0.5, 0.0, 0.0, -0.5, -1.0, 0.5],
    ),
    EqualizerPreset(
      name: 'Vocal Clarity',
      isBuiltIn: true,
      fiveBandGains: [-2.0, 0.5, 4.0, 3.5, 1.0],
      tenBandGains: [-2.5, -2.0, -0.5, 1.0, 3.0, 4.5, 3.5, 2.0, 1.0, 0.5],
    ),
    EqualizerPreset(
      name: 'Acoustic',
      isBuiltIn: true,
      fiveBandGains: [2.0, 1.0, 0.0, 2.5, 3.0],
      tenBandGains: [2.5, 2.0, 1.0, 0.5, 0.0, 1.0, 2.0, 3.0, 3.5, 3.0],
    ),
    EqualizerPreset(
      name: 'Electronic',
      isBuiltIn: true,
      fiveBandGains: [4.5, 3.5, -1.0, 2.0, 3.5],
      tenBandGains: [5.0, 4.5, 3.0, 0.5, -1.0, 0.0, 1.5, 2.5, 3.5, 4.0],
    ),
    EqualizerPreset(
      name: 'Rock',
      isBuiltIn: true,
      fiveBandGains: [4.0, 2.0, -1.5, 1.5, 3.5],
      tenBandGains: [4.5, 4.0, 2.5, 0.0, -1.5, -0.5, 1.0, 2.0, 3.0, 4.0],
    ),
    EqualizerPreset(
      name: 'Classical',
      isBuiltIn: true,
      fiveBandGains: [3.0, 1.5, 0.0, 2.0, 2.5],
      tenBandGains: [3.5, 3.0, 2.0, 1.0, 0.0, 0.5, 1.5, 2.0, 2.5, 3.0],
    ),
    EqualizerPreset(
      name: 'Jazz',
      isBuiltIn: true,
      fiveBandGains: [2.5, 1.0, 2.0, 1.5, 2.0],
      tenBandGains: [3.0, 2.5, 1.5, 0.5, 1.5, 2.0, 1.5, 1.0, 2.0, 2.5],
    ),
    EqualizerPreset(
      name: 'Treble Air',
      isBuiltIn: true,
      fiveBandGains: [0.0, -1.0, 1.0, 4.0, 6.0],
      tenBandGains: [0.0, -0.5, -1.0, 0.0, 0.5, 1.5, 2.5, 4.0, 5.5, 6.5],
    ),
    EqualizerPreset(
      name: 'Warm Tube',
      isBuiltIn: true,
      fiveBandGains: [3.5, 2.0, 1.0, 0.0, -1.5],
      tenBandGains: [4.0, 3.5, 2.5, 1.5, 1.0, 0.5, 0.0, -0.5, -1.0, -2.0],
    ),
  ];
}
