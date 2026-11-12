import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../app/theme/theme_accent.dart';

/// Lightweight, non-destructive JSON persistence for daily-use preferences
/// (theme mode, accent palette, disconnect pause behavior, and playback restoration session).
class AppPreferencesService {
  const AppPreferencesService();

  static const String _fileName = 'sonora_preferences.json';

  static const String keyLastPlaybackTrackId = 'last_playback_track_id';
  static const String keyLastPlaybackPositionMs = 'last_playback_position_ms';
  static const String keyLastPlaybackQueueIds = 'last_playback_queue_ids';
  static const String keyLastPlaybackQueueIndex = 'last_playback_queue_index';

  static Map<String, dynamic> _cachedMap = {};
  static Map<String, dynamic>? _testPreferences;

  @visibleForTesting
  static void setTestPreferences(Map<String, dynamic>? prefs) {
    _testPreferences = prefs != null ? Map<String, dynamic>.from(prefs) : null;
    if (prefs != null) {
      _cachedMap = Map<String, dynamic>.from(prefs);
    } else {
      _cachedMap = {};
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _testPreferences = null;
    _cachedMap = {};
  }

  Future<File?> _prefsFile() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }
    try {
      final dir = await getApplicationSupportDirectory();
      return File(p.join(dir.path, _fileName));
    } catch (_) {
      return null;
    }
  }

  /// Warms the synchronous memory cache from disk.
  Future<Map<String, dynamic>> init() => loadAll();

  Future<Map<String, dynamic>> loadAll() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      final current = _testPreferences ?? const {};
      _cachedMap = Map<String, dynamic>.from(current);
      return current;
    }

    final file = await _prefsFile();
    if (file == null) return _cachedMap;
    try {
      if (!await file.exists()) return _cachedMap;
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _cachedMap = Map<String, dynamic>.from(decoded);
        return decoded;
      }
    } catch (_) {
      // Ignore corrupt preference files and fall back to defaults.
    }
    return _cachedMap;
  }

  Future<void> updateKey(String key, dynamic value) async {
    _cachedMap[key] = value;
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      if (_testPreferences != null) {
        _testPreferences![key] = value;
      }
      return;
    }

    final file = await _prefsFile();
    if (file == null) return;
    try {
      final current = Map<String, dynamic>.from(await loadAll());
      current[key] = value;
      _cachedMap = current;
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(current), flush: true);
    } catch (_) {
      // Best-effort persistence; never crash UI on storage errors.
    }
  }

  /// Persists the active track, scrubbed position, and playback queue indices.
  Future<void> savePlaybackSession({
    required String trackId,
    required int positionMs,
    required List<String> queueIds,
    required int queueIndex,
  }) async {
    final current = Map<String, dynamic>.from(_cachedMap);
    current[keyLastPlaybackTrackId] = trackId;
    current[keyLastPlaybackPositionMs] = positionMs;
    current[keyLastPlaybackQueueIds] = queueIds;
    current[keyLastPlaybackQueueIndex] = queueIndex;
    _cachedMap = current;

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      if (_testPreferences != null) {
        _testPreferences = current;
      }
      return;
    }

    final file = await _prefsFile();
    if (file == null) return;
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(current), flush: true);
    } catch (_) {
      // Best-effort persistence
    }
  }

  /// Loads the saved playback session asynchronously.
  Future<
    ({String? trackId, int positionMs, List<String> queueIds, int queueIndex})
  >
  loadPlaybackSession() async {
    final all = await loadAll();
    return _extractSessionFromMap(all);
  }

  /// Synchronous retrieval of the loaded or cached playback session.
  ({String? trackId, int positionMs, List<String> queueIds, int queueIndex})
  getCachedPlaybackSession() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      if (_testPreferences != null) {
        return _extractSessionFromMap(_testPreferences!);
      }
      return (
        trackId: null,
        positionMs: 0,
        queueIds: const <String>[],
        queueIndex: 0,
      );
    }
    return _extractSessionFromMap(_cachedMap);
  }

  ({String? trackId, int positionMs, List<String> queueIds, int queueIndex})
  _extractSessionFromMap(Map<String, dynamic> map) {
    final trackId = map[keyLastPlaybackTrackId]?.toString();
    final positionMs = (map[keyLastPlaybackPositionMs] as num?)?.toInt() ?? 0;
    final rawQueue = map[keyLastPlaybackQueueIds];
    final queueIds = rawQueue is List
        ? rawQueue.map((e) => e.toString()).toList()
        : <String>[];
    final queueIndex = (map[keyLastPlaybackQueueIndex] as num?)?.toInt() ?? 0;

    return (
      trackId: trackId,
      positionMs: positionMs,
      queueIds: queueIds,
      queueIndex: queueIndex,
    );
  }

  /// Clears the saved playback session on user queue dismissal.
  Future<void> clearPlaybackSession() async {
    _cachedMap.remove(keyLastPlaybackTrackId);
    _cachedMap.remove(keyLastPlaybackPositionMs);
    _cachedMap.remove(keyLastPlaybackQueueIds);
    _cachedMap.remove(keyLastPlaybackQueueIndex);

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _testPreferences?.remove(keyLastPlaybackTrackId);
      _testPreferences?.remove(keyLastPlaybackPositionMs);
      _testPreferences?.remove(keyLastPlaybackQueueIds);
      _testPreferences?.remove(keyLastPlaybackQueueIndex);
      return;
    }

    final file = await _prefsFile();
    if (file == null) return;
    try {
      final current = Map<String, dynamic>.from(await loadAll());
      current.remove(keyLastPlaybackTrackId);
      current.remove(keyLastPlaybackPositionMs);
      current.remove(keyLastPlaybackQueueIds);
      current.remove(keyLastPlaybackQueueIndex);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(current), flush: true);
    } catch (_) {}
  }

  static ThemeMode? parseThemeMode(String? raw) {
    return switch (raw) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => null,
    };
  }

  static String serializeThemeMode(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    };
  }

  static ThemeAccent? parseAccent(String? id) {
    if (id == null) return null;
    for (final accent in ThemeAccent.values) {
      if (accent.id == id) return accent;
    }
    return null;
  }
}
