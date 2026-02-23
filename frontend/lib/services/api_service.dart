import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/artist.dart';
import '../models/track.dart';

/// Service layer that communicates with the FastAPI backend.
///
/// For Android emulator, 10.0.2.2 maps to the host machine's localhost.
/// Change [baseUrl] to your machine's LAN IP when testing on a physical device.
class ApiService {
  static const String _defaultBase = 'http://localhost:8000';

  final String baseUrl;
  final http.Client _client;

  ApiService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? _defaultBase,
        _client = client ?? http.Client();

  /// Search YouTube Music for songs matching [query].
  Future<List<Track>> searchTracks(String query, {int limit = 20, String? filterMode}) async {
    final Map<String, dynamic> qParams = {
      'q': query, 
      'limit': '$limit'
    };
    if (filterMode != null) {
      qParams['filter'] = filterMode;
    }
    
    final uri = Uri.parse('$baseUrl/api/v1/search').replace(queryParameters: qParams);

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Search failed (${response.statusCode}): ${response.body}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) {
      final track = Track.fromJson(json);
      // Proxy thumbnail through our backend to avoid CORS / 429 on web
      if (track.thumbnail != null && track.thumbnail!.startsWith('https://lh3.googleusercontent.com')) {
        return Track(
          videoId: track.videoId,
          title: track.title,
          artist: track.artist,
          thumbnail: thumbnailProxyUrl(track.thumbnail!),
          duration: track.duration,
        );
      }
      return track;
    }).toList();
  }

  /// Search YouTube Music for artists matching [query].
  Future<List<Artist>> searchArtists(String query, {int limit = 10, String? filterMode}) async {
    final Map<String, dynamic> qParams = {
      'q': query,
      'limit': '$limit',
    };
    if (filterMode != null) {
      qParams['filter'] = filterMode;
    }

    final uri = Uri.parse('$baseUrl/api/v1/search/artists')
        .replace(queryParameters: qParams);

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Artist search failed (${response.statusCode}): ${response.body}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) {
      final artist = Artist.fromJson(json);
      // Proxy thumbnail
      if (artist.thumbnail != null && artist.thumbnail!.startsWith('https://lh3.googleusercontent.com')) {
        return Artist(
          browseId: artist.browseId,
          name: artist.name,
          thumbnail: thumbnailProxyUrl(artist.thumbnail!),
          subscribers: artist.subscribers,
        );
      }
      return artist;
    }).toList();
  }

  /// Get all songs by an artist from their [browseId].
  Future<Map<String, dynamic>> getArtistDetail(String browseId) async {
    final uri = Uri.parse('$baseUrl/api/v1/artists/$browseId');

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Artist detail failed (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // Parse songs
    final List<dynamic> rawSongs = data['songs'] ?? [];
    final songs = rawSongs.map((json) {
      final track = Track.fromJson(json);
      if (track.thumbnail != null && track.thumbnail!.startsWith('https://lh3.googleusercontent.com')) {
        return Track(
          videoId: track.videoId,
          title: track.title,
          artist: track.artist,
          thumbnail: thumbnailProxyUrl(track.thumbnail!),
          duration: track.duration,
        );
      }
      return track;
    }).toList();

    // Proxy the artist thumbnail too
    String? thumb = data['thumbnail'];
    if (thumb != null && thumb.startsWith('https://lh3.googleusercontent.com')) {
      thumb = thumbnailProxyUrl(thumb);
    }

    return {
      'name': data['name'] ?? '',
      'thumbnail': thumb,
      'description': data['description'],
      'subscribers': data['subscribers'],
      'songs': songs,
    };
  }

  /// Get the direct audio stream URL for a [videoId].
  /// This now points to our backend proxy to securely stream the content and bypass CORS.
  Future<String> getStreamUrl(String videoId) async {
    return '$baseUrl/api/v1/stream/$videoId';
  }

  /// Get the proxy download URL for a [videoId].
  /// Opening this URL will force the browser to securely download the file natively.
  String getDownloadUrl(String videoId) {
    return '$baseUrl/api/v1/download/$videoId';
  }

  /// Convert a Google CDN thumbnail URL into a proxied backend URL.
  String thumbnailProxyUrl(String originalUrl) {
    return '$baseUrl/api/v1/thumbnail?url=${Uri.encodeComponent(originalUrl)}';
  }

  /// Get lyrics for a specific [videoId].
  Future<String?> getLyrics(String videoId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/lyrics/$videoId');
      final response = await _client.get(uri);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['lyrics'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

