import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora_audio_engine/sonora_audio_engine.dart';

void main() {
  group('SONORA Root Native Audio Engine Integration Tests', () {
    test('Can query C++ audio engine version', () {
      final version = SonoraAudioEngine.getVersion();
      expect(version, startsWith('1.0.0'));
    });

    test(
      'Engine allocates, processes audio buffer, and frees resources safely',
      () {
        final engine = SonoraAudioEngine.create(sampleRate: 48000, channels: 2);
        expect(engine.sampleRate, equals(48000));
        expect(engine.channels, equals(2));
        expect(engine.eqBandCount, equals(10));

        const frames = 256;
        final input = Float32List(frames * 2);
        for (int i = 0; i < frames; i++) {
          final sample = 0.3 * math.sin(2.0 * math.pi * 440.0 * i / 48000.0);
          input[i * 2] = sample;
          input[i * 2 + 1] = sample;
        }

        final output = Float32List(frames * 2);
        engine.processInterleaved(input, output);
        expect(output.length, equals(frames * 2));

        // In-place processing
        final inplace = Float32List.fromList(input);
        engine.processInplace(inplace);
        expect(inplace.length, equals(frames * 2));

        engine.dispose();
        expect(engine.isDisposed, isTrue);
      },
    );

    test('FFT spectrum analysis and waveform extraction from root app', () {
      const fftSize = 512;
      final samples = Float32List(fftSize);
      for (int i = 0; i < fftSize; i++) {
        samples[i] = math.sin(2.0 * math.pi * 937.5 * i / 48000.0); // Bin 10
      }

      final magnitudes = SonoraAudioEngine.computeFft(
        samples,
        fftSize: fftSize,
      );
      expect(magnitudes.length, equals(256));

      int peakBin = 0;
      double peakVal = -999.0;
      for (int i = 0; i < magnitudes.length; i++) {
        if (magnitudes[i] > peakVal) {
          peakVal = magnitudes[i];
          peakBin = i;
        }
      }
      expect(peakBin, inInclusiveRange(9, 11));

      final bands = SonoraAudioEngine.computeSpectrumBands(
        magnitudes,
        sampleRate: 48000,
        numBands: 8,
      );
      expect(bands.length, equals(8));

      final waveform = SonoraAudioEngine.extractWaveform(
        samples,
        channels: 1,
        numPeaks: 10,
      );
      expect(waveform.length, equals(10));
    });
  });
}
