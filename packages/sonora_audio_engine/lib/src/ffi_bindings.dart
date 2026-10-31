// Low-level C FFI bindings for sonora_audio_engine

import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Opaque struct representing SonoraEngine C handle
final class SonoraEngineOpaque extends Opaque {}

// C function type definitions
typedef SonoraEngineCreateC =
    Pointer<SonoraEngineOpaque> Function(Uint32 sampleRate, Uint32 channels);
typedef SonoraEngineCreateDart =
    Pointer<SonoraEngineOpaque> Function(int sampleRate, int channels);

typedef SonoraEngineDestroyC =
    Void Function(Pointer<SonoraEngineOpaque> engine);
typedef SonoraEngineDestroyDart =
    void Function(Pointer<SonoraEngineOpaque> engine);

typedef SonoraEngineResetC = Int32 Function(Pointer<SonoraEngineOpaque> engine);
typedef SonoraEngineResetDart =
    int Function(Pointer<SonoraEngineOpaque> engine);

typedef SonoraEngineSetSampleRateC =
    Int32 Function(Pointer<SonoraEngineOpaque> engine, Uint32 sampleRate);
typedef SonoraEngineSetSampleRateDart =
    int Function(Pointer<SonoraEngineOpaque> engine, int sampleRate);

typedef SonoraEngineGetSampleRateC =
    Uint32 Function(Pointer<SonoraEngineOpaque> engine);
typedef SonoraEngineGetSampleRateDart =
    int Function(Pointer<SonoraEngineOpaque> engine);

typedef SonoraEngineGetChannelCountC =
    Uint32 Function(Pointer<SonoraEngineOpaque> engine);
typedef SonoraEngineGetChannelCountDart =
    int Function(Pointer<SonoraEngineOpaque> engine);

typedef SonoraEngineSetPreampGainC =
    Int32 Function(Pointer<SonoraEngineOpaque> engine, Float gainDb);
typedef SonoraEngineSetPreampGainDart =
    int Function(Pointer<SonoraEngineOpaque> engine, double gainDb);

typedef SonoraEngineGetPreampGainC =
    Float Function(Pointer<SonoraEngineOpaque> engine);
typedef SonoraEngineGetPreampGainDart =
    double Function(Pointer<SonoraEngineOpaque> engine);

typedef SonoraEngineSetLimiterEnabledC =
    Int32 Function(Pointer<SonoraEngineOpaque> engine, Int32 enabled);
typedef SonoraEngineSetLimiterEnabledDart =
    int Function(Pointer<SonoraEngineOpaque> engine, int enabled);

typedef SonoraEngineIsLimiterEnabledC =
    Int32 Function(Pointer<SonoraEngineOpaque> engine);
typedef SonoraEngineIsLimiterEnabledDart =
    int Function(Pointer<SonoraEngineOpaque> engine);

typedef SonoraEngineSetEqEnabledC =
    Int32 Function(Pointer<SonoraEngineOpaque> engine, Int32 enabled);
typedef SonoraEngineSetEqEnabledDart =
    int Function(Pointer<SonoraEngineOpaque> engine, int enabled);

typedef SonoraEngineIsEqEnabledC =
    Int32 Function(Pointer<SonoraEngineOpaque> engine);
typedef SonoraEngineIsEqEnabledDart =
    int Function(Pointer<SonoraEngineOpaque> engine);

typedef SonoraEngineInitStandardEqC =
    Int32 Function(Pointer<SonoraEngineOpaque> engine, Uint32 numBands);
typedef SonoraEngineInitStandardEqDart =
    int Function(Pointer<SonoraEngineOpaque> engine, int numBands);

typedef SonoraEngineGetEqBandCountC =
    Uint32 Function(Pointer<SonoraEngineOpaque> engine);
typedef SonoraEngineGetEqBandCountDart =
    int Function(Pointer<SonoraEngineOpaque> engine);

typedef SonoraEngineConfigureEqBandC =
    Int32 Function(
      Pointer<SonoraEngineOpaque> engine,
      Uint32 bandIndex,
      Int32 filterType,
      Float frequencyHz,
      Float qFactor,
      Float gainDb,
    );
typedef SonoraEngineConfigureEqBandDart =
    int Function(
      Pointer<SonoraEngineOpaque> engine,
      int bandIndex,
      int filterType,
      double frequencyHz,
      double qFactor,
      double gainDb,
    );

typedef SonoraEngineSetEqBandGainC =
    Int32 Function(
      Pointer<SonoraEngineOpaque> engine,
      Uint32 bandIndex,
      Float gainDb,
    );
typedef SonoraEngineSetEqBandGainDart =
    int Function(
      Pointer<SonoraEngineOpaque> engine,
      int bandIndex,
      double gainDb,
    );

typedef SonoraEngineGetEqBandGainC =
    Float Function(Pointer<SonoraEngineOpaque> engine, Uint32 bandIndex);
typedef SonoraEngineGetEqBandGainDart =
    double Function(Pointer<SonoraEngineOpaque> engine, int bandIndex);

typedef SonoraEngineGetEqBandFrequencyC =
    Float Function(Pointer<SonoraEngineOpaque> engine, Uint32 bandIndex);
typedef SonoraEngineGetEqBandFrequencyDart =
    double Function(Pointer<SonoraEngineOpaque> engine, int bandIndex);

typedef SonoraEngineProcessInterleavedC =
    Int32 Function(
      Pointer<SonoraEngineOpaque> engine,
      Pointer<Float> inSamples,
      Pointer<Float> outSamples,
      Uint32 numFrames,
    );
typedef SonoraEngineProcessInterleavedDart =
    int Function(
      Pointer<SonoraEngineOpaque> engine,
      Pointer<Float> inSamples,
      Pointer<Float> outSamples,
      int numFrames,
    );

typedef SonoraEngineProcessInplaceC =
    Int32 Function(
      Pointer<SonoraEngineOpaque> engine,
      Pointer<Float> samples,
      Uint32 numFrames,
    );
typedef SonoraEngineProcessInplaceDart =
    int Function(
      Pointer<SonoraEngineOpaque> engine,
      Pointer<Float> samples,
      int numFrames,
    );

typedef SonoraAnalysisComputeFftC =
    Int32 Function(
      Pointer<Float> pcmSamples,
      Uint32 numSamples,
      Pointer<Float> outMagnitudes,
      Uint32 fftSize,
    );
typedef SonoraAnalysisComputeFftDart =
    int Function(
      Pointer<Float> pcmSamples,
      int numSamples,
      Pointer<Float> outMagnitudes,
      int fftSize,
    );

typedef SonoraAnalysisComputeSpectrumBandsC =
    Int32 Function(
      Pointer<Float> magnitudes,
      Uint32 numMagnitudes,
      Uint32 sampleRate,
      Pointer<Float> outBands,
      Uint32 numBands,
      Float minFreq,
      Float maxFreq,
    );
typedef SonoraAnalysisComputeSpectrumBandsDart =
    int Function(
      Pointer<Float> magnitudes,
      int numMagnitudes,
      int sampleRate,
      Pointer<Float> outBands,
      int numBands,
      double minFreq,
      double maxFreq,
    );

typedef SonoraAnalysisExtractWaveformC =
    Int32 Function(
      Pointer<Float> pcmSamples,
      Uint32 numSamples,
      Uint32 channels,
      Pointer<Float> outMin,
      Pointer<Float> outMax,
      Pointer<Float> outRms,
      Uint32 numPeaks,
    );
typedef SonoraAnalysisExtractWaveformDart =
    int Function(
      Pointer<Float> pcmSamples,
      int numSamples,
      int channels,
      Pointer<Float> outMin,
      Pointer<Float> outMax,
      Pointer<Float> outRms,
      int numPeaks,
    );

typedef SonoraEngineGetVersionC = Pointer<Utf8> Function();
typedef SonoraEngineGetVersionDart = Pointer<Utf8> Function();

/// Native FFI symbol bindings container
class SonoraNativeBindings {
  SonoraNativeBindings(DynamicLibrary lib)
    : createEngine = lib
          .lookup<NativeFunction<SonoraEngineCreateC>>('sonora_engine_create')
          .asFunction(),
      destroyEngine = lib
          .lookup<NativeFunction<SonoraEngineDestroyC>>('sonora_engine_destroy')
          .asFunction(),
      resetEngine = lib
          .lookup<NativeFunction<SonoraEngineResetC>>('sonora_engine_reset')
          .asFunction(),
      setSampleRate = lib
          .lookup<NativeFunction<SonoraEngineSetSampleRateC>>(
            'sonora_engine_set_sample_rate',
          )
          .asFunction(),
      getSampleRate = lib
          .lookup<NativeFunction<SonoraEngineGetSampleRateC>>(
            'sonora_engine_get_sample_rate',
          )
          .asFunction(),
      getChannelCount = lib
          .lookup<NativeFunction<SonoraEngineGetChannelCountC>>(
            'sonora_engine_get_channel_count',
          )
          .asFunction(),
      setPreampGain = lib
          .lookup<NativeFunction<SonoraEngineSetPreampGainC>>(
            'sonora_engine_set_preamp_gain',
          )
          .asFunction(),
      getPreampGain = lib
          .lookup<NativeFunction<SonoraEngineGetPreampGainC>>(
            'sonora_engine_get_preamp_gain',
          )
          .asFunction(),
      setLimiterEnabled = lib
          .lookup<NativeFunction<SonoraEngineSetLimiterEnabledC>>(
            'sonora_engine_set_limiter_enabled',
          )
          .asFunction(),
      isLimiterEnabled = lib
          .lookup<NativeFunction<SonoraEngineIsLimiterEnabledC>>(
            'sonora_engine_is_limiter_enabled',
          )
          .asFunction(),
      setEqEnabled = lib
          .lookup<NativeFunction<SonoraEngineSetEqEnabledC>>(
            'sonora_engine_set_eq_enabled',
          )
          .asFunction(),
      isEqEnabled = lib
          .lookup<NativeFunction<SonoraEngineIsEqEnabledC>>(
            'sonora_engine_is_eq_enabled',
          )
          .asFunction(),
      initStandardEq = lib
          .lookup<NativeFunction<SonoraEngineInitStandardEqC>>(
            'sonora_engine_init_standard_eq',
          )
          .asFunction(),
      getEqBandCount = lib
          .lookup<NativeFunction<SonoraEngineGetEqBandCountC>>(
            'sonora_engine_get_eq_band_count',
          )
          .asFunction(),
      configureEqBand = lib
          .lookup<NativeFunction<SonoraEngineConfigureEqBandC>>(
            'sonora_engine_configure_eq_band',
          )
          .asFunction(),
      setEqBandGain = lib
          .lookup<NativeFunction<SonoraEngineSetEqBandGainC>>(
            'sonora_engine_set_eq_band_gain',
          )
          .asFunction(),
      getEqBandGain = lib
          .lookup<NativeFunction<SonoraEngineGetEqBandGainC>>(
            'sonora_engine_get_eq_band_gain',
          )
          .asFunction(),
      getEqBandFrequency = lib
          .lookup<NativeFunction<SonoraEngineGetEqBandFrequencyC>>(
            'sonora_engine_get_eq_band_frequency',
          )
          .asFunction(),
      processInterleaved = lib
          .lookup<NativeFunction<SonoraEngineProcessInterleavedC>>(
            'sonora_engine_process_interleaved',
          )
          .asFunction(),
      processInplace = lib
          .lookup<NativeFunction<SonoraEngineProcessInplaceC>>(
            'sonora_engine_process_inplace',
          )
          .asFunction(),
      computeFft = lib
          .lookup<NativeFunction<SonoraAnalysisComputeFftC>>(
            'sonora_analysis_compute_fft',
          )
          .asFunction(),
      computeSpectrumBands = lib
          .lookup<NativeFunction<SonoraAnalysisComputeSpectrumBandsC>>(
            'sonora_analysis_compute_spectrum_bands',
          )
          .asFunction(),
      extractWaveform = lib
          .lookup<NativeFunction<SonoraAnalysisExtractWaveformC>>(
            'sonora_analysis_extract_waveform',
          )
          .asFunction(),
      getVersion = lib
          .lookup<NativeFunction<SonoraEngineGetVersionC>>(
            'sonora_engine_get_version',
          )
          .asFunction();

  final SonoraEngineCreateDart createEngine;
  final SonoraEngineDestroyDart destroyEngine;
  final SonoraEngineResetDart resetEngine;
  final SonoraEngineSetSampleRateDart setSampleRate;
  final SonoraEngineGetSampleRateDart getSampleRate;
  final SonoraEngineGetChannelCountDart getChannelCount;
  final SonoraEngineSetPreampGainDart setPreampGain;
  final SonoraEngineGetPreampGainDart getPreampGain;
  final SonoraEngineSetLimiterEnabledDart setLimiterEnabled;
  final SonoraEngineIsLimiterEnabledDart isLimiterEnabled;
  final SonoraEngineSetEqEnabledDart setEqEnabled;
  final SonoraEngineIsEqEnabledDart isEqEnabled;
  final SonoraEngineInitStandardEqDart initStandardEq;
  final SonoraEngineGetEqBandCountDart getEqBandCount;
  final SonoraEngineConfigureEqBandDart configureEqBand;
  final SonoraEngineSetEqBandGainDart setEqBandGain;
  final SonoraEngineGetEqBandGainDart getEqBandGain;
  final SonoraEngineGetEqBandFrequencyDart getEqBandFrequency;
  final SonoraEngineProcessInterleavedDart processInterleaved;
  final SonoraEngineProcessInplaceDart processInplace;
  final SonoraAnalysisComputeFftDart computeFft;
  final SonoraAnalysisComputeSpectrumBandsDart computeSpectrumBands;
  final SonoraAnalysisExtractWaveformDart extractWaveform;
  final SonoraEngineGetVersionDart getVersion;

  static DynamicLibrary openLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libsonora_audio_engine.so');
    }
    if (Platform.isIOS) {
      return DynamicLibrary.process();
    }
    if (Platform.isMacOS) {
      const candidates = [
        'libsonora_audio_engine.dylib',
        'packages/sonora_audio_engine/libsonora_audio_engine.dylib',
        '../packages/sonora_audio_engine/libsonora_audio_engine.dylib',
        '../../packages/sonora_audio_engine/libsonora_audio_engine.dylib',
      ];
      for (final candidate in candidates) {
        try {
          return DynamicLibrary.open(candidate);
        } catch (_) {}
      }
      try {
        return DynamicLibrary.process();
      } catch (_) {}
    }
    throw UnsupportedError(
      'Unable to load native audio engine for platform: ${Platform.operatingSystem}',
    );
  }
}
