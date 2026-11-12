import 'dart:io';
import 'package:path/path.dart' as p;

/// Comprehensive filter and deduplication utility for the SONORA music scanner.
///
/// Ensures only authentic music files (MP3, FLAC, WAV, M4A/AAC, OGG, OPUS) are
/// imported, strictly excluding voice notes (WhatsApp, Telegram), call recordings,
/// system tones (ringtones, notifications, alarms), hidden folders, and directories
/// guarded by `.nomedia` markers.
class MusicFileFilter {
  MusicFileFilter({
    this.directoryExistsChecker = _defaultDirectoryExists,
    this.fileExistsChecker = _defaultFileExists,
  });

  final bool Function(String path) directoryExistsChecker;
  final bool Function(String path) fileExistsChecker;

  static bool _defaultDirectoryExists(String path) {
    try {
      return Directory(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  static bool _defaultFileExists(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// In-memory cache for directories containing `.nomedia` to prevent redundant I/O.
  final Map<String, bool> _noMediaDirectoryCache = {};

  /// Excluded directory keyword signatures (matched case-insensitively).
  static const List<String> excludedFolderKeywords = [
    // WhatsApp voice notes, media, and attachments
    'whatsapp voice notes',
    'whatsapp audio',
    'whatsapp animated gifs',
    'whatsapp documents',
    'com.whatsapp',
    'com.whatsapp.w4b',

    // Telegram audio messages and attachments
    'telegram audio',
    'telegram documents',
    'telegram video',
    'org.telegram.messenger',

    // Other messaging and social apps
    'org.thoughtcrime.securesms', // Signal
    'com.facebook.orca', // Messenger
    'com.tencent.mm', // WeChat
    'com.viber.voip', // Viber
    'com.discord', // Discord
    'com.slack', // Slack
    'jp.naver.line.android', // Line
    'com.skype.raider', // Skype
    // Call and voice recordings
    'callrecordings',
    'call recordings',
    'call_recordings',
    'soundrecorder',
    'voice recorder',
    'voicerecorder',
    'voice recordings',
    'voicerecordings',
    'voice notes',
    'voicenotes',
    '/recordings/call',
    '/calls/',

    // System chimes and notification tones
    '/ringtones/',
    '/notifications/',
    '/alarms/',
    '/ui/',
    '/system/media/',
    'media/audio/ringtones',
    'media/audio/notifications',
    'media/audio/alarms',

    // Internal app caches and system directories
    '/android/data/',
    '/android/obb/',
    '/.thumbnails',
    '/.trash',
    '/.cache',
  ];

  /// Standard audio extensions supported by SONORA.
  static const Set<String> supportedExtensions = {
    'mp3',
    'flac',
    'wav',
    'm4a',
    'aac',
    'ogg',
    'opus',
  };

  /// Determines whether [filePath] belongs to an excluded audio category.
  bool isExcludedPath(
    String filePath, {
    String? displayName,
    int? durationMs,
    bool checkNoMedia = true,
  }) {
    if (filePath.isEmpty) return true;

    final normalized = filePath.replaceAll('\\', '/');
    final lower = normalized.toLowerCase();
    final name = displayName?.isNotEmpty == true
        ? displayName!
        : p.basename(normalized);
    final lowerName = name.toLowerCase();

    // 1. Exclude hidden files (e.g. ._song.mp3, .track.flac)
    if (lowerName.startsWith('.')) {
      return true;
    }

    // 2. Exclude hidden directories (any segment starting with '.')
    final segments = p.split(normalized);
    for (var i = 0; i < segments.length - 1; i++) {
      final seg = segments[i];
      if (seg.startsWith('.') && seg != '.' && seg != '..') {
        return true;
      }
    }

    // 3. Exclude known messaging, recording, and system folder signatures
    for (final keyword in excludedFolderKeywords) {
      if (lower.contains(keyword)) {
        return true;
      }
    }

    // 4. Exclude specific standalone folder names that represent system sound types
    for (var i = 0; i < segments.length - 1; i++) {
      final s = segments[i].toLowerCase();
      if (s == 'ringtones' ||
          s == 'notifications' ||
          s == 'alarms' ||
          s == 'voice recorder' ||
          s == 'soundrecorder' ||
          s == 'call recordings' ||
          s == 'callrecordings') {
        return true;
      }
    }

    // 5. Exclude WhatsApp voice note filename patterns (PTT-YYYYMMDD-WA....opus)
    if (lowerName.startsWith('ptt-') &&
        (lower.contains('wa') ||
            lower.contains('opus') ||
            lower.contains('m4a'))) {
      return true;
    }

    // 6. Exclude WhatsApp audio filename patterns (AUD-YYYYMMDD-WA....)
    if (lowerName.startsWith('aud-') && lower.contains('wa')) {
      return true;
    }

    // 7. Exclude call recording filename patterns
    if (lowerName.startsWith('call@') ||
        lowerName.startsWith('call_') ||
        (lowerName.startsWith('rec_') && lower.contains('call'))) {
      return true;
    }

    // 8. Non-music duration check: files under 5 seconds outside of standard Music folders
    // are almost always system UI sounds, notification blips, or voice micro-notes.
    final isInMusicFolder =
        lower.contains('/music/') || lower.endsWith('/music');
    if (!isInMusicFolder &&
        durationMs != null &&
        durationMs > 0 &&
        durationMs < 5000) {
      return true;
    }

    // 9. Check for .nomedia files up the directory tree
    if (checkNoMedia && hasNoMediaMarker(filePath)) {
      return true;
    }

    return false;
  }

  /// Checks if any directory in [filePath]'s hierarchy contains a `.nomedia` file.
  bool hasNoMediaMarker(String filePath) {
    if (filePath.isEmpty) return false;
    final normalized = filePath.replaceAll('\\', '/');

    var dir = p.dirname(normalized);
    final visitedDirs = <String>[];

    while (dir.isNotEmpty && dir != '/' && dir != '.') {
      if (_noMediaDirectoryCache.containsKey(dir)) {
        final hasMarker = _noMediaDirectoryCache[dir]!;
        for (final v in visitedDirs) {
          _noMediaDirectoryCache[v] = hasMarker;
        }
        return hasMarker;
      }

      visitedDirs.add(dir);
      final noMediaPath = p.join(dir, '.nomedia');
      if (fileExistsChecker(noMediaPath)) {
        for (final v in visitedDirs) {
          _noMediaDirectoryCache[v] = true;
        }
        return true;
      }

      final parent = p.dirname(dir);
      if (parent == dir) break;
      dir = parent;
    }

    for (final v in visitedDirs) {
      _noMediaDirectoryCache[v] = false;
    }
    return false;
  }

  /// Clears cached `.nomedia` directory results.
  void clearCache() {
    _noMediaDirectoryCache.clear();
  }

  /// Determines if [filePath] represents a valid, non-excluded music file.
  bool isMusicFile(
    String filePath, {
    String? displayName,
    int? durationMs,
    bool checkNoMedia = true,
  }) {
    final ext = p.extension(filePath).toLowerCase().replaceAll('.', '');
    if (!supportedExtensions.contains(ext)) {
      final name = displayName ?? '';
      final displayExt = p.extension(name).toLowerCase().replaceAll('.', '');
      if (!supportedExtensions.contains(displayExt)) {
        return false;
      }
    }

    return !isExcludedPath(
      filePath,
      displayName: displayName,
      durationMs: durationMs,
      checkNoMedia: checkNoMedia,
    );
  }

  /// Computes a priority score for a file path.
  /// Standard `/Music` paths receive highest priority (10), followed by
  /// `/Download` (5), and others (1).
  int getPriorityScore(String filePath) {
    final lower = filePath.replaceAll('\\', '/').toLowerCase();
    if (lower.contains('/music/') || lower.endsWith('/music')) {
      return 10;
    }
    if (lower.contains('/download/') || lower.contains('/downloads/')) {
      return 5;
    }
    return 1;
  }
}
