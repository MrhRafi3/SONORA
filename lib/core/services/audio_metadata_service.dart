import 'dart:io';
import 'dart:typed_data';
import 'package:audio_metadata_reader/audio_metadata_reader.dart' as amr;
import 'package:path/path.dart' as p;
import '../constants/app_constants.dart';

/// Parsed metadata container from an audio file.
class ExtractedMetadata {
  const ExtractedMetadata({
    required this.title,
    this.artist,
    this.album,
    this.albumArtist,
    required this.duration,
    required this.fileExtension,
    required this.fileSizeBytes,
    this.bitrateKbps,
    this.sampleRateHz,
    this.bitDepth,
    this.trackNumber,
    this.discNumber,
    this.year,
    this.genre,
    this.artworkBytes,
  });

  final String title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final Duration duration;
  final String fileExtension;
  final int fileSizeBytes;
  final int? bitrateKbps;
  final int? sampleRateHz;
  final int? bitDepth;
  final int? trackNumber;
  final int? discNumber;
  final int? year;
  final String? genre;
  final Uint8List? artworkBytes;
}

/// Service that extracts tags, audio specifications, and embedded artwork.
class AudioMetadataService {
  const AudioMetadataService();

  /// Determines if [filePath] has a supported audio extension.
  bool isSupportedAudioFile(String filePath) {
    final ext = p.extension(filePath).toLowerCase().replaceAll('.', '');
    return AppConstants.supportedAudioExtensions.contains(ext);
  }

  /// Extracts metadata from [file], falling back gracefully if tags are absent.
  Future<ExtractedMetadata> extractMetadata(
    File file, {
    bool extractArtwork = true,
  }) async {
    final fileName = p.basename(file.path);
    final ext = p.extension(file.path).toLowerCase().replaceAll('.', '');
    final fallbackTitle = p.basenameWithoutExtension(file.path);

    int fileSizeBytes = 0;
    try {
      fileSizeBytes = await file.length();
    } catch (_) {
      fileSizeBytes = 0;
    }

    try {
      final meta = amr.readMetadata(file, getImage: extractArtwork);

      // Clean extracted strings
      final title = (meta.title?.trim().isNotEmpty == true)
          ? meta.title!.trim()
          : fallbackTitle;

      final artist = (meta.artist?.trim().isNotEmpty == true)
          ? meta.artist!.trim()
          : null;

      final album = (meta.album?.trim().isNotEmpty == true)
          ? meta.album!.trim()
          : null;

      final albumArtist = (meta.albumArtist?.trim().isNotEmpty == true)
          ? meta.albumArtist!.trim()
          : null;

      final genre =
          (meta.genres.isNotEmpty && meta.genres.first.trim().isNotEmpty)
          ? meta.genres.first.trim()
          : null;

      // Bitrate normalization: convert bps (>1000) to kbps
      int? bitrateKbps;
      if (meta.bitrate != null && meta.bitrate! > 0) {
        bitrateKbps = meta.bitrate! > 1000
            ? (meta.bitrate! / 1000).round()
            : meta.bitrate;
      }

      // Pick front cover or first picture
      Uint8List? artworkBytes;
      if (extractArtwork && meta.pictures.isNotEmpty) {
        final frontCover = meta.pictures.firstWhere(
          (p) => p.pictureType == amr.PictureType.coverFront,
          orElse: () => meta.pictures.first,
        );
        artworkBytes = frontCover.bytes;
      }

      return ExtractedMetadata(
        title: title,
        artist: artist,
        album: album,
        albumArtist: albumArtist,
        duration: meta.duration ?? Duration.zero,
        fileExtension: ext.isNotEmpty ? ext : 'unknown',
        fileSizeBytes: fileSizeBytes,
        bitrateKbps: bitrateKbps,
        sampleRateHz: meta.sampleRate,
        trackNumber: meta.trackNumber,
        discNumber: meta.discNumber,
        year: meta.year?.year,
        genre: genre,
        artworkBytes: artworkBytes,
      );
    } catch (_) {
      // Return safe fallback metadata for files without valid ID3/Vorbis headers
      return ExtractedMetadata(
        title: fallbackTitle.isNotEmpty ? fallbackTitle : fileName,
        artist: null,
        album: null,
        duration: Duration.zero,
        fileExtension: ext.isNotEmpty ? ext : 'mp3',
        fileSizeBytes: fileSizeBytes,
      );
    }
  }
}
