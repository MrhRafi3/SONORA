# Sonora Audio Engine (`sonora_audio_engine`)

## Overview

`sonora_audio_engine` is a dedicated sub-package reserved for high-performance native audio processing in **SONORA**. It bridges Flutter/Dart with a custom C++ engine via Dart FFI (`dart:ffi`).

## Architectural Objectives

- **Ultra-low Latency DSP**: Native digital signal processing routines for dynamic parametric equalization, crossfading, replay gain, and audio filtering.
- **Spectrum Analysis / FFT**: Real-time frequency spectrum analysis and audio visualization calculated off the main thread.
- **Isolation & Safety**: Compute-intensive audio processing is isolated from the Flutter UI isolate using background worker isolates and native C++ worker threads.
- **Zero UI-Thread Jitter**: Under no circumstances should audio decoding, signal filtering, or buffer transforms block Flutter's 60/120fps frame rendering pipeline.

## Native Boundary Guidelines

1. **Profiling First**: Only move audio algorithms from Dart to C++ when CPU/memory profiling demonstrates a concrete performance bottleneck.
2. **C++ Standard**: C++20 standard, compiled for Android (NDK `arm64-v8a`, `armeabi-v7a`, `x86_64`) and iOS (`arm64`, `x86_64` simulator).
3. **Dart FFI Bindings**: Generated cleanly using `ffigen` or idiomatic manual binding wrappers with strict memory management (no leaks).

## Roadmap

- **Phase 01**: Architectural foundation and directory scaffold (Current).
- **Phase 02+**: Playback abstraction with `just_audio` / `audio_service`.
- **Future Phase**: Custom C++ DSP filter graphs, parametric EQ, and real-time visualization buffers.

