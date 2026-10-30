import 'package:flutter/material.dart';
import '../../player/domain/ui_track.dart';

/// Clean Architecture domain entity representing an indexed audio track.
@immutable
class AudioTrack {
  const AudioTrack({
    required this.id,
    required this.sourceUri,
    required this.filePath,
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
    this.artworkPath,
    this.platformSource = 'local',
    required this.dateAdded,
    this.dateModified,
    this.isFavorite = false,
    this.isAvailable = true,
  });

  final String id;
  final String sourceUri;
  final String filePath;
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
  final String? artworkPath;
  final String platformSource;
  final DateTime dateAdded;
  final DateTime? dateModified;
  final bool isFavorite;
  final bool isAvailable;

  /// Display presentation fallbacks
  String get displayArtist =>
      (artist?.isNotEmpty == true) ? artist! : 'Unknown Artist';
  String get displayAlbum =>
      (album?.isNotEmpty == true) ? album! : 'Unknown Album';

  /// High-resolution audio format pill label
  String get formatBadge {
    final extUpper = fileExtension.toUpperCase();
    if (sampleRateHz != null && sampleRateHz! > 0) {
      final khz = (sampleRateHz! / 1000)
          .toStringAsFixed(1)
          .replaceAll('.0', '');
      final depth = bitDepth != null ? '$bitDepth-bit/' : '';
      return '$extUpper • $depth$khz kHz';
    }
    if (bitrateKbps != null && bitrateKbps! > 0) {
      return '$extUpper • $bitrateKbps kbps';
    }
    return extUpper;
  }

  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Converts this domain entity into a [UiTrack] for seamless UI component rendering.
  UiTrack toUiTrack() {
    return UiTrack(
      id: id,
      title: title,
      artist: displayArtist,
      album: displayAlbum,
      duration: duration,
      audioFormat: fileExtension.toUpperCase(),
      sampleRate: sampleRateHz != null
          ? '${(sampleRateHz! / 1000).toStringAsFixed(1)} kHz'
          : '44.1 kHz',
      bitDepth: bitDepth != null
          ? '$bitDepth-bit'
          : (bitrateKbps != null ? '$bitrateKbps kbps' : '16-bit'),
      isFavorite: isFavorite,
      artworkPath: artworkPath,
    );
  }

  AudioTrack copyWith({
    String? id,
    String? sourceUri,
    String? filePath,
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    Duration? duration,
    String? fileExtension,
    int? fileSizeBytes,
    int? bitrateKbps,
    int? sampleRateHz,
    int? bitDepth,
    int? trackNumber,
    int? discNumber,
    int? year,
    String? genre,
    String? artworkPath,
    String? platformSource,
    DateTime? dateAdded,
    DateTime? dateModified,
    bool? isFavorite,
    bool? isAvailable,
  }) {
    return AudioTrack(
      id: id ?? this.id,
      sourceUri: sourceUri ?? this.sourceUri,
      filePath: filePath ?? this.filePath,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      duration: duration ?? this.duration,
      fileExtension: fileExtension ?? this.fileExtension,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      bitrateKbps: bitrateKbps ?? this.bitrateKbps,
      sampleRateHz: sampleRateHz ?? this.sampleRateHz,
      bitDepth: bitDepth ?? this.bitDepth,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      artworkPath: artworkPath ?? this.artworkPath,
      platformSource: platformSource ?? this.platformSource,
      dateAdded: dateAdded ?? this.dateAdded,
      dateModified: dateModified ?? this.dateModified,
      isFavorite: isFavorite ?? this.isFavorite,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioTrack && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Domain entity representing a music album collection.
@immutable
class AudioAlbum {
  const AudioAlbum({
    required this.name,
    required this.artist,
    this.year,
    required this.trackCount,
    this.artworkPath,
  });

  final String name;
  final String artist;
  final int? year;
  final int trackCount;
  final String? artworkPath;

  String get id => '$name-$artist';
}

/// Domain entity representing an artist collection.
@immutable
class AudioArtist {
  const AudioArtist({
    required this.name,
    required this.trackCount,
    required this.albumCount,
  });

  final String name;
  final int trackCount;
  final int albumCount;

  String get id => name;
}

/// Domain entity representing a user playlist.
@immutable
class AudioPlaylist {
  const AudioPlaylist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.trackCount = 0,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int trackCount;
}

/// Result of an Android or iOS scan/import operation.
class ScanSummary {
  const ScanSummary({
    required this.scannedCount,
    required this.newlyAddedCount,
    required this.failedCount,
    this.errorMessage,
  });

  final int scannedCount;
  final int newlyAddedCount;
  final int failedCount;
  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}
