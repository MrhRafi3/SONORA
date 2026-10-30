# AGENTS.md — SONORA Project Guidelines

Permanent instructions and architectural rules for all AI agents and engineers working on the **SONORA** codebase.

---

## 1. Core Principles & Philosophy

SONORA is a premium, high-resolution, offline-first MP3 and audio player crafted for audiophiles. Quality, performance, and audio fidelity are paramount.

Every contributor must adhere to the following mandatory standards:

1. **Inspect before editing**: Always explore and understand existing files, patterns, and contracts before modifying or writing code. Never make blind assumptions.
2. **Preserve unrelated code and approved UI**: Never overwrite, delete, or break existing working features or polished UI unless explicitly instructed to refactor them.
3. **Never silently remove existing functionality**: If code needs deprecation, make it explicit, documented, and approved.
4. **Follow existing architecture**: Strictly respect the Feature-based Clean Architecture conventions laid out in the project.
5. **Report all failed tests and unresolved issues honestly**: Never conceal errors, broken builds, or skipped edge cases. Evidence before claims, always.

---

## 2. Architectural Guidelines

SONORA uses **Feature-based Clean Architecture**:

```text
lib/
├── app/               # Root app configuration, router, and design tokens/theme
├── core/              # Shared constants, errors, database infrastructure, core utilities
├── features/          # Domain-driven feature slices
│   ├── <feature>/
│   │   ├── data/          # Models, data sources (SQLite/Drift, disk, platform channels)
│   │   ├── domain/        # Entities, failure types, repository interfaces, use cases
│   │   └── presentation/  # Widgets, Riverpod notifiers, screens, view models
└── shared/            # Cross-cutting widgets, utility extensions, shared providers
```

### Architectural Invariants:
- **Separation of Concerns**: Keep business and audio logic strictly outside Flutter widgets. Widgets should only observe state and dispatch user intents.
- **Data Flow**: Unidirectional. UI -> Notifier/UseCase -> Repository -> Data Source -> Device/Storage.
- **No Mock Song Hacks**: Do **NOT** use hardcoded sample songs or dummy metadata lists as real music library data. SONORA reads from real device storage and the local SQLite index.
- **Production-Quality Code**: Avoid fake functionality, no-op placeholder buttons, or deceptive UI elements. If a feature is in development, display honest disabled or progress states.

---

## 3. State Management & Reactivity (Riverpod)

- **Use Riverpod consistently**: Use `Notifier` / `AsyncNotifier` (or code-generation equivalents when configured) for state management.
- **Avoid unnecessary rebuilds**: Use `ref.watch(provider.select((state) => state.specificField))` to scope rebuilds.
- **Dispose resources gracefully**: Audio players, stream subscriptions, and native controllers must be cleaned up on disposal via `ref.onDispose`.

---

## 4. Audio Performance & Threading Rules

Audio processing requires strict real-time guarantees:

- **Avoid blocking the UI thread**: The Flutter UI thread must maintain 60/120 fps smoothness without dropped frames.
- **Never perform heavy audio processing on the main isolate**:
  - FFT computation, spectrum visualization, waveform extraction, tag reading across hundreds of files, and DSP filters must run either in Dart background worker isolates (`compute` / `Isolate.run`) or within native C++ worker threads.
- **Native C++ Engine Boundary (`packages/sonora_audio_engine`)**:
  - Use C++ via Dart FFI only where profiling demonstrates a genuine, measurable performance bottleneck in Dart.
  - Native code must strictly handle memory leaks and exceptions before returning across the FFI boundary.

---

## 5. Platform Compatibility (Android & iOS)

- Maintain 100% feature and visual parity between Android and iOS.
- **Android**: Respect Scoped Storage (MediaStore API / SAF), Android 13+ granular audio permissions (`READ_MEDIA_AUDIO`), and foreground service audio focus management.
- **iOS**: Respect AVAudioSession category requirements, background audio modes (`UIBackgroundModes: audio`), and Lock Screen Now Playing / Remote Command Center integration.

---

## 6. Testing, Verification & Code Quality

- **Test every meaningful change**: Write unit tests for domain logic/notifiers and widget tests for key UI components.
- **Always verify before completion**:
  1. Run `flutter analyze` — zero errors or warnings allowed.
  2. Run `dart format .` — ensure uniform styling.
  3. Run `flutter test` — all tests must pass cleanly.
- **Build verification**: Verify Android and iOS build configs regularly. Never claim a build succeeds without executing it and inspecting the exit code.

