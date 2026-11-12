import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../app/theme/theme_accent.dart';

/// Lightweight, non-destructive JSON persistence for daily-use preferences
/// (theme mode, accent palette, and disconnect pause behavior).
class AppPreferencesService {
  const AppPreferencesService();

  static const String _fileName = 'sonora_preferences.json';

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

  Future<Map<String, dynamic>> loadAll() async {
    final file = await _prefsFile();
    if (file == null) return const {};
    try {
      if (!await file.exists()) return const {};
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Ignore corrupt preference files and fall back to defaults.
    }
    return const {};
  }

  Future<void> updateKey(String key, dynamic value) async {
    final file = await _prefsFile();
    if (file == null) return;
    try {
      final current = Map<String, dynamic>.from(await loadAll());
      current[key] = value;
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(current), flush: true);
    } catch (_) {
      // Best-effort persistence; never crash UI on storage errors.
    }
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
