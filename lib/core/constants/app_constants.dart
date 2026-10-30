/// Application-wide constants for SONORA.
abstract final class AppConstants {
  static const String appName = 'SONORA';
  static const String appTagline = 'High-Resolution Offline Audio';

  // Supported Audio Extensions
  static const List<String> supportedAudioExtensions = [
    'mp3',
    'flac',
    'wav',
    'm4a',
    'aac',
    'ogg',
    'opus',
  ];

  // Database
  static const String databaseName = 'sonora.db';
  static const int databaseSchemaVersion = 1;
}
