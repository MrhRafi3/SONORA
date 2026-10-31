import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/app/theme/app_theme.dart';
import 'package:sonora/features/equalizer/presentation/equalizer_providers.dart';
import 'package:sonora/features/equalizer/presentation/equalizer_screen.dart';
import 'package:sonora/features/equalizer/presentation/widgets/frequency_response_graph.dart';
import 'package:sonora/features/equalizer/presentation/widgets/spectrum_visualizer.dart';
import 'package:sonora/features/player/domain/ui_track.dart';
import 'package:sonora/features/player/presentation/player_state.dart';
import 'package:sonora/features/player/presentation/widgets/audio_inspector_sheet.dart';
import 'package:sonora/features/player/presentation/widgets/lyrics_sheet.dart';
import 'package:sonora/features/player/presentation/widgets/waveform_progress_bar.dart';

void main() {
  group('Equalizer Domain & Notifier Unit Tests', () {
    test('Initial state defaults to 10 bands flat', () {
      final state = EqualizerState.initial();
      expect(state.isEnabled, isTrue);
      expect(state.bandCount, equals(10));
      expect(state.bands.length, equals(10));
      expect(state.activePreset, equals('Flat'));
      expect(state.preampGain, equals(0.0));
      expect(state.bassEnhancement, equals(0.0));
      expect(state.isLimiterActive, isTrue);

      for (final band in state.bands) {
        expect(band.gain, equals(0.0));
      }
    });

    test('Frequency response calculation models filter response', () {
      final state = EqualizerState.initial();
      // Flat response produces 0 dB
      expect(state.calculateResponseAt(1000.0), closeTo(0.0, 0.01));

      // With preamp
      final boostedPreamp = state.copyWith(preampGain: 3.0);
      expect(boostedPreamp.calculateResponseAt(1000.0), closeTo(3.0, 0.01));

      // With band boost at 1 kHz
      final boosted1k = state.copyWith(
        bands: state.bands
            .map((b) => b.frequency == 1000.0 ? b.copyWith(gain: 6.0) : b)
            .toList(),
      );
      expect(boosted1k.calculateResponseAt(1000.0), closeTo(6.0, 0.5));

      // Bypass produces 0 dB
      final bypassed = boosted1k.copyWith(isEnabled: false);
      expect(bypassed.calculateResponseAt(1000.0), equals(0.0));
    });

    test('Notifier toggles enabled, switches bands, and applies presets', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(equalizerProvider.notifier);

      // Toggle enabled
      notifier.toggleEnabled();
      expect(container.read(equalizerProvider).isEnabled, isFalse);
      notifier.toggleEnabled();
      expect(container.read(equalizerProvider).isEnabled, isTrue);

      // Switch to 5 bands
      notifier.setBandCount(5);
      var state = container.read(equalizerProvider);
      expect(state.bandCount, equals(5));
      expect(state.bands.length, equals(5));

      // Apply Bass Boost preset
      notifier.applyPreset('Bass Boost');
      state = container.read(equalizerProvider);
      expect(state.activePreset, equals('Bass Boost'));
      expect(state.bands[0].gain, greaterThan(3.0));

      // Adjust band gain -> custom preset
      notifier.setBandGain(2, 4.0);
      state = container.read(equalizerProvider);
      expect(state.activePreset, equals('Custom'));
      expect(state.bands[2].gain, closeTo(4.0, 0.01));

      // Save custom preset
      notifier.saveCustomPreset('My Rock');
      state = container.read(equalizerProvider);
      expect(state.customPresets.any((p) => p.name == 'My Rock'), isTrue);
      expect(state.activePreset, equals('My Rock'));

      // Delete custom preset
      notifier.deleteCustomPreset('My Rock');
      state = container.read(equalizerProvider);
      expect(state.customPresets.any((p) => p.name == 'My Rock'), isFalse);

      // Reset to flat
      notifier.resetAllToFlat();
      state = container.read(equalizerProvider);
      expect(state.activePreset, equals('Flat'));
      expect(state.preampGain, equals(0.0));
      expect(state.bassEnhancement, equals(0.0));
    });
  });

  group('EqualizerScreen Widget Tests', () {
    testWidgets(
      'Renders EqualizerScreen with DSP core, frequency graph, and sliders',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const EqualizerScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Title & Top Card
        expect(find.text('Equalizer & DSP'), findsOneWidget);
        expect(find.text('C++17 Biquad DSP Core'), findsOneWidget);
        expect(find.byType(FrequencyResponseGraph), findsOneWidget);
        expect(find.byType(SegmentedButton<int>), findsOneWidget);

        // Presets
        expect(find.text('Flat'), findsOneWidget);
        expect(find.text('Bass Boost'), findsOneWidget);
        expect(find.text('Vocal Clarity'), findsOneWidget);

        // Sliders & Controls
        expect(find.text('Preamp Gain'), findsOneWidget);
        expect(find.text('Bass Enhancement'), findsOneWidget);
        expect(find.text('Soft Limiter'), findsOneWidget);
        expect(find.byType(SpectrumVisualizerWidget), findsOneWidget);

        // Tap Bass Boost preset
        await tester.tap(find.text('Bass Boost'));
        await tester.pumpAndSettle();

        // Switch to 5 Bands
        await tester.tap(find.text('5 Bands'));
        await tester.pumpAndSettle();
        expect(find.text('60 Hz'), findsOneWidget);
        expect(find.text('230 Hz'), findsOneWidget);

        // Reset to flat
        final resetBtn = find.byTooltip('Reset to Flat (0 dB)');
        expect(resetBtn, findsOneWidget);
        await tester.tap(resetBtn);
        await tester.pumpAndSettle();

        // Clean unmount
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });

  group('WaveformProgressBar & Audio Sheets Tests', () {
    testWidgets('WaveformProgressBar renders and handles drag seeking', (
      tester,
    ) async {
      double seekedValue = -1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 40,
                child: WaveformProgressBar(
                  progress: 0.35,
                  duration: const Duration(minutes: 3),
                  onSeek: (val) => seekedValue = val,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WaveformProgressBar), findsOneWidget);

      // Tap at center (progress ~ 0.5)
      await tester.tap(find.byType(WaveformProgressBar));
      await tester.pumpAndSettle();

      expect(seekedValue, inInclusiveRange(0.4, 0.6));
    });

    testWidgets(
      'AudioInspectorSheet displays technical specs and codec metadata',
      (tester) async {
        const track = UiTrack(
          id: 'test-hi-res',
          title: 'Symphony No. 5 in C Minor',
          artist: 'Vienna Philharmonic',
          album: 'Beethoven Masterworks',
          duration: Duration(minutes: 7, seconds: 20),
          audioFormat: 'FLAC',
          sampleRate: '192 kHz',
          bitDepth: '24-bit',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: AudioInspectorSheet(track: track)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Technical Audio Inspector'), findsOneWidget);
        expect(find.text('Symphony No. 5 in C Minor'), findsOneWidget);
        expect(find.text('Audio Codec'), findsOneWidget);
        expect(find.text('FLAC'), findsOneWidget);
        expect(find.text('192 kHz'), findsOneWidget);
        expect(find.text('24-bit'), findsOneWidget);
        expect(find.text('C++17 Direct Form II Transposed'), findsOneWidget);
      },
    );

    testWidgets('LyricsSheet renders synchronized lines and master notes tab', (
      tester,
    ) async {
      final track = kShowcaseTracks.first;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(body: LyricsSheet(track: track)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Synced Lyrics'), findsOneWidget);
      expect(find.text('Master Notes'), findsOneWidget);
      expect(find.textContaining('Clair de Lune'), findsOneWidget);

      // Switch to Master Notes tab
      await tester.tap(find.text('Master Notes'));
      await tester.pumpAndSettle();

      expect(find.text('Audiophile Master Metadata'), findsOneWidget);
      expect(
        find.text('Direct-to-Analogue Dual Ribbon Capture'),
        findsOneWidget,
      );
      expect(find.text('Liner Notes & Provenance'), findsOneWidget);
    });
  });
}
