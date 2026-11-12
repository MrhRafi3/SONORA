import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/lyrics_model.dart';

/// HTTP Client for querying LRCLIB API for synchronized (.lrc) and plain lyrics.
class LrclibClient {
  LrclibClient({
    http.Client? httpClient,
    this.baseUrl = 'https://lrclib.net/api',
  }) : _client = httpClient ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  static const Map<String, String> _headers = {
    'User-Agent':
        'SONORA-Audiophile-Player/1.0.0 (https://github.com/mrhrafi3/sonora)',
    'Accept': 'application/json',
  };

  static const Duration _timeout = Duration(seconds: 8);

  /// Queries the `/api/get` exact-match endpoint.
  /// Returns [LrclibSearchResult] if found, or null on 404 / network failure.
  Future<LrclibSearchResult?> getExactLyrics({
    required String title,
    required String artist,
    String? album,
    Duration? duration,
  }) async {
    try {
      final queryParams = <String, String>{
        'track_name': title.trim(),
        'artist_name': artist.trim(),
      };
      if (album != null &&
          album.trim().isNotEmpty &&
          album != 'Unknown Album') {
        queryParams['album_name'] = album.trim();
      }
      if (duration != null && duration.inSeconds > 0) {
        queryParams['duration'] = duration.inSeconds.toString();
      }

      final uri = Uri.parse(
        '$baseUrl/get',
      ).replace(queryParameters: queryParams);
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final result = LrclibSearchResult.fromJson(data);
        if (result.hasContent) {
          return result;
        }
      } else if (response.statusCode == 404) {
        return null;
      }
    } on SocketException catch (_) {
      // Offline / network unreachable
      return null;
    } on TimeoutException catch (_) {
      return null;
    } catch (e) {
      debugPrint('[LrclibClient] getExactLyrics error: $e');
    }
    return null;
  }

  /// Searches LRCLIB using `/api/search` with track title and artist.
  /// Returns a sorted list of candidate lyrics matching the track.
  Future<List<LrclibSearchResult>> searchLyrics({
    required String title,
    required String artist,
    String? album,
    Duration? duration,
  }) async {
    final List<LrclibSearchResult> results = [];
    try {
      final queryParams = <String, String>{
        'track_name': title.trim(),
        'artist_name': artist.trim(),
      };
      if (album != null &&
          album.trim().isNotEmpty &&
          album != 'Unknown Album') {
        queryParams['album_name'] = album.trim();
      }

      final uri = Uri.parse(
        '$baseUrl/search',
      ).replace(queryParameters: queryParams);
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final result = LrclibSearchResult.fromJson(item);
              if (result.hasContent) {
                results.add(result);
              }
            }
          }
        }
      }

      // If specific search yielded zero results, try broader query search
      if (results.isEmpty) {
        final broadQuery = '${title.trim()} ${artist.trim()}'.trim();
        if (broadQuery.isNotEmpty) {
          final broadUri = Uri.parse(
            '$baseUrl/search',
          ).replace(queryParameters: {'q': broadQuery});
          final broadResponse = await _client
              .get(broadUri, headers: _headers)
              .timeout(_timeout);

          if (broadResponse.statusCode == 200) {
            final dynamic decoded = jsonDecode(broadResponse.body);
            if (decoded is List) {
              for (final item in decoded) {
                if (item is Map<String, dynamic>) {
                  final result = LrclibSearchResult.fromJson(item);
                  if (result.hasContent) {
                    results.add(result);
                  }
                }
              }
            }
          }
        }
      }

      // Sort results by match quality against target track
      results.sort((a, b) {
        final scoreA = a.calculateMatchScore(
          targetTitle: title,
          targetArtist: artist,
          targetDuration: duration,
        );
        final scoreB = b.calculateMatchScore(
          targetTitle: title,
          targetArtist: artist,
          targetDuration: duration,
        );
        return scoreB.compareTo(scoreA);
      });
    } on SocketException catch (_) {
      // Offline / network unreachable
      return [];
    } on TimeoutException catch (_) {
      return [];
    } catch (e) {
      debugPrint('[LrclibClient] searchLyrics error: $e');
    }

    return results;
  }

  void close() {
    _client.close();
  }
}
