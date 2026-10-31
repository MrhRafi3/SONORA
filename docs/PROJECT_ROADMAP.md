# SONORA — Master Project Roadmap & Execution Status

> **Project:** SONORA — Premium High-Resolution Offline Audio Player
> **Repository:** `https://github.com/MrhRafi3/SONORA.git`
> **Local Path:** `/Users/rafi/Programing/sonora`
> **Target Platforms:** Android (API 34–36, `com.mrhrafi3.sonora`) & iOS (14.0+, `com.mrhrafi3.sonora`)
> **Current Phase:** Phase 06 (Planning Stage — Awaiting Approval)
> **Last Verified Phase 05 Commit:** `30d7df91932e9072b9d579749e4e57e1b7807bfc`

---

## 1. Master Phase Matrix

| Phase | Title | Status | Verification Summary | Latest Commit |
| :--- | :--- | :--- | :--- | :--- |
| **Phase 01** | Project Initialization & Clean Architecture | **COMPLETED** | Folder structure, core tokens, initial test scaffold | Initial milestones |
| **Phase 02** | Premium UI Design System & App Shell | **COMPLETED** | Audiophile dark theme, GoRouter, AppShell, NavigationRail | UI integration |
| **Phase 03** | Music Library, Metadata & Database | **COMPLETED** | Drift SQLite, MediaStore cursor, iOS FilePicker, ID3/FLAC metadata | Storage milestone |
| **Phase 04** | Real Audio Playback Engine | **COMPLETED** | `just_audio`, single player instance, AudioPlayerFacade | Playback core |
| **Phase 05** | Background Playback & System Media Controls | **COMPLETED** | `audio_service`, lock screen, notification shade, noisy disconnect | `30d7df91932e9072b9d579749e4e57e1b7807bfc` |
| **Phase 06** | C++ Audio Engine & Dart FFI | **PLANNING** | Scope defined, architecture researched, awaiting approval | Pending |
| **Phase 07** | Premium Audio Experience (DSP, EQ, Waveforms) | **PLANNED** | Dependent on Phase 06 engine & FFI bridge | Scheduled |
| **Phase 08** | Personalization & Smart Library | **PLANNED** | Favorites, recently played, theme customization | Scheduled |
| **Phase 09** | Performance Optimization & Comprehensive QA | **PLANNED** | Memory profiling, stress testing, large library benchmarks | Scheduled |
| **Phase 10** | Production Release Preparation | **PLANNED** | Release builds, store assets, metadata, final audit | Scheduled |

---

## 2. Completed Phase Details

### Phase 01 to Phase 04 Summary
- **Architecture**: Established Feature-based Clean Architecture (`lib/app`, `lib/core`, `lib/features`, `lib/shared`).
- **UI & Navigation**: Audiophile dark theme (`#121214`), champagne/amber accents (`#D4AF37`), responsive `AppShell` with bottom navigation and tablet navigation rail.
- **Database & Discovery**: Indexed SQLite schema with Drift (`Tracks`, `Playlists`, `PlaylistTracks`). Android `MediaStore` integration via Kotlin cursor queries; iOS sandboxed audio import via `file_picker`.
- **Playback Core**: Single production `just_audio.AudioPlayer` behind `AudioPlayerFacade` and deterministic in-memory `FakeAudioPlayerFacade`.

### Phase 05: Background Playback & System Media Controls
- **Status**: IMPLEMENTED & AUDITED.
- **Key Deliverables**:
  - `SonoraAudioHandler`: Integrated `audio_service` with `just_audio`.
  - Android `MediaSessionCompat`: Compact notification controls (play/pause, seek, skip) with `POST_NOTIFICATIONS` support.
  - iOS `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` integration with `UIBackgroundModes: [audio]`.
  - `audio_session`: Configured for music playback, handling headphone unplugs (`becomingNoisyEventStream`) and phone call interruptions safely.
  - Smart queue indexing, non-destructive shuffle, and repeat modes (`off`, `all`, `one`).
- **Verification Evidence**:
  - 47 automated unit and widget tests passed cleanly.
  - `flutter analyze --no-pub` reported zero errors or warnings.
  - Android debug APK build verified.
  - iOS simulator build verified.
  - Clean working tree on `main` synchronized with `origin/main`.

### Phase 06 — C++ Audio Engine & Dart FFI (Completed)
- **Status**: Completed & Verified.
- **Deliverables**:
  - `packages/sonora_audio_engine`: FFI plugin for Android, iOS, and macOS.
  - Native C++17 DSP Core: Direct Form II Transposed Biquad IIR filter bank with Robert Bristow-Johnson Audio EQ Cookbook algorithms, parameter de-zippering / smoothing, and anti-denormal flush-to-zero.
  - Preamp & Soft-Knee Limiter: Preamp boost/cut (-24 dB to +24 dB) with smooth linear interpolation and tanh soft-knee saturation curve preventing digital clipping.
  - Frequency Analysis: Radix-2 Cooley-Tukey DIT FFT with Hann windowing and logarithmic frequency spectrum visualizer band grouping.
  - Waveform Extraction: High-throughput min/max/RMS waveform chunk extraction.
  - C ABI & Dart FFI: Opaque handles, mutex thread-safety, safe Dart typed-data wrapper, and automatic lifecycle management via `Finalizer`.
  - Build Pipeline: Android CMake + NDK 28 with 16k page-size support (`libsonora_audio_engine.so` bundled for `arm64-v8a`, `armeabi-v7a`, `x86_64`), iOS/macOS CocoaPods podspecs.
- **Verification Evidence**:
  - Native C++ DSP suite: 6/6 tests passed + benchmark demonstrated 0.0314 ms per 1024-frame stereo buffer (679.7x faster than real-time).
  - Package Dart tests: 6/6 passed.
  - Root integration tests: 3/3 passed (Total app suite: 50/50 tests passed).
  - `dart format` clean (0 changed).
  - `flutter analyze --no-pub` clean (0 issues in root and package).
  - Android APK: `app-debug.apk` built and verified containing native `.so` binaries.
  - iOS Simulator: `Runner.app` built and verified via CocoaPods / Xcode.

---

## 3. Remaining Roadmap & Objectives

### Phase 07 — Premium Audio Experience (Next Priority — Awaiting User Approval)
- **Objective**: Connect verified DSP capabilities to production UI.
- **Scope**: Graphic equalizer (5-band / 10-band) and parametric EQ controls, custom presets, preamp/gain control, bass enhancement, real-time waveform visualization, frequency spectrum analysis, lyrics rendering, and audio format/bitrate indicators.

### Phase 08 — Personalization & Smart Library
- **Objective**: Local intelligence and personalization.
- **Scope**: Theme accents, personalized home screen, recently played, most played, smart playlists, custom playlists, sorting/filtering, and persistent user preferences.

### Phase 09 — Performance Optimization & Comprehensive QA
- **Objective**: Hardening, profiling, and stress testing.
- **Scope**: Large library benchmarking (10,000+ tracks), SQLite query optimization, artwork disk cache eviction, memory leak detection, battery efficiency, background playback stability, and rapid playback control stress tests.

### Phase 10 — Production Release Preparation
- **Objective**: Android and iOS store-ready packaging.
- **Scope**: Release signing, proguard/R8 rules, splash screens, adaptive icons, privacy policy documentation, version tagging (`v1.0.0`), and store listing preparation.

---

## 4. Known Limitations & Outstanding Hardware QA

1. **Physical Device Validation**: All verification to date has run in Android emulator and iOS simulator environments. Physical Android and iOS device field testing is tracked as mandatory pre-release QA.
2. **Metadata Bit-Depth**: Pure-Dart `audio_metadata_reader` does not universally extract `bitsPerSample`. Bit-depth is stored as null in SQLite; UI displays sample rate / bitrate.
3. **Containerless ADTS AAC**: Uncontainerized `.aac` files fall back to filename-based title/artist metadata.
4. **Android 13+ Notification Permission**: If the user denies `POST_NOTIFICATIONS`, background audio continues via the foreground service, but the notification card is hidden by Android OS.

---

## 5. Architectural Decision Records (ADR) Log

- **ADR-001**: Keep single production `AudioPlayer` instance in `SonoraAudioHandler`.
- **ADR-002**: Do not replace `just_audio` with a custom C++ playback engine. Core playback remains with established Flutter/native libraries.
- **ADR-003**: C++ is strictly reserved for justified custom audio DSP, advanced EQ, waveform/audio analysis, and performance-critical operations via Dart FFI.
- **ADR-004**: Audio file scanning and heavy DSP must never run on the Flutter UI thread.
