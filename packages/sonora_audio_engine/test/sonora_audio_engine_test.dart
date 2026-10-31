import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora_audio_engine/sonora_audio_engine.dart';

void main() {
  group('SonoraAudioEngine Dart FFI Tests', () {
    test('getVersion returns valid semantic version', () {
      final version = SonoraAudioEngine.getVersion();
      expect(version, isNotEmpty);
      expect(version, contains('1.0.0'));
    });

    test('Engine lifecycle and default parameters', () {
      final engine = SonoraAudioEngine.create(sampleRate: 48000, channels: 2);
      expect(engine.isDisposed, isFalse);
      expect(engine.sampleRate, equals(48000));
      expect(engine.channels, equals(2));
      expect(engine.preampGain, closeTo(0.0, 0.01));
      expect(engine.isLimiterEnabled, isTrue);
      expect(engine.isEqEnabled, isTrue);
      expect(engine.eqBandCount, equals(10));

      // Test parameter modification
      engine.preampGain = 2.5;
      expect(engine.preampGain, closeTo(2.5, 0.01));

      engine.isLimiterEnabled = false;
      expect(engine.isLimiterEnabled, isFalse);

      engine.isEqEnabled = false;
      expect(engine.isEqEnabled, isFalse);

      engine.sampleRate = 96000;
      expect(engine.sampleRate, equals(96000));

      engine.dispose();
      expect(engine.isDisposed, isTrue);
      expect(() => engine.reset(), throwsStateError);
      expect(() => engine.preampGain, throwsStateError);
    });

    test('Equalizer ISO standard bands and configuration', () {
      final engine = SonoraAudioEngine.create(sampleRate: 48000, channels: 2);

      // Verify 10-band standard frequencies
      expect(engine.eqBandCount, equals(10));
      expect(engine.getEqBandFrequency(0), closeTo(31.25, 0.5));
      expect(engine.getEqBandFrequency(5), closeTo(1000.0, 1.0));
      expect(engine.getEqBandFrequency(9), closeTo(16000.0, 1.0));

      // Set band gains
      engine.setEqBandGain(5, 4.5);
      expect(engine.getEqBandGain(5), closeTo(4.5, 0.01));

      // Switch to 5-band configuration
      engine.initStandardEq(numBands: 5);
      expect(engine.eqBandCount, equals(5));
      expect(engine.getEqBandFrequency(0), closeTo(60.0, 1.0));
      expect(engine.getEqBandFrequency(2), closeTo(910.0, 1.0));

      // Configure custom band
      engine.configureEqBand(
        2,
        filterType: SonoraFilterType.peaking,
        frequencyHz: 1200.0,
        qFactor: 1.5,
        gainDb: -3.0,
      );
      expect(engine.getEqBandFrequency(2), closeTo(1200.0, 1.0));
      expect(engine.getEqBandGain(2), closeTo(-3.0, 0.01));

      engine.dispose();
    });

    test('Audio buffer processing interleaved and in-place', () {
      final engine = SonoraAudioEngine.create(sampleRate: 48000, channels: 2);
      const numFrames = 512;
      const numSamples = numFrames * 2;

      final inSamples = Float32List(numSamples);
      for (int i = 0; i < numFrames; i++) {
        final val = 0.5 * math.sin(2.0 * math.pi * 1000.0 * i / 48000.0);
        inSamples[i * 2] = val;
        inSamples[i * 2 + 1] = val;
      }

      // Test processInterleaved
      final outSamples = Float32List(numSamples);
      engine.processInterleaved(inSamples, outSamples);
      expect(outSamples.length, equals(numSamples));

      // Flat EQ -> output matches input closely
      for (int i = 0; i < 50; i++) {
        expect(outSamples[i], closeTo(inSamples[i], 0.01));
      }

      // Test processInplace
      final inPlaceBuffer = Float32List.fromList(inSamples);
      engine.processInplace(inPlaceBuffer);
      for (int i = 0; i < 50; i++) {
        expect(inPlaceBuffer[i], closeTo(inSamples[i], 0.01));
      }

      engine.dispose();
    });

    test('FFT spectral analysis and peak bin detection', () {
      const fftSize = 1024;
      const sampleRate = 48000;
      const targetFreq = 1875.0; // Bin 40

      final pcm = Float32List(fftSize);
      for (int i = 0; i < fftSize; i++) {
        pcm[i] = math.sin(2.0 * math.pi * targetFreq * i / sampleRate);
      }

      final magnitudes = SonoraAudioEngine.computeFft(pcm, fftSize: fftSize);
      expect(magnitudes.length, equals(fftSize ~/ 2));

      int peakBin = 0;
      double peakMag = -999.0;
      for (int i = 0; i < magnitudes.length; i++) {
        if (magnitudes[i] > peakMag) {
          peakMag = magnitudes[i];
          peakBin = i;
        }
      }
      expect(peakBin, inInclusiveRange(39, 41));

      // Test spectrum band grouping
      final bands = SonoraAudioEngine.computeSpectrumBands(
        magnitudes,
        sampleRate: sampleRate,
        numBands: 16,
      );
      expect(bands.length, equals(16));

      int maxBand = 0;
      double maxVal = 0.0;
      for (int b = 0; b < bands.length; b++) {
        if (bands[b] > maxVal) {
          maxVal = bands[b];
          maxBand = b;
        }
      }
      expect(maxBand, inInclusiveRange(8, 12));
    });

    test('Waveform peak and RMS extraction', () {
      const numFrames = 5000;
      const channels = 2;
      const numPeaks = 50;
      final pcm = Float32List(numFrames * channels);

      for (int i = 0; i < numFrames; i++) {
        final val = 0.8 * math.sin(2.0 * math.pi * 2000.0 * i / 48000.0);
        pcm[i * 2] = val;
        pcm[i * 2 + 1] = val;
      }

      final waveform = SonoraAudioEngine.extractWaveform(
        pcm,
        channels: channels,
        numPeaks: numPeaks,
      );

      expect(waveform.length, equals(numPeaks));
      expect(waveform.min.length, equals(numPeaks));
      expect(waveform.max.length, equals(numPeaks));
      expect(waveform.rms.length, equals(numPeaks));

      for (int i = 0; i < numPeaks; i++) {
        expect(waveform.min[i], inInclusiveRange(-0.85, -0.75));
        expect(waveform.max[i], inInclusiveRange(0.75, 0.85));
        expect(waveform.rms[i], inInclusiveRange(0.50, 0.65));
      }
    });
  });
}
