import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/artwork_cache_service.dart';
import '../../../core/services/audio_metadata_service.dart';
import 'android_media_scanner.dart';

/// Service managing audio file importation via the iOS Files app or system document picker.
class IosFileImporter {
  const IosFileImporter({
    this.metadataService = const AudioMetadataService(),
    this.artworkCacheService = const ArtworkCacheService(),
  });

  final AudioMetadataService metadataService;
  final ArtworkCacheService artworkCacheService;

  Future<Directory> get _musicImportDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'sonora_imported_music'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Opens the system document picker and imports selected audio files into app storage.
  Future<List<ExtractedScanItem>> pickAndImportAudioFiles() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.supportedAudioExtensions,
    );

    if (files.isEmpty) {
      return [];
    }

    final targetDir = await _musicImportDir;
    final importedItems = <ExtractedScanItem>[];

    for (final platformFile in files) {
      final sourcePath = platformFile.path;
      if (sourcePath == null) continue;

      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) continue;

      final fileName = p.basename(sourcePath);
      final ext = p.extension(sourcePath).toLowerCase().replaceAll('.', '');
      final destinationPath = p.join(targetDir.path, fileName);
      final destFile = File(destinationPath);

      // Copy into application private sandbox storage if not already present
      if (!await destFile.exists() ||
          (await destFile.length()) != (await sourceFile.length())) {
        await sourceFile.copy(destinationPath);
      }

      // Extract metadata from the permanent local file
      final meta = await metadataService.extractMetadata(
        destFile,
        extractArtwork: true,
      );

      String? artworkPath;
      if (meta.artworkBytes != null && meta.artworkBytes!.isNotEmpty) {
        artworkPath = await artworkCacheService.saveArtworkBytes(
          '${meta.album ?? meta.title}_${meta.artist}',
          meta.artworkBytes,
        );
      }

      final trackId =
          'ios_${p.basenameWithoutExtension(fileName).replaceAll(RegExp(r'\s+'), '_')}';

      importedItems.add(
        ExtractedScanItem(
          id: trackId,
          sourceUri: Uri.file(destFile.path).toString(),
          filePath: destFile.path,
          title: meta.title,
          artist: meta.artist,
          album: meta.album,
          albumArtist: meta.albumArtist,
          duration: meta.duration,
          fileExtension: ext.isNotEmpty ? ext : 'mp3',
          fileSizeBytes: meta.fileSizeBytes,
          bitrateKbps: meta.bitrateKbps,
          sampleRateHz: meta.sampleRateHz,
          bitDepth: meta.bitDepth,
          trackNumber: meta.trackNumber,
          discNumber: meta.discNumber,
          year: meta.year,
          genre: meta.genre,
          artworkPath: artworkPath,
          platformSource: 'ios_documents',
        ),
      );
    }

    return importedItems;
  }
}
