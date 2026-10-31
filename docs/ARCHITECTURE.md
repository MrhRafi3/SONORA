# SONORA — Technical Architecture Specification

> **Repository:** `https://github.com/MrhRafi3/SONORA.git`
> **Status:** Implemented through Phase 05 (Phase 06 Native Audio Engine in Planning)
> **Target Framework:** Flutter 3.44.5 / Dart 3.12.2
> **Target Platforms:** Android (API 34–36, `com.mrhrafi3.sonora`) & iOS (iOS 14.0+, `com.mrhrafi3.sonora`)

---

## 1. System Overview & Clean Architecture

SONORA employs **Feature-based Clean Architecture**, separating domain logic, data persistence, platform channels, and Flutter presentation:

```
lib/
├── app/                  # Application bootstrap, routing, and design system tokens
│   ├── router/           # GoRouter route declarations and navigation shell
│   └── theme/            # SonoraTheme (colors, typography, component themes)
├── core/                 # Shared foundations and cross-cutting infrastructure
│   ├── constants/        # System keys, notification channels, storage paths
│   ├── database/         # Drift SQLite database schema, tables, DAOs
│   ├── errors/           # Failure models and exception definitions
│   └── utils/            # Time formatting, file utilities, byte conversions
├── features/             # Domain-driven feature slices
│   ├── library/          # MediaStore/iOS file scanning, track repository, database sync
│   │   ├── data/         # LibraryRepositoryImpl, metadata extraction, picture caching
│   │   ├── domain/       # AudioTrack entity, Album, Artist, LibraryRepository interface
│   │   └── presentation/ # LibraryScreen, AlbumGrid, TrackTile, search/filter notifiers
│   ├── player/           # Playback engine, audio session, background media controls
│   │   ├── data/         # SonoraAudioHandler, JustAudioPlayerFacade, FakeAudioPlayerFacade
│   │   ├── domain/       # AudioPlayerFacade interface, UiTrack, PlaybackMode
│   │   └── presentation/ # PlayerScreen, MiniPlayer, PlayerNotifier, scrub bar
│   └── settings/         # User configuration, theme modes, storage management
└── shared/               # Reusable atomic widgets, design elements, extensions
```

---

## 2. Playback Subsystem Architecture

### The Single AudioPlayer Invariant
To prevent resource contention, audio device lockouts, and duplicate playback streams:
- Exactly **ONE** production `just_audio.AudioPlayer` instance exists in the running application.
- This instance is encapsulated entirely inside `SonoraAudioHandler`.
- UI widgets and view-models interact solely via the domain interface [`AudioPlayerFacade`](../lib/features/player/domain/audio_player_facade.dart), implemented by `JustAudioPlayerFacade`.
- Automated tests utilize [`FakeAudioPlayerFacade`](../lib/features/player/data/fake_audio_player_facade.dart) for fast, deterministic unit and widget verification without platform channels.

### Background Audio & System Integration
- **`audio_service`**: Runs the background audio lifecycle.
- **Android MediaSession**: Exposes `MediaSessionCompat` with playback state, lock screen controls, and notification shade actions.
- **iOS MPRemoteCommandCenter**: Connects play, pause, seek, and skip commands to `MPNowPlayingInfoCenter`.
- **`audio_session`**: Configures the platform audio focus for music playback. Automatically pauses on headphone disconnect / Bluetooth loss (`becomingNoisyEventStream`) and handles phone call interruptions safely.

---

## 3. Data & Storage Subsystem

### Local Database (Drift / SQLite)
- **Tables**:
  - `Tracks`: id, title, artist, album, duration, filePath, sourceUri, audioFormat, sampleRate, bitDepth, dateAdded, isFavorite.
  - `Playlists`: id, name, createdAt, updatedAt.
  - `PlaylistTracks`: playlistId, trackId, sortOrder (Foreign keys with cascade deletion).
- **Reactive Queries**: Exposes Drift `Selectable.watch()` streams mapped into Riverpod providers for automatic UI updates when tracks or playlists mutate.

### Audio Discovery
- **Android**: Queries Android `MediaStore.Audio.Media.EXTERNAL_CONTENT_URI` via Kotlin platform channel, extracting media items compatible with Android 13+ granular permissions (`READ_MEDIA_AUDIO`).
- **iOS**: Uses `UIDocumentPickerViewController` via `file_picker`, copying selected audio files into the sandboxed `sonora_imported_music/` documents directory for permanent access.

---

## 4. Native C++ Audio Subsystem (`packages/sonora_audio_engine`)

A dedicated sub-package at `packages/sonora_audio_engine` is structured to provide high-performance native audio processing.

### Implemented Native C++ Architecture
```
packages/sonora_audio_engine/
├── CMakeLists.txt              # Cross-platform CMake root script (C++17)
├── android/
│   └── build.gradle            # Gradle FFI plugin configuration (AGP 8.7 / NDK 28)
├── ios/
│   ├── Classes/
│   │   ├── sonora_audio_engine.h # Self-contained C header
│   │   └── sonora_audio_engine.cpp # CocoaPods unity compilation unit
│   └── sonora_audio_engine.podspec # CocoaPods iOS build specification (C++17)
├── macos/
│   ├── Classes/
│   │   ├── sonora_audio_engine.h
│   │   └── sonora_audio_engine.cpp
│   └── sonora_audio_engine.podspec # CocoaPods macOS build specification (C++17)
├── include/
│   └── sonora_audio_engine.h   # Pure C ABI header (extern "C") with opaque handles
├── src/
│   ├── CMakeLists.txt          # Shared library target (16k page alignment)
│   ├── engine.cpp              # Engine lifecycle, parameter getters/setters, buffer processing
│   ├── dsp/
│   │   ├── biquad_filter.h/cpp # Direct Form II Transposed IIR filter with de-zippering
│   │   ├── equalizer.h/cpp     # Cascaded 5-band and 10-band ISO standard filter bank
│   │   └── preamp.h/cpp        # Preamp gain interpolation and soft-knee limiter
│   └── analysis/
│       ├── fft.h/cpp           # Radix-2 Cooley-Tukey DIT FFT + Hann window
│       └── waveform.h/cpp      # Min/max/RMS waveform chunk extraction
├── test/
│   └── native_dsp_test.cpp     # Standalone C++ unit test suite & latency benchmark
└── lib/
    ├── sonora_audio_engine.dart # High-level Dart API with Finalizer & safe typed arrays
    └── src/
        └── ffi_bindings.dart   # dart:ffi C function pointers and bindings
```

### Critical Playback & DSP Integration Architecture

#### The Architectural Challenge
Dart FFI allows Dart to call C++ functions in microseconds, but Dart FFI alone **does not place C++ in the audio playback path**. During normal `just_audio` playback, ExoPlayer (Android) and AVPlayer (iOS) stream directly to hardware output without passing audio through Dart.

#### The Verified Integration Strategy
1. **Audio Analysis & Visualization (Waveforms & Spectrum)**:
   - For file waveforms and audio analysis, Dart/native background worker feeds audio PCM chunks into `sonora_audio_engine`.
   - C++ computes FFT spectrum bands and waveform peak vectors with sub-millisecond execution.
   - Analysis data returns via FFI to Riverpod providers for 60/120fps UI rendering.
2. **Real-Time Playback DSP (Equalizer, Bass Boost, Preamp)**:
   - **Android**: Utilize the platform audio effects pipeline connected to ExoPlayer's `audioSessionId` (`android.media.audiofx.Equalizer`, `android.media.audiofx.LoudnessEnhancer`, `android.media.audiofx.BassBoost`), integrated through `just_audio`'s native `AudioPipeline`. For custom C++ algorithms, an ExoPlayer `AudioProcessor` intercepts PCM buffers before `AudioTrack`.
   - **iOS**: Attach an `MTAudioProcessingTap` or native audio tap to the player item's audio track, routing PCM sample buffers through the C++ DSP engine before output to CoreAudio.
   - **Safety Invariant**: Under no circumstances will core playback or decoding be rewritten from scratch in C++. `just_audio` remains the core playback controller.

---

## 5. Quality Invariants & Verification Standards

1. **Zero Static Analysis Warnings**: `flutter analyze --no-pub` must exit with code 0 and zero issues across all code.
2. **Automated Test Coverage**: All unit, widget, and native tests must pass cleanly. No test is ever skipped or faked.
3. **Evidence Before Assertions**: Every build, test, and verification result must be supported by recorded terminal evidence.
4. **Physical Device QA Boundary**: Emulator/simulator results must never be claimed as physical hardware tests.
