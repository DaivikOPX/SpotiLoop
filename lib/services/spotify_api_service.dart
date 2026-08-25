import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/spotify_track.dart';
import 'spotify_auth_service.dart';

class SpotifyApiService {
  final SpotifyAuthService _authService;

  SpotifyApiService(this._authService);

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getValidAccessToken();
    if (token == null) {
      throw Exception('Not authenticated with Spotify');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Fetches the currently playing track and playback state from Spotify
  Future<SpotifyTrack?> getPlaybackState() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/player'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['item'] != null) {
          return SpotifyTrack.fromJson(data);
        }
      } else if (response.statusCode == 204) {
        // No active playback
        return null;
      } else if (response.statusCode == 401) {
        // Token expired
        await _authService.getValidAccessToken();
      }
    } catch (e) {
      debugPrint('SpotifyApiService getPlaybackState error: $e');
    }
    return null;
  }

  /// Sends a seek command to Spotify Connect
  Future<bool> seekTo(int positionMs) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('https://api.spotify.com/v1/me/player/seek?position_ms=$positionMs');
      final response = await http.put(url, headers: headers);
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('SpotifyApiService seekTo error: $e');
      return false;
    }
  }

  /// Resume playback
  Future<bool> play() async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('https://api.spotify.com/v1/me/player/play'),
        headers: headers,
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('SpotifyApiService play error: $e');
      return false;
    }
  }

  /// Pause playback
  Future<bool> pause() async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('https://api.spotify.com/v1/me/player/pause'),
        headers: headers,
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('SpotifyApiService pause error: $e');
      return false;
    }
  }

  /// Skip to next track
  Future<bool> next() async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('https://api.spotify.com/v1/me/player/next'),
        headers: headers,
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('SpotifyApiService next error: $e');
      return false;
    }
  }

  /// Skip to previous track
  Future<bool> previous() async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('https://api.spotify.com/v1/me/player/previous'),
        headers: headers,
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('SpotifyApiService previous error: $e');
      return false;
    }
  }

  /// Set playback volume (0 - 100)
  Future<bool> setVolume(int percent) async {
    try {
      final headers = await _getHeaders();
      final clamped = percent.clamp(0, 100);
      final response = await http.put(
        Uri.parse('https://api.spotify.com/v1/me/player/volume?volume_percent=$clamped'),
        headers: headers,
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('SpotifyApiService setVolume error: $e');
      return false;
    }
  }
}
