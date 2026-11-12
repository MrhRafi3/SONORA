import 'package:flutter/foundation.dart';

enum ArtworkProvider { itunes, deezer, musicBrainz }

/// Representation of an online album artwork candidate discovered from a metadata provider.
@immutable
class ArtworkMatch {
  const ArtworkMatch({
    required this.album,
    required this.artist,
    required this.imageUrl,
    required this.provider,
    required this.confidence,
    this.releaseYear,
  });

  final String album;
  final String artist;
  final String imageUrl;
  final ArtworkProvider provider;
  final double confidence;
  final String? releaseYear;

  bool get isHighConfidence => confidence >= 0.85;

  String get providerDisplayName {
    switch (provider) {
      case ArtworkProvider.itunes:
        return 'Apple iTunes';
      case ArtworkProvider.deezer:
        return 'Deezer';
      case ArtworkProvider.musicBrainz:
        return 'MusicBrainz';
    }
  }

  /// Calculates combined confidence score based on artist and album match.
  /// Strictly requires both artist and album to be evaluated (does not rely on title alone).
  static double calculateConfidence({
    required String targetArtist,
    required String targetAlbum,
    required String candidateArtist,
    required String candidateAlbum,
  }) {
    final artistSim = stringSimilarity(targetArtist, candidateArtist);
    final albumSim = stringSimilarity(targetAlbum, candidateAlbum);

    // If either artist or album is wildly different, confidence drops significantly
    if (artistSim < 0.50 || albumSim < 0.40) {
      return (artistSim * 0.5 + albumSim * 0.5) * 0.5;
    }

    // Artist accuracy has 55% weight, album accuracy 45%
    return ((artistSim * 0.55) + (albumSim * 0.45)).clamp(0.0, 1.0);
  }

  static double stringSimilarity(String a, String b) {
    final cleanA = normalize(a);
    final cleanB = normalize(b);

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
      return (shorter / longer).clamp(0.75, 0.96);
    }

    final distance = _levenshtein(cleanA, cleanB);
    final maxLen = cleanA.length > cleanB.length
        ? cleanA.length
        : cleanB.length;
    return (1.0 - (distance / maxLen)).clamp(0.0, 1.0);
  }

  static String normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), '') // remove parenthesized details
        .replaceAll(RegExp(r'\[[^\]]*\]'), '') // remove bracketed details
        .replaceAll(
          RegExp(r'\b(remastered|deluxe|version|edition|single|ep)\b'),
          '',
        )
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
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
