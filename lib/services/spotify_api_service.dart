import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/spotify_track.dart';
import 'spotify_auth_service.dart';

class SpotifyApiService {
  final SpotifyAuthService _authService;

  SpotifyApiService(this._authService);

  SpotifyAuthService get authService => _authService;
  Future<String?> getAccessToken() => _authService.getValidAccessToken();

  /// Finds a non-restricted Spotify Connect device to transfer playback to.
  Future<String?> _firstAvailableDeviceId() async {
    try {
      final headers = await _getHeaders();
      final res = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/player/devices'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final devices = data['devices'] as List<dynamic>? ?? [];
        for (final d in devices) {
          if (d is Map<String, dynamic> && d['is_restricted'] != true) {
            return d['id'] as String?;
          }
        }
      }
    } catch (e) {
      debugPrint('Device listing error: $e');
    }
    return null;
  }

  /// Transfers playback to a device. Returns true on success.
  Future<bool> _transferPlayback(String deviceId) async {
    try {
      final headers = await _getHeaders();
      final res = await http.post(
        Uri.parse('https://api.spotify.com/v1/me/player'),
        headers: headers,
        body: jsonEncode({'device_ids': [deviceId]}),
      );
      return res.statusCode == 204 || res.statusCode == 200;
    } catch (e) {
      debugPrint('Playback transfer error: $e');
      return false;
    }
  }

  Future<Map<String, String>> _getHeaders({bool forceRefresh = false}) async {
    final token = await _authService.getValidAccessToken(forceRefresh: forceRefresh);
    if (token == null) {
      throw Exception('Not authenticated with Spotify');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Fetches the currently playing track with local round-trip transit latency calibration
  Future<SpotifyTrack?> getPlaybackState() async {
    try {
      var headers = await _getHeaders();
      final startTime = DateTime.now();
      var response = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/player'),
        headers: headers,
      );
      final endTime = DateTime.now();

      if (response.statusCode == 401) {
        headers = await _getHeaders(forceRefresh: true);
        final retryStart = DateTime.now();
        response = await http.get(
          Uri.parse('https://api.spotify.com/v1/me/player'),
          headers: headers,
        );
        final retryEnd = DateTime.now();
        final roundTrip = retryEnd.difference(retryStart).inMilliseconds;
        final oneWayLatency = (roundTrip ~/ 2).clamp(0, 800);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['item'] != null) {
            return SpotifyTrack.fromJson(data, oneWayLatencyMs: oneWayLatency);
          }
        }
        return null;
      }

      final roundTrip = endTime.difference(startTime).inMilliseconds;
      final oneWayLatency = (roundTrip ~/ 2).clamp(0, 800);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['item'] != null) {
          return SpotifyTrack.fromJson(data, oneWayLatencyMs: oneWayLatency);
        }
      } else if (response.statusCode == 204) {
        // No active playback
        return null;
      }
    } catch (e) {
      debugPrint('SpotifyApiService getPlaybackState error: $e');
    }
    return null;
  }

  /// Sends a seek command to Spotify Connect. Falls back to an available
  /// device when Spotify reports no active player (404).
  Future<bool> seekTo(int positionMs) async {
    try {
      var headers = await _getHeaders();
      final url = Uri.parse('https://api.spotify.com/v1/me/player/seek?position_ms=$positionMs');
      var response = await http.put(url, headers: headers);

      if (response.statusCode == 401) {
        headers = await _getHeaders(forceRefresh: true);
        response = await http.put(url, headers: headers);
      }

      if (response.statusCode == 404) {
        final deviceId = await _firstAvailableDeviceId();
        if (deviceId != null) {
          await _transferPlayback(deviceId);
          response = await http.put(
            Uri.parse('https://api.spotify.com/v1/me/player/seek?position_ms=$positionMs&device_id=$deviceId'),
            headers: headers,
          );
        }
      }

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('SpotifyApiService seekTo error: $e');
      return false;
    }
  }

  /// Resume playback. When no device is active (404), transfers playback to an
  /// available Spotify Connect device first so the play button always works.
  Future<bool> play() async {
    try {
      var headers = await _getHeaders();
      final url = Uri.parse('https://api.spotify.com/v1/me/player/play');
      var response = await http.put(url, headers: headers);

      if (response.statusCode == 401) {
        headers = await _getHeaders(forceRefresh: true);
        response = await http.put(url, headers: headers);
      }

      if (response.statusCode == 404) {
        final deviceId = await _firstAvailableDeviceId();
        if (deviceId != null) {
          await _transferPlayback(deviceId);
          response = await http.put(
            Uri.parse('https://api.spotify.com/v1/me/player/play?device_id=$deviceId'),
            headers: headers,
          );
        }
      }

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('SpotifyApiService play error: $e');
      return false;
    }
  }

  /// Pause playback
  Future<bool> pause() async {
    try {
      var headers = await _getHeaders();
      final url = Uri.parse('https://api.spotify.com/v1/me/player/pause');
      var response = await http.put(url, headers: headers);

      if (response.statusCode == 401) {
        headers = await _getHeaders(forceRefresh: true);
        response = await http.put(url, headers: headers);
      }

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('SpotifyApiService pause error: $e');
      return false;
    }
  }

  /// Skip to next track
  Future<bool> next() async {
    try {
      var headers = await _getHeaders();
      final url = Uri.parse('https://api.spotify.com/v1/me/player/next');
      var response = await http.post(url, headers: headers);

      if (response.statusCode == 401) {
        headers = await _getHeaders(forceRefresh: true);
        response = await http.post(url, headers: headers);
      }

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('SpotifyApiService next error: $e');
      return false;
    }
  }

  /// Skip to previous track
  Future<bool> previous() async {
    try {
      var headers = await _getHeaders();
      final url = Uri.parse('https://api.spotify.com/v1/me/player/previous');
      var response = await http.post(url, headers: headers);

      if (response.statusCode == 401) {
        headers = await _getHeaders(forceRefresh: true);
        response = await http.post(url, headers: headers);
      }

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('SpotifyApiService previous error: $e');
      return false;
    }
  }

  /// Set playback volume (0 - 100)
  Future<bool> setVolume(int percent) async {
    try {
      var headers = await _getHeaders();
      final clamped = percent.clamp(0, 100);
      final url = Uri.parse('https://api.spotify.com/v1/me/player/volume?volume_percent=$clamped');
      var response = await http.put(url, headers: headers);

      if (response.statusCode == 401) {
        headers = await _getHeaders(forceRefresh: true);
        response = await http.put(url, headers: headers);
      }

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('SpotifyApiService setVolume error: $e');
      return false;
    }
  }
}
