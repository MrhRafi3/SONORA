# SONORA

**SONORA** is a premium, offline-first high-resolution audio player built with Flutter, designed with audiophile-grade aesthetic refinement and a Feature-based Clean Architecture.

---

## Architecture & Technology Stack

- **Framework**: Flutter 3.44.5 / Dart 3.12.2
- **State Management**: Riverpod (Notifiers, StreamProviders, AsyncValue)
- **Navigation**: GoRouter
- **Audio Playback Engine**: Clean Architecture facade (`AudioPlayerFacade`) backed by `just_audio` in production and `FakeAudioPlayerFacade` for pure-Dart in-memory testing without platform channel dependencies.
- **Queue & Playback Management**:
  - Full queue indexing, dynamic track insertion, removal, and direct-index playback.
  - Smart Previous: restarts track at `0:00` if position > 3 seconds; navigates to previous queue item otherwise.
  - Non-destructive Shuffle: keeps active track at head, shuffles remaining items, and preserves the pristine `originalQueue` order for seamless un-shuffling.
  - Repeat Modes: `off` (stops and halts at queue end), `all` (loops queue continuously), and `one` (restarts current track from `0:00` on completion).
  - Auto-advance: reactive completion stream advances queue according to repeat settings.
- **Local Database**: Drift (SQLite) with indexed tables (`Tracks`, `Playlists`, `PlaylistTracks`), reactive queries, and foreign key cascade deletion.
- **Audio Discovery**:
  - **Android**: `MediaStore` query cursor via Kotlin platform channel (`READ_MEDIA_AUDIO` on Android 13+, scoped storage compatible).
  - **iOS**: `UIDocumentPickerViewController` via `file_picker`, copying selected audio files into the sandboxed application documents directory (`sonora_imported_music/`) for persistent cross-launch access.
- **Artwork Caching**: Embedded picture extraction with persistent SHA-1 disk caching.
- **Native Audio Engine (`packages/sonora_audio_engine`)**: Reserved architecture for C++ DSP routines, parametric equalization, and real-time audio analysis via Dart FFI.

---

## Technical Specifications & Known Limitations

The following technical characteristics and known limitations have been verified:

1. **Phase 04 Playback Scope**:
   - The playback engine handles foreground audio loading, state synchronization, queue management, seeking, repeat, and shuffle.
   - Background audio playback, lock screen controls, and platform media notification controls are intentionally reserved for Phase 05.
   - Custom C++ DSP filter graphs and Dart FFI processing are reserved for Phase 06.
2. **Bit-Depth Information**:
   - The pure-Dart `audio_metadata_reader` package does not expose universal bit-depth (`bitsPerSample`) information on its generic `AudioMetadata` container across all formats. As a result, `AudioTrack.bitDepth` is stored as `null` in the local SQLite database. The UI format badge displays the sample rate or bitrate instead (e.g. `FLAC • 96 kHz` or `MP3 • 320 kbps`).
3. **Raw ADTS AAC Metadata**:
   - Containerized AAC audio (such as `.m4a` and `.mp4`) parses fully. Raw uncontainerized ADTS audio streams (`.aac`) that lack container atoms may fall back to filename-based title and artist metadata with zero duration.
4. **Hardware Environment Testing**:
   - Automated testing and verification have been executed in virtual simulator and emulator build environments (`build apk --debug`, `build ios --simulator`). Actual physical-device field testing across specific vendor hardware and legacy OS revisions has not yet been performed.

---

## Getting Started

### Prerequisites

- Flutter SDK 3.44.5 or higher
- Android SDK (API 34–36, Gradle 9.1+)
- Xcode 15+ (iOS 14.0 deployment target)

### Verification Commands

```bash
# Code formatting check
dart format --output=none --set-exit-if-changed .

# Static analysis
flutter analyze

# Automated test suite
flutter test

# Android debug build
flutter build apk --debug

# iOS simulator build
flutter build ios --simulator --no-codesign
```
