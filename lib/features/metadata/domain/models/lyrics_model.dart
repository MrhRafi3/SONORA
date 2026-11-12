import 'package:flutter/foundation.dart';

/// Single parsed lyric line with duration timestamp for synchronized playback.
@immutable
class LrcLyricLine {
  const LrcLyricLine({required this.timestamp, required this.text});

  final Duration timestamp;
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LrcLyricLine &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          text == other.text;

  @override
  int get hashCode => timestamp.hashCode ^ text.hashCode;

  @override
  String toString() => '[${timestamp.inSeconds}s] $text';
}

/// Offline persisted lyrics payload for a specific track.
@immutable
class TrackLyricsData {
  const TrackLyricsData({
    required this.trackId,
    this.plainLyrics,
    this.syncedLyrics,
    this.source = 'lrclib',
    required this.updatedAt,
  });

  final String trackId;
  final String? plainLyrics;
  final String? syncedLyrics;
  final String source;
  final DateTime updatedAt;

  bool get hasSynced => syncedLyrics != null && syncedLyrics!.trim().isNotEmpty;
  bool get hasPlain => plainLyrics != null && plainLyrics!.trim().isNotEmpty;
  bool get isEmpty => !hasSynced && !hasPlain;

  /// Parses synchronized LRC lyrics into chronological [LrcLyricLine] items.
  /// Falls back to lines from [plainLyrics] if synchronized lyrics are unavailable.
  List<LrcLyricLine> parseLines() {
    if (hasSynced) {
      final lines = parseLrcString(syncedLyrics!);
      if (lines.isNotEmpty) return lines;
    }

    if (hasPlain) {
      final plainLines = plainLyrics!
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      return [
        for (final line in plainLines)
          LrcLyricLine(timestamp: Duration.zero, text: line),
      ];
    }

    return const [];
  }

  /// Robust parser for LRC strings:
  /// Handles `[mm:ss.xx]`, `[mm:ss.xxx]`, `[mm:ss]`, multiple timestamps per line,
  /// and safely ignores non-lyric metadata tags `[ti:...]`, `[ar:...]`, `[al:...]`.
  static List<LrcLyricLine> parseLrcString(String lrcText) {
    final List<LrcLyricLine> result = [];
    final tagRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');
    final lines = lrcText.split('\n');

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Skip common LRC metadata headers like [ti:Title], [ar:Artist], etc.
      if (line.startsWith('[') && !line.startsWith(RegExp(r'\[\d'))) {
        continue;
      }

      final matches = tagRegex.allMatches(line).toList();
      if (matches.isEmpty) continue;

      // Extract remaining text after all timestamp tags
      final textPart = line.replaceAll(tagRegex, '').trim();

      for (final match in matches) {
        final min = int.tryParse(match.group(1) ?? '0') ?? 0;
        final sec = int.tryParse(match.group(2) ?? '0') ?? 0;
        final fracStr = match.group(3) ?? '0';

        int ms = 0;
        if (fracStr.length == 1) {
          ms = (int.tryParse(fracStr) ?? 0) * 100;
        } else if (fracStr.length == 2) {
          ms = (int.tryParse(fracStr) ?? 0) * 10;
        } else {
          ms = int.tryParse(fracStr.substring(0, 3)) ?? 0;
        }

        final duration = Duration(minutes: min, seconds: sec, milliseconds: ms);

        result.add(LrcLyricLine(timestamp: duration, text: textPart));
      }
    }

    // Sort lyrics chronologically
    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }
}

/// Search result model from LRCLIB API.
@immutable
class LrclibSearchResult {
  const LrclibSearchResult({
    required this.id,
    required this.trackName,
    required this.artistName,
    this.albumName = '',
    required this.duration,
    this.instrumental = false,
    this.plainLyrics,
    this.syncedLyrics,
  });

  factory LrclibSearchResult.fromJson(Map<String, dynamic> json) {
    return LrclibSearchResult(
      id: json['id'] as int? ?? 0,
      trackName: (json['trackName'] ?? json['name'] ?? '') as String,
      artistName: (json['artistName'] ?? '') as String,
      albumName: (json['albumName'] ?? '') as String,
      duration: (json['duration'] is num)
          ? (json['duration'] as num).toDouble()
          : 0.0,
      instrumental: json['instrumental'] as bool? ?? false,
      plainLyrics: json['plainLyrics'] as String?,
      syncedLyrics: json['syncedLyrics'] as String?,
    );
  }

  final int id;
  final String trackName;
  final String artistName;
  final String albumName;
  final double duration;
  final bool instrumental;
  final String? plainLyrics;
  final String? syncedLyrics;

  bool get isSynced => syncedLyrics != null && syncedLyrics!.trim().isNotEmpty;
  bool get hasContent =>
      (syncedLyrics?.trim().isNotEmpty ?? false) ||
      (plainLyrics?.trim().isNotEmpty ?? false) ||
      instrumental;

  /// Calculates a match score between 0.0 and 1.0 against target track metadata.
  double calculateMatchScore({
    required String targetTitle,
    required String targetArtist,
    Duration? targetDuration,
  }) {
    final titleScore = _stringSimilarity(trackName, targetTitle);
    final artistScore = _stringSimilarity(artistName, targetArtist);

    double durationScore = 1.0;
    if (targetDuration != null &&
        targetDuration.inSeconds > 0 &&
        duration > 0) {
      final diff = (targetDuration.inSeconds - duration).abs();
      if (diff <= 3) {
        durationScore = 1.0;
      } else if (diff <= 8) {
        durationScore = 0.8;
      } else if (diff <= 15) {
        durationScore = 0.5;
      } else {
        durationScore = 0.1;
      }
    }

    // Heavy weight on title and artist, with duration confirmation
    return (titleScore * 0.45) + (artistScore * 0.35) + (durationScore * 0.20);
  }

  /// Whether this result represents an exact/high-confidence match.
  bool isExactMatch({
    required String targetTitle,
    required String targetArtist,
    Duration? targetDuration,
  }) {
    final titleSim = _stringSimilarity(trackName, targetTitle);
    final artistSim = _stringSimilarity(artistName, targetArtist);

    bool durationMatches = true;
    if (targetDuration != null &&
        targetDuration.inSeconds > 0 &&
        duration > 0) {
      final diff = (targetDuration.inSeconds - duration).abs();
      durationMatches = diff <= 5;
    }

    return titleSim >= 0.88 && artistSim >= 0.80 && durationMatches;
  }

  static double _stringSimilarity(String a, String b) {
    final cleanA = _normalizeString(a);
    final cleanB = _normalizeString(b);

    if (cleanA.isEmpty && cleanB.isEmpty) return 1.0;
    if (cleanA.isEmpty || cleanB.isEmpty) return 0.0;
    if (cleanA == cleanB) return 1.0;
    if (cleanA.contains(cleanB) || cleanB.contains(cleanA)) {
      final shorter = cleanA.length < cleanB.length
          ? cleanA.length
          : cleanB.length;
      final longer = cleanA.length > cleanB.length
          ? cleanA.length
          : cleanB.length;
      return (shorter / longer).clamp(0.7, 0.95);
    }

    final distance = _levenshtein(cleanA, cleanB);
    final maxLen = cleanA.length > cleanB.length
        ? cleanA.length
        : cleanB.length;
    return (1.0 - (distance / maxLen)).clamp(0.0, 1.0);
  }

  static String _normalizeString(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), '') // remove (feat...), (remaster...)
        .replaceAll(RegExp(r'\[[^\]]*\]'), '') // remove [remastered...]
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '') // remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        final cost = (s.codeUnitAt(i) == t.codeUnitAt(j)) ? 0 : 1;
        final min1 = v1[j] + 1;
        final min2 = v0[j + 1] + 1;
        final min3 = v0[j] + cost;
        int m = min1 < min2 ? min1 : min2;
        v1[j + 1] = m < min3 ? m : min3;
      }
      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[t.length];
  }
}
