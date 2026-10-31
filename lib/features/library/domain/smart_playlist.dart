import 'package:flutter/material.dart';
import 'entities.dart';

/// Preset smart playlist definitions calculated dynamically from the library.
enum SmartPlaylistType {
  favorites(
    id: 'smart_favorites',
    name: 'Favorites',
    subtitle: 'Starred audiophile gems',
    icon: Icons.favorite_rounded,
    accentColor: Color(0xFFE07A5F),
  ),
  hiResMasters(
    id: 'smart_hi_res',
    name: 'Hi-Res Studio Masters',
    subtitle: '24-bit / 96kHz+ uncompressed',
    icon: Icons.album_rounded,
    accentColor: Color(0xFFE5C07B),
  ),
  recentlyAdded(
    id: 'smart_recently_added',
    name: 'Recently Added',
    subtitle: 'Latest arrivals in storage',
    icon: Icons.history_rounded,
    accentColor: Color(0xFF52B788),
  ),
  losslessVault(
    id: 'smart_lossless',
    name: 'Lossless Vault',
    subtitle: 'Bit-perfect FLAC & WAV',
    icon: Icons.diamond_outlined,
    accentColor: Color(0xFF5DADE2),
  );

  const SmartPlaylistType({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  /// Filters a list of tracks to match this smart playlist definition.
  List<AudioTrack> filter(List<AudioTrack> tracks) {
    switch (this) {
      case SmartPlaylistType.favorites:
        return tracks.where((t) => t.isFavorite).toList();
      case SmartPlaylistType.hiResMasters:
        return tracks.where((t) {
          final isHighSample = (t.sampleRateHz ?? 0) >= 88200;
          final isHighBit = (t.bitDepth ?? 0) >= 24;
          final isFlacOrWav =
              t.fileExtension.toLowerCase() == 'flac' ||
              t.fileExtension.toLowerCase() == 'wav';
          return isHighSample || isHighBit || isFlacOrWav;
        }).toList();
      case SmartPlaylistType.recentlyAdded:
        final sorted = List<AudioTrack>.from(tracks);
        sorted.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        return sorted.take(50).toList();
      case SmartPlaylistType.losslessVault:
        return tracks.where((t) {
          final ext = t.fileExtension.toLowerCase();
          return ext == 'flac' ||
              ext == 'wav' ||
              ext == 'alac' ||
              ext == 'aiff';
        }).toList();
    }
  }
}

/// Format filtering options for the tracks tab.
enum LibraryAudioFilter {
  all('All'),
  hiRes('Hi-Res'),
  lossless('Lossless'),
  standard('Standard');

  const LibraryAudioFilter(this.label);
  final String label;

  bool matches(AudioTrack track) {
    switch (this) {
      case LibraryAudioFilter.all:
        return true;
      case LibraryAudioFilter.hiRes:
        return ((track.sampleRateHz ?? 0) >= 88200) ||
            ((track.bitDepth ?? 0) >= 24);
      case LibraryAudioFilter.lossless:
        final ext = track.fileExtension.toLowerCase();
        return ext == 'flac' || ext == 'wav' || ext == 'alac' || ext == 'aiff';
      case LibraryAudioFilter.standard:
        final ext = track.fileExtension.toLowerCase();
        return ext == 'mp3' ||
            ext == 'm4a' ||
            ext == 'aac' ||
            ext == 'ogg' ||
            ext == 'opus';
    }
  }
}
