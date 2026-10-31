import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

import 'src/ffi_bindings.dart';

/// Available bi-quad filter topology types for equalizer bands.
enum SonoraFilterType {
  peaking(0),
  lowShelf(1),
  highShelf(2),
  lowPass(3),
  highPass(4),
  bandPass(5),
  notch(6);

  const SonoraFilterType(this.value);
  final int value;
}

/// Extracted waveform visualization representation.
class WaveformData {
  const WaveformData({required this.min, required this.max, required this.rms});

  /// Array of minimum sample peaks per block (-1.0 to 0.0).
  final Float32List min;

  /// Array of maximum sample peaks per block (0.0 to 1.0).
  final Float32List max;

  /// Array of root-mean-square energy levels per block (0.0 to 1.0).
  final Float32List rms;

  /// Number of peak chunks extracted.
  int get length => min.length;
}

/// High-performance native audio processing engine for SONORA.
///
/// Wraps native C++ DSP core with safe typed-data operations, automatic
/// lifecycle management, and zero garbage collection overhead during playback.
class SonoraAudioEngine {
  SonoraAudioEngine._(this._handle, this._bindings) {
    _finalizer.attach(this, _handle, detach: this);
  }

  static SonoraNativeBindings? _sharedBindings;
  static SonoraNativeBindings get _bindingsInstance => _sharedBindings ??=
      SonoraNativeBindings(SonoraNativeBindings.openLibrary());

  static final Finalizer<Pointer<SonoraEngineOpaque>> _finalizer = Finalizer((
    handle,
  ) {
    _bindingsInstance.destroyEngine(handle);
  });

  final Pointer<SonoraEngineOpaque> _handle;
  final SonoraNativeBindings _bindings;
  bool _isDisposed = false;

  /// Creates and initializes a native Sonora audio engine instance.
  ///
  /// [sampleRate] defaults to 48000 Hz.
  /// [channels] must be 1 (Mono) or 2 (Stereo).
  factory SonoraAudioEngine.create({int sampleRate = 48000, int channels = 2}) {
    final bindings = _bindingsInstance;
    final handle = bindings.createEngine(sampleRate, channels);
    if (handle == nullptr) {
      throw StateError('Failed to allocate native SonoraAudioEngine.');
    }
    return SonoraAudioEngine._(handle, bindings);
  }

  /// Returns true if the native resources have been released.
  bool get isDisposed => _isDisposed;

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('SonoraAudioEngine has already been disposed.');
    }
  }

  /// Releases native memory and destroys the C++ engine instance.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _finalizer.detach(this);
    _bindings.destroyEngine(_handle);
  }

  /// Resets all internal filter delay buffers to silence.
  void reset() {
    _checkDisposed();
    _bindings.resetEngine(_handle);
  }

  /// Current sample rate in Hz.
  int get sampleRate {
    _checkDisposed();
    return _bindings.getSampleRate(_handle);
  }

  set sampleRate(int value) {
    _checkDisposed();
    _bindings.setSampleRate(_handle, value);
  }

  /// Number of interleaved channels (1 or 2).
  int get channels {
    _checkDisposed();
    return _bindings.getChannelCount(_handle);
  }

  /// Master preamp gain in decibels.
  double get preampGain {
    _checkDisposed();
    return _bindings.getPreampGain(_handle);
  }

  set preampGain(double value) {
    _checkDisposed();
    _bindings.setPreampGain(_handle, value);
  }

  /// Output soft-knee limiter state.
  bool get isLimiterEnabled {
    _checkDisposed();
    return _bindings.isLimiterEnabled(_handle) != 0;
  }

  set isLimiterEnabled(bool value) {
    _checkDisposed();
    _bindings.setLimiterEnabled(_handle, value ? 1 : 0);
  }

  /// Equalizer active state.
  bool get isEqEnabled {
    _checkDisposed();
    return _bindings.isEqEnabled(_handle) != 0;
  }

  set isEqEnabled(bool value) {
    _checkDisposed();
    _bindings.setEqEnabled(_handle, value ? 1 : 0);
  }

  /// Number of configured equalizer bands.
  int get eqBandCount {
    _checkDisposed();
    return _bindings.getEqBandCount(_handle);
  }

  /// Initializes standard ISO graphic equalizer frequencies.
  /// [numBands] must be 5 or 10.
  void initStandardEq({int numBands = 10}) {
    _checkDisposed();
    final res = _bindings.initStandardEq(_handle, numBands);
    if (res != 0) {
      throw ArgumentError(
        'Invalid number of bands: $numBands (must be 5 or 10)',
      );
    }
  }

  /// Sets gain in decibels for an individual EQ band.
  void setEqBandGain(int bandIndex, double gainDb) {
    _checkDisposed();
    final res = _bindings.setEqBandGain(_handle, bandIndex, gainDb);
    if (res != 0) {
      throw RangeError.index(bandIndex, this, 'bandIndex', null, eqBandCount);
    }
  }

  /// Gets gain in decibels for an individual EQ band.
  double getEqBandGain(int bandIndex) {
    _checkDisposed();
    return _bindings.getEqBandGain(_handle, bandIndex);
  }

  /// Gets center frequency in Hz for an individual EQ band.
  double getEqBandFrequency(int bandIndex) {
    _checkDisposed();
    return _bindings.getEqBandFrequency(_handle, bandIndex);
  }

  /// Configures custom parametric EQ band parameters.
  void configureEqBand(
    int bandIndex, {
    required SonoraFilterType filterType,
    required double frequencyHz,
    required double qFactor,
    required double gainDb,
  }) {
    _checkDisposed();
    final res = _bindings.configureEqBand(
      _handle,
      bandIndex,
      filterType.value,
      frequencyHz,
      qFactor,
      gainDb,
    );
    if (res != 0) {
      throw ArgumentError(
        'Failed to configure band $bandIndex with params ($frequencyHz Hz, Q=$qFactor, gain=$gainDb dB)',
      );
    }
  }

  /// Processes interleaved PCM audio frames from [inSamples] into [outSamples].
  void processInterleaved(Float32List inSamples, Float32List outSamples) {
    _checkDisposed();
    final ch = channels;
    if (inSamples.length != outSamples.length || inSamples.length % ch != 0) {
      throw ArgumentError(
        'Input and output buffer sizes must match and be a multiple of channel count.',
      );
    }

    final numFrames = inSamples.length ~/ ch;
    using((arena) {
      final inPtr = arena<Float>(inSamples.length);
      final outPtr = arena<Float>(outSamples.length);

      inPtr.asTypedList(inSamples.length).setAll(0, inSamples);
      _bindings.processInterleaved(_handle, inPtr, outPtr, numFrames);
      outSamples.setAll(0, outPtr.asTypedList(outSamples.length));
    });
  }

  /// Processes interleaved PCM audio frames in-place inside [samples].
  void processInplace(Float32List samples) {
    _checkDisposed();
    final ch = channels;
    if (samples.length % ch != 0) {
      throw ArgumentError(
        'Buffer size must be a multiple of channel count ($ch).',
      );
    }

    final numFrames = samples.length ~/ ch;
    using((arena) {
      final ptr = arena<Float>(samples.length);
      ptr.asTypedList(samples.length).setAll(0, samples);
      _bindings.processInplace(_handle, ptr, numFrames);
      samples.setAll(0, ptr.asTypedList(samples.length));
    });
  }

  // =========================================================================
  // Static Analysis & Diagnostic Functions
  // =========================================================================

  /// Returns the native engine version string.
  static String getVersion() {
    final ptr = _bindingsInstance.getVersion();
    return ptr.toDartString();
  }

  /// Computes the magnitude frequency spectrum using a Radix-2 Cooley-Tukey FFT.
  ///
  /// [pcmSamples] must have at least [fftSize] samples.
  /// [fftSize] must be a power of two (e.g. 512, 1024, 2048).
  /// Returns array of `fftSize / 2` magnitude values in dB.
  static Float32List computeFft(Float32List pcmSamples, {int fftSize = 1024}) {
    if (pcmSamples.length < fftSize) {
      throw ArgumentError(
        'Input PCM samples (${pcmSamples.length}) must be at least fftSize ($fftSize).',
      );
    }

    final outSize = fftSize ~/ 2;
    return using((arena) {
      final inPtr = arena<Float>(pcmSamples.length);
      final outPtr = arena<Float>(outSize);

      inPtr.asTypedList(pcmSamples.length).setAll(0, pcmSamples);
      final res = _bindingsInstance.computeFft(
        inPtr,
        pcmSamples.length,
        outPtr,
        fftSize,
      );
      if (res != 0) {
        throw StateError('FFT calculation failed with code: $res');
      }

      final result = Float32List(outSize);
      result.setAll(0, outPtr.asTypedList(outSize));
      return result;
    });
  }

  /// Groups FFT magnitudes into logarithmic frequency spectrum visualizer bands.
  static Float32List computeSpectrumBands(
    Float32List magnitudes, {
    required int sampleRate,
    int numBands = 16,
    double minFreq = 20.0,
    double maxFreq = 20000.0,
  }) {
    return using((arena) {
      final inPtr = arena<Float>(magnitudes.length);
      final outPtr = arena<Float>(numBands);

      inPtr.asTypedList(magnitudes.length).setAll(0, magnitudes);
      final res = _bindingsInstance.computeSpectrumBands(
        inPtr,
        magnitudes.length,
        sampleRate,
        outPtr,
        numBands,
        minFreq,
        maxFreq,
      );
      if (res != 0) {
        throw StateError('Spectrum band grouping failed with code: $res');
      }

      final result = Float32List(numBands);
      result.setAll(0, outPtr.asTypedList(numBands));
      return result;
    });
  }

  /// Extracts waveform visualization peaks and RMS energy.
  static WaveformData extractWaveform(
    Float32List pcmSamples, {
    int channels = 2,
    int numPeaks = 100,
  }) {
    return using((arena) {
      final inPtr = arena<Float>(pcmSamples.length);
      final minPtr = arena<Float>(numPeaks);
      final maxPtr = arena<Float>(numPeaks);
      final rmsPtr = arena<Float>(numPeaks);

      inPtr.asTypedList(pcmSamples.length).setAll(0, pcmSamples);
      final res = _bindingsInstance.extractWaveform(
        inPtr,
        pcmSamples.length,
        channels,
        minPtr,
        maxPtr,
        rmsPtr,
        numPeaks,
      );
      if (res != 0) {
        throw StateError('Waveform extraction failed with code: $res');
      }

      final minList = Float32List(numPeaks);
      final maxList = Float32List(numPeaks);
      final rmsList = Float32List(numPeaks);

      minList.setAll(0, minPtr.asTypedList(numPeaks));
      maxList.setAll(0, maxPtr.asTypedList(numPeaks));
      rmsList.setAll(0, rmsPtr.asTypedList(numPeaks));

      return WaveformData(min: minList, max: maxList, rms: rmsList);
    });
  }
}
