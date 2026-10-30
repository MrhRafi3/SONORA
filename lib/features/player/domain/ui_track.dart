import 'package:flutter/material.dart';

/// Presentation-level track representation for the SONORA UI design system.
@immutable
class UiTrack {
  const UiTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.audioFormat,
    this.sampleRate = '96 kHz',
    this.bitDepth = '24-bit',
    this.artworkColor = const Color(0xFF2C2523),
    this.accentColor = const Color(0xFFE59866),
    this.isFavorite = false,
    this.artworkPath,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String audioFormat;
  final String sampleRate;
  final String bitDepth;
  final Color artworkColor;
  final Color accentColor;
  final bool isFavorite;
  final String? artworkPath;

  String get formatBadge => '$audioFormat • $bitDepth/$sampleRate';

  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  UiTrack copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? audioFormat,
    String? sampleRate,
    String? bitDepth,
    Color? artworkColor,
    Color? accentColor,
    bool? isFavorite,
    String? artworkPath,
  }) {
    return UiTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      audioFormat: audioFormat ?? this.audioFormat,
      sampleRate: sampleRate ?? this.sampleRate,
      bitDepth: bitDepth ?? this.bitDepth,
      artworkColor: artworkColor ?? this.artworkColor,
      accentColor: accentColor ?? this.accentColor,
      isFavorite: isFavorite ?? this.isFavorite,
      artworkPath: artworkPath ?? this.artworkPath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UiTrack && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
