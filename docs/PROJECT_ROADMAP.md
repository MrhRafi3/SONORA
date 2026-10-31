# SONORA — Master Project Roadmap & Execution Status

> **Project:** SONORA — Premium High-Resolution Offline Audio Player
> **Repository:** `https://github.com/MrhRafi3/SONORA.git`
> **Local Path:** `/Users/rafi/Programing/sonora`
> **Target Platforms:** Android (API 34–36, `com.mrhrafi3.sonora`) & iOS (14.0+, `com.mrhrafi3.sonora`)
> **Current Phase:** UI/UX Refinement Complete (Phase 10 Postponed — Awaiting User Approval)
> **Last Verified Phase 09 Commit:** `931edfe868e616732670d58a4b07285b3a109437`

---

## 1. Master Phase Matrix

| Phase | Title | Status | Verification Summary | Latest Commit |
| :--- | :--- | :--- | :--- | :--- |
| **Phase 01** | Project Initialization & Clean Architecture | **COMPLETED** | Folder structure, core tokens, initial test scaffold | Initial milestones |
| **Phase 02** | Premium UI Design System & App Shell | **COMPLETED** | Audiophile dark theme, GoRouter, AppShell, NavigationRail | UI integration |
| **Phase 03** | Music Library, Metadata & Database | **COMPLETED** | Drift SQLite, MediaStore cursor, iOS FilePicker, ID3/FLAC metadata | Storage milestone |
| **Phase 04** | Real Audio Playback Engine | **COMPLETED** | `just_audio`, single player instance, AudioPlayerFacade | Playback core |
| **Phase 05** | Background Playback & System Media Controls | **COMPLETED** | `audio_service`, lock screen, notification shade, noisy disconnect | `30d7df91932e9072b9d579749e4e57e1b7807bfc` |
| **Phase 06** | C++ Audio Engine & Dart FFI | **COMPLETED** | Biquad filter bank, FFT analysis, waveform extractor, 16k page alignment | `a0fb5cb9e210cff419257b7498f926e64e75ebe6` |
| **Phase 07** | Premium Audio Experience (DSP, EQ, Waveforms) | **COMPLETED** | Reactive 10-band EQ, spectrum visualizer, waveform scrubber, lyrics | `b37bc9085efb816e70371afb1244facf7555a783` |
| **Phase 08** | Personalization & Smart Library | **COMPLETED** | Theme accents, smart playlists, reordering, audio format filter chips | `62f417f139b243f5939dad53eedd51694c018be2` |
| **Phase 09** | Performance Optimization & Comprehensive QA | **COMPLETED** | SQLite indexes, artwork caching & LRU pruning, 93 test suite, stress testing | `931edfe868e616732670d58a4b07285b3a109437` |
| **UI/UX Polish** | App-Wide Motion, Restructured Settings & Fixes | **COMPLETED** | AppMotion system, 6 subpages, developer credit, EQ overflow fix, 99 tests | `ac67205` |
| **Splash Screen** | Native & Animated Flutter Splash Screen | **COMPLETED** | Native launch splash handoff, #171717 contrast, scale & resonance pulse, 103 tests | In current commit |
| **Phase 10** | Production Release Preparation | **POSTPONED** | Release builds, store assets, metadata, final audit (awaiting Phase 10 approval) | Scheduled |

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

### Phase 07 — Premium Audio Experience (Completed)
- **Status**: Completed & Verified.
- **Deliverables**:
  - `EqualizerState` & `EqualizerNotifier`: Reactive Riverpod state management communicating directly with `SonoraAudioEngine` via Dart FFI.
  - Frequency Response Graph: Interactive `CustomPainter` plotting composite filter magnitude response in dB across the logarithmic audio spectrum (20 Hz - 20 kHz) with glowing gradient shading.
  - Multi-Band Equalizer: 5-band graphic mode and 10-band ISO standard mode (`31.25 Hz` to `16 kHz`) with fine vertical sliders, dB readout, and double-tap reset.
  - Preset Management: 10 built-in presets (Flat, Bass Boost, Vocal Clarity, Acoustic, Electronic, Rock, Classical, Jazz, Treble Air, Warm Tube) + custom user preset creation and saving.
  - Acoustic Dynamics: Master Preamp Gain (-12 dB to +12 dB), Sub-Bass Enhancement (0 dB to +10 dB), and soft-knee limiter dynamics toggle.
  - Real-Time Spectrum Visualizer: Animated 32-band logarithmic frequency spectrum analyzer widget with natural harmonic physics and peak-hold decay.
  - Waveform Scrubber: Audiophile interactive waveform progress scrubber on `PlayerScreen` with touch drag seek and glowing playhead marker.
  - Synchronized Lyrics & Master Notes: Multi-tab bottom sheet parsing synchronized LRC lyrics with auto-highlighting, seek-on-tap, and uncompressed analog master tape provenance notes.
  - Technical Audio Inspector: Modal inspecting codec container, sample rate, bit-depth, channel configuration, and C++ DSP engine buffer latency.
- **Verification Evidence**:
  - 57 automated unit, widget, and integration tests passed cleanly (100% pass rate).
  - `dart format` clean (0 changed).
  - `flutter analyze --no-pub` clean (0 issues in root and package).
  - Android debug APK built and verified in 22.6s.
  - iOS simulator app built and verified in 20.8s.

### Phase 08 — Personalization & Smart Library (Completed)
- **Status**: Completed & Verified.
- **Deliverables**:
  - Theme Accent Engine: 5 audiophile palette presets (`Amber Warmth`, `Rose Copper`, `Champagne Gold`, `Emerald Velvet`, `Sapphire Tube`) managed via `themeAccentProvider` with dynamic dark and light theme builders.
  - Interactive Theme Customization: Integrated palette selector in `SettingsScreen` with live visual indicators and persistent selection.
  - Smart Playlists: Dynamic virtual collections calculated on-device:
    - *Favorites*: Quick access to starred audiophile tracks.
    - *Hi-Res Studio Masters*: Lossless/Hi-Res tracks (>= 88.2 kHz, >= 24-bit, FLAC, WAV).
    - *Recently Added*: Real-time chronological arrival stream from local storage.
    - *Lossless Vault*: Pure bit-perfect uncompressed formats.
  - Custom Playlist Management: Full CRUD operations backed by Drift SQLite (`createPlaylist`, `renamePlaylist`, `deletePlaylist`, `addTrackToPlaylist`, `removeTrackFromPlaylist`).
  - Playlist Reordering: Smooth drag-and-drop playlist reordering via `ReorderableListView` updating SQLite sequence orders in atomic transactions.
  - Dedicated Playlist Detail Screen: Rich playlist header with duration calculation, 'Play All', 'Shuffle', track picker modal, and reorderable track list.
  - Audio Format Filtering: Tab-level chip filters (`All`, `Hi-Res`, `Lossless`, `Standard`) on Songs tab allowing instant audiophile collection segmentation.
  - Home Screen Personalization: Time-of-day contextual greeting ('Morning Listening', 'Afternoon Fidelity', 'Evening Session', 'Late Night Vinyl'), dynamic recently added carousel, and quick-launch Smart Collection cards.
- **Verification Evidence**:
  - 71 automated unit, widget, and integration tests passed cleanly (100% pass rate).
  - 14 comprehensive tests in `test/personalization_and_smart_library_test.dart`.
  - `dart format` clean (0 changed).
  - `flutter analyze --no-pub` clean (0 issues in root and native packages).
  - Android debug APK built in 14.5s (`app-debug.apk`).
  - iOS simulator app built in 19.9s (`Runner.app`).

---

## 3. Remaining Roadmap & Objectives

### Phase 09 — Performance Optimization & Comprehensive QA (Completed)
- **Status**: Completed & Verified.
- **Deliverables**:
  - **Database Query & Index Optimization**:
    - Created targeted SQLite indexes: `idx_tracks_date_added` on `tracks(date_added)`, `idx_tracks_duration` on `tracks(duration_ms)`, and `idx_playlist_tracks_order` on `playlist_tracks(playlist_id, sort_order)`.
    - Drift code generator updated and verified.
    - Large library benchmark verified with 5,000 tracks batch inserted into SQLite in memory:
      - All-tracks fetch: < 250ms.
      - Indexed title/artist/dateAdded/duration sorting: < 150ms.
      - Full-text search across 5,000 items: < 100ms.
      - Favorites and Recently Added limit queries: < 80ms.
      - 200-track playlist reordering in atomic transaction: < 120ms.
  - **Artwork Caching, Downsampling & Memory Pooling**:
    - `ArtworkCacheService`: Implemented fast in-memory LRU cache (`_memoryPathCache`, capacity 500) to bypass synchronous filesystem `stat` calls during fast fling scrolling.
    - Bounded disk footprint (`defaultMaxDiskBytes = 150 MB`), disk usage monitoring (`getDiskUsage()`), and deterministic LRU timestamp-based file eviction (`pruneDiskCache()`).
    - Downscaled raster decodes in `SonoraArtwork`: Clamped `cacheWidth` and `cacheHeight` to `[64, 1024]` based on 2x retina display density metrics with `gaplessPlayback: true` to prevent image raster memory spikes and UI thread jank.
  - **Rapid Playback Engine Stress Testing**:
    - Concurrently spammed 100+ rapid interleaved commands (`playTrack`, `togglePlayPause`, `seek`, `nextTrack`, `previousTrack`, `toggleShuffle`, `toggleRepeat`, `playQueueIndex`) on `PlayerNotifier` and `FakeAudioPlayerFacade`.
    - Zero uncaught exceptions, zero race crashes, and deterministic state consistency.
  - **Audio Session & Background Resilience**:
    - Tested `SonoraAudioHandler` against edge track metadata (320+ character titles, multi-byte Japanese/Arabic/Cyrillic scripts, musical emojis).
    - Verified graceful behavior with unassigned remote callbacks, zero-duration tracks, and corrupted artwork file paths falling back to procedural vinyl graphics.
  - **C++ Native Audio Engine FFI Stress & Leak Testing**:
    - Executed 25 rapid allocate-and-dispose cycles of `SonoraAudioEngine` without leaks.
    - Processed 100 consecutive 1024-frame stereo buffers while aggressively mutating EQ band gains (-12 dB to +12 dB) and preamp gains (-5 dB to +5 dB).
    - Verified all output samples remain finite numbers (no NaN, Inf, or denormals).
    - Computed 50 consecutive FFT spectrum transforms and waveform extractions under continuous load.
- **Verification Evidence**:
  - 93 automated tests passed cleanly (87 in root app, 6 in C++ package, 100% pass rate).
  - 16 new comprehensive tests in `test/performance_and_stress_test.dart`.
  - `dart format` clean (0 changed).
  - `flutter analyze --no-pub` clean (0 issues in root and native packages).
  - Android debug APK built in 13.2s (`app-debug.apk`).
  - iOS simulator app built in 46.1s (`Runner.app`).

### UI/UX Refinement & Polish Phase (Completed)
- **Status**: Completed & Verified.
- **Deliverables**:
  - **App-Wide Seamless Transitions & Motion System**:
    - Created `AppMotion` design token suite (`lib/app/theme/app_motion.dart`) defining standard motion durations (`short150`, `medium250`, `medium300`, `long400`), easing curves (`Curves.easeOutCubic`, `Curves.fastOutSlowIn`), and reduced-motion accessibility overrides (`MediaQuery.disableAnimations`).
    - Standardized GoRouter transition builders with shared-axis slide transitions for horizontal navigation, modal bottom-sheet slide-up for full-screen players and equalizers, and fade-through for nested settings destinations.
    - Added subtle animated scale and color feedback on interactive cards, buttons, sliders, and toggles.
  - **Settings Page UI/UX Restructuring**:
    - Restructured root `SettingsScreen` from a long cluttered list into 7 clean, consolidated category cards with animated press feedback, gold accent icons, informative summaries, and chevron navigation.
    - Preserved instant access to Theme Mode and Audiophile Accent Palette directly on the root screen.
    - Implemented 6 dedicated, modular subpages under `lib/features/settings/presentation/subpages/`:
      - `PlaybackSettingsScreen`: High-Res Direct DAC, bit-perfect streaming, ReplayGain normalization, gapless playback, crossfade slider (0–12s), pause on disconnect.
      - `AppearanceSettingsScreen`: Theme mode selector, accent palette picker, reduce motion toggle.
      - `LibraryStorageSettingsScreen`: Auto-rescan library on launch, disk cache usage monitor, clear artwork cache action.
      - `NotificationsSettingsScreen`: System notification media controls toggle, lock screen full artwork toggle.
      - `PrivacySettingsScreen`: Local telemetry/diagnostics toggle, read-only storage permissions status.
      - `AboutSettingsScreen`: App version, build number, core architecture specifications, audiophile audio engine specs, and dedicated developer credit.
    - Introduced Riverpod `SettingsNotifier` (`settings_providers.dart`) managing persistent audio and UX preferences.
  - **Developer & Architect Credit**:
    - Designed an elegant, high-fidelity developer credit on `AboutSettingsScreen` highlighting **Mrh Rafi** as `DEVELOPER & ARCHITECT` ("Audio Engineering, DSP & Flutter Architecture") adhering strictly to the warm charcoal and champagne aesthetic.
    - Surfaced a gold badge on the root Settings card to acknowledge the creator without intrusiveness.
  - **Equalizer Responsive Pixel Overflow Resolution**:
    - Addressed RenderFlex overflow errors on compact viewports (`320x480`, `360x640`, `412x915`).
    - Replaced rigid rows with responsive `Wrap` layouts in Equalizer header, Band Architecture toggle, Acoustic Dynamics section, and Live Spectrum card.
    - Added `LayoutBuilder` wrapper with horizontal `SingleChildScrollView` for the 10-band slider deck when viewport width is below comfortable touch target dimensions, ensuring sliders remain fully usable without clipping.
    - Added comprehensive multi-resolution widget tests verifying 0 overflows across all device dimensions.
- **Verification Evidence**:
  - 99 automated unit, widget, and integration tests passed cleanly (93 root app, 6 C++ package, 100% pass rate).
  - `dart format` clean (0 files changed).
  - `flutter analyze --no-pub` clean (0 warnings or errors across root and native engine).
  - Android debug APK built in 14.4s (`build/app/outputs/flutter-apk/app-debug.apk`).
  - iOS simulator app built in 18.6s (`build/ios/iphonesimulator/Runner.app`).

### Premium Animated Splash Screen Phase (Completed)
- **Status**: Completed & Verified.
- **Deliverables**:
  - **Asset Integration & Verification**:
    - Verified and registered `assets/branding/` in `pubspec.yaml`.
    - Integrated supplied `sonora_logo.png` (1024x1024, acoustic wave geometry) without modifications, distortions, or text overlays.
  - **Native Launch Splash (Android & iOS)**:
    - Generated unified solid `#171717` launch background matching the exact RGB values (23, 23, 23) of the logo background using `flutter_native_splash`.
    - Configured Android `launch_background.xml`, `styles.xml`, and Android 12+ `values-v31/styles.xml` (`windowSplashScreenBackground: #171717`, dark base theme).
    - Configured iOS `LaunchScreen.storyboard` and `LaunchBackground.imageset` with matching solid `#171717`.
    - Completely eliminated launch flashes (white/black glitches) and layout jumps.
  - **Flutter Animated Splash Screen ([`SplashScreen`](file:///Users/rafi/Programing/sonora/lib/features/splash/presentation/splash_screen.dart))**:
    - Clean solid-color `#171717` canvas providing seamless continuity from native launch.
    - Synchronized handoff: `FlutterNativeSplash.preserve` during `main()` async initialization, cleanly dismissed via `FlutterNativeSplash.remove()` on the first drawn Flutter frame.
    - Animation Sequence (1700ms total):
      1. Clean solid-color background start.
      2. Logo entrance (0–600ms): Subtle scale (0.85 -> 1.0) and opacity (0.0 -> 1.0) with `Curves.easeOutCubic`.
      3. Acoustic resonance pulse (600–1350ms): Organic breathing pulse (1.0 -> 1.045 -> 1.0) echoing the waveform radiating arcs.
      4. Settling (1350–1700ms): Natural rest at 1.0 scale and opacity.
      5. Fluid fade transition directly into HomeScreen (`context.go('/')`).
    - Guarded navigation preventing back-navigation to splash; `PopScope(canPop: false)`.
    - Responsive sizing (`math.min(w, h) * 0.42` clamped to `[140, 220]`) tested across compact phones (320x480, 360x640), tall flagships (412x915), and tablets (800x1200).
    - Full accessibility support: detects `MediaQuery.disableAnimations` and gracefully short-circuits after minimal pause.
- **Verification Evidence**:
  - 103 automated tests passed cleanly (97 root app, 6 C++ package, 100% pass rate).
  - 4 comprehensive new tests in `test/splash_screen_test.dart`.
  - `dart format` clean (0 files changed).
  - `flutter analyze --no-pub` clean (0 issues across root and native engine).
  - Android debug APK built in 22.6s (`build/app/outputs/flutter-apk/app-debug.apk`).
  - iOS simulator app built in 49.9s (`build/ios/iphonesimulator/Runner.app`).

---

## 3. Remaining Roadmap & Objectives

### Phase 10 — Production Release Preparation (Next Priority — Awaiting User Approval)
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
