import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/artwork_match.dart';

/// Client for searching and downloading missing album artwork from online providers:
/// 1. Apple iTunes Search API (primary)
/// 2. Deezer Search API (secondary)
/// 3. MusicBrainz + Cover Art Archive (fallback)
class OnlineArtworkClient {
  OnlineArtworkClient({http.Client? httpClient})
    : _client = httpClient ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 8);

  /// Searches for matching album artwork across providers.
  /// Priority order: iTunes -> Deezer -> MusicBrainz.
  /// Returns a list of candidates sorted by confidence score.
  Future<List<ArtworkMatch>> searchArtwork({
    required String artist,
    required String album,
    String? trackTitle,
  }) async {
    final List<ArtworkMatch> matches = [];

    // Normalize search query
    final cleanArtist = ArtworkMatch.normalize(artist);
    final cleanAlbum = ArtworkMatch.normalize(album);

    if (cleanArtist.isEmpty && cleanAlbum.isEmpty) {
      return const [];
    }

    // 1. Primary: iTunes Search API
    try {
      final itunesMatches = await _searchItunes(
        targetArtist: artist,
        targetAlbum: album,
      );
      matches.addAll(itunesMatches);
    } catch (e) {
      debugPrint('[OnlineArtworkClient] iTunes search error: $e');
    }

    // If iTunes found a high-confidence match (>= 0.88), return early to save network bandwidth
    if (matches.any((m) => m.confidence >= 0.88)) {
      matches.sort((a, b) => b.confidence.compareTo(a.confidence));
      return matches;
    }

    // 2. Secondary: Deezer Search API
    try {
      final deezerMatches = await _searchDeezer(
        targetArtist: artist,
        targetAlbum: album,
      );
      matches.addAll(deezerMatches);
    } catch (e) {
      debugPrint('[OnlineArtworkClient] Deezer search error: $e');
    }

    // If Deezer or iTunes found high confidence, return
    if (matches.any((m) => m.confidence >= 0.85)) {
      matches.sort((a, b) => b.confidence.compareTo(a.confidence));
      return matches;
    }

    // 3. Fallback: MusicBrainz + Cover Art Archive
    try {
      final mbMatches = await _searchMusicBrainz(
        targetArtist: artist,
        targetAlbum: album,
      );
      matches.addAll(mbMatches);
    } catch (e) {
      debugPrint('[OnlineArtworkClient] MusicBrainz search error: $e');
    }

    // Deduplicate by image URL and sort by confidence descending
    final seenUrls = <String>{};
    final uniqueMatches = <ArtworkMatch>[];
    for (final match in matches) {
      if (!seenUrls.contains(match.imageUrl)) {
        seenUrls.add(match.imageUrl);
        uniqueMatches.add(match);
      }
    }

    uniqueMatches.sort((a, b) => b.confidence.compareTo(a.confidence));
    return uniqueMatches;
  }

  /// Downloads image binary bytes from [imageUrl].
  /// Returns null if network fails, times out, or image is corrupt/empty.
  Future<Uint8List?> downloadImageBytes(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final response = await _client.get(uri).timeout(_timeout);

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        // Basic sanity check: image bytes should be at least 1 KB
        if (response.bodyBytes.length >= 1024) {
          return response.bodyBytes;
        }
      }
    } on SocketException catch (_) {
      return null;
    } on TimeoutException catch (_) {
      return null;
    } catch (e) {
      debugPrint('[OnlineArtworkClient] downloadImageBytes error: $e');
    }
    return null;
  }

  Future<List<ArtworkMatch>> _searchItunes({
    required String targetArtist,
    required String targetAlbum,
  }) async {
    final List<ArtworkMatch> results = [];
    final searchTerm = '$targetArtist $targetAlbum'.trim();
    final uri = Uri.parse('https://itunes.apple.com/search').replace(
      queryParameters: {'term': searchTerm, 'entity': 'album', 'limit': '5'},
    );

    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode == 200) {
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      final rawList = data['results'] as List<dynamic>? ?? [];

      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          final candArtist = (item['artistName'] ?? '') as String;
          final candAlbum = (item['collectionName'] ?? '') as String;
          final rawArtUrl = (item['artworkUrl100'] ?? '') as String;

          if (rawArtUrl.isEmpty) continue;

          // Upgrade to high-resolution 600x600 artwork
          final highResUrl = rawArtUrl.replaceAll('100x100bb', '600x600bb');
          final confidence = ArtworkMatch.calculateConfidence(
            targetArtist: targetArtist,
            targetAlbum: targetAlbum,
            candidateArtist: candArtist,
            candidateAlbum: candAlbum,
          );

          final releaseDate = item['releaseDate'] as String?;
          String? year;
          if (releaseDate != null && releaseDate.length >= 4) {
            year = releaseDate.substring(0, 4);
          }

          results.add(
            ArtworkMatch(
              album: candAlbum,
              artist: candArtist,
              imageUrl: highResUrl,
              provider: ArtworkProvider.itunes,
              confidence: confidence,
              releaseYear: year,
            ),
          );
        }
      }
    }
    return results;
  }

  Future<List<ArtworkMatch>> _searchDeezer({
    required String targetArtist,
    required String targetAlbum,
  }) async {
    final List<ArtworkMatch> results = [];
    final searchTerm = '$targetArtist $targetAlbum'.trim();
    final uri = Uri.parse(
      'https://api.deezer.com/search/album',
    ).replace(queryParameters: {'q': searchTerm, 'limit': '5'});

    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode == 200) {
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      final rawList = data['data'] as List<dynamic>? ?? [];

      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          final candAlbum = (item['title'] ?? '') as String;
          final artistObj = item['artist'] as Map<String, dynamic>?;
          final candArtist = (artistObj?['name'] ?? '') as String;

          // Deezer provides cover_xl (1000x1000) or cover_big (500x500)
          final coverUrl =
              (item['cover_xl'] ??
                      item['cover_big'] ??
                      item['cover_medium'] ??
                      '')
                  as String;
          if (coverUrl.isEmpty) continue;

          final confidence = ArtworkMatch.calculateConfidence(
            targetArtist: targetArtist,
            targetAlbum: targetAlbum,
            candidateArtist: candArtist,
            candidateAlbum: candAlbum,
          );

          results.add(
            ArtworkMatch(
              album: candAlbum,
              artist: candArtist,
              imageUrl: coverUrl,
              provider: ArtworkProvider.deezer,
              confidence: confidence,
            ),
          );
        }
      }
    }
    return results;
  }

  Future<List<ArtworkMatch>> _searchMusicBrainz({
    required String targetArtist,
    required String targetAlbum,
  }) async {
    final List<ArtworkMatch> results = [];
    final query = 'release:"$targetAlbum" AND artist:"$targetArtist"';
    final uri = Uri.parse(
      'https://musicbrainz.org/ws/2/release/',
    ).replace(queryParameters: {'query': query, 'fmt': 'json', 'limit': '3'});

    final response = await _client
        .get(
          uri,
          headers: {
            'User-Agent': 'SONORA/1.0.0 (https://github.com/mrhrafi3/sonora)',
            'Accept': 'application/json',
          },
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      final releases = data['releases'] as List<dynamic>? ?? [];

      for (final rel in releases) {
        if (rel is Map<String, dynamic>) {
          final mbid = rel['id'] as String?;
          final candAlbum = (rel['title'] ?? '') as String;
          final credits = rel['artist-credit'] as List<dynamic>?;
          String candArtist = '';
          if (credits != null && credits.isNotEmpty) {
            candArtist = (credits.first['name'] ?? '') as String;
          }

          if (mbid == null || mbid.isEmpty) continue;

          // Cover Art Archive URL
          final coverUrl =
              'https://coverartarchive.org/release/$mbid/front-500';
          final confidence = ArtworkMatch.calculateConfidence(
            targetArtist: targetArtist,
            targetAlbum: targetAlbum,
            candidateArtist: candArtist,
            candidateAlbum: candAlbum,
          );

          results.add(
            ArtworkMatch(
              album: candAlbum,
              artist: candArtist,
              imageUrl: coverUrl,
              provider: ArtworkProvider.musicBrainz,
              confidence: confidence,
            ),
          );
        }
      }
    }
    return results;
  }

  void close() {
    _client.close();
  }
}
