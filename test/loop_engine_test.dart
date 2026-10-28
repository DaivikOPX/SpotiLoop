import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:spotiloop/models/loop_preset.dart';
import 'package:spotiloop/models/spotify_track.dart';
import 'package:spotiloop/services/loop_engine.dart';

void main() {
  group('LoopEngine.formatTime', () {
    test('formats milliseconds into mm:ss.t', () {
      expect(LoopEngine.formatTime(0), '00:00.0');
      expect(LoopEngine.formatTime(1000), '00:01.0');
      expect(LoopEngine.formatTime(74500), '01:14.5');
      expect(LoopEngine.formatTime(125300), '02:05.3');
    });
  });

  group('SpotifyTrack.fromJson', () {
    final payload = jsonDecode('''
      {
        "item": {
          "id": "track123",
          "name": "Test Song",
          "artists": [{"name": "Test Artist"}],
          "album": {"name": "Test Album", "images": [{"url": "http://img"}]},
          "duration_ms": 180000
        },
        "progress_ms": 10000,
        "is_playing": true
      }
    ''') as Map<String, dynamic>;

    test('parses payload fields and compensates one-way latency', () {
      final track = SpotifyTrack.fromJson(payload, oneWayLatencyMs: 100);
      expect(track.id, 'track123');
      expect(track.title, 'Test Song');
      expect(track.artist, 'Test Artist');
      expect(track.albumArtUrl, 'http://img');
      expect(track.durationMs, 180000);
      expect(track.progressMs, 10100); // raw progress + one-way latency
      expect(track.isPlaying, isTrue);
    });

    test('clamps progress at track duration', () {
      final nearEndPayload = jsonDecode('''
        {
          "item": {
            "id": "track123",
            "name": "Test Song",
            "artists": [{"name": "Test Artist"}],
            "album": {"name": "Test Album", "images": [{"url": "http://img"}]},
            "duration_ms": 180000
          },
          "progress_ms": 178000,
          "is_playing": true
        }
      ''') as Map<String, dynamic>;
      final track = SpotifyTrack.fromJson(nearEndPayload, oneWayLatencyMs: 5000);
      expect(track.progressMs, 180000);
    });

    test('estimatedProgressMs advances with local clock and clamps', () {
      final track = SpotifyTrack.fromJson(payload, oneWayLatencyMs: 0);
      final est = track.estimatedProgressMs;
      expect(est >= 10000, isTrue);
      expect(est <= 180000, isTrue);
    });
  });

  group('LoopPreset', () {
    test('encodes and decodes round-trip', () {
      final preset = LoopPreset(
        id: '1',
        trackId: 'track123',
        trackTitle: 'Test Song',
        trackArtist: 'Test Artist',
        name: 'Solo',
        startMs: 10000,
        endMs: 12000,
        createdAt: DateTime.utc(2024, 1, 1),
      );
      final decoded = LoopPreset.decodeList(LoopPreset.encodeList([preset]));
      expect(decoded, hasLength(1));
      expect(decoded.first.id, '1');
      expect(decoded.first.name, 'Solo');
      expect(decoded.first.startMs, 10000);
      expect(decoded.first.endMs, 12000);
    });

    test('decodeList tolerates empty and malformed input', () {
      expect(LoopPreset.decodeList(''), isEmpty);
      expect(LoopPreset.decodeList('not json'), isEmpty);
    });
  });
}
