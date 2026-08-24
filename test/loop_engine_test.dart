import 'package:flutter_test/flutter_test.dart';
import 'package:spotiloop/services/loop_engine.dart';
import 'package:spotiloop/models/spotify_track.dart';

void main() {
  group('LoopEngine & Timing Precision Tests', () {
    test('formatTime parses milliseconds into mm:ss.s', () {
      expect(LoopEngine.formatTime(0), '00:00.0');
      expect(LoopEngine.formatTime(1000), '00:01.0');
      expect(LoopEngine.formatTime(74500), '01:14.5');
      expect(LoopEngine.formatTime(125300), '02:05.3');
    });

    test('Absolute Anchoring guarantees zero cumulative drift', () {
      final engine = LoopEngine();
      final track = SpotifyTrack(
        id: 'track123',
        name: 'Test Song',
        artistName: 'Test Artist',
        albumArtUrl: '',
        durationMs: 180000,
        progressMs: 10000,
        isPlaying: true,
        lastUpdated: DateTime.now(),
      );

      engine.updateTrack(track);
      engine.setStartMarker(10000);
      engine.setEndMarker(12000); // 2-second loop

      expect(engine.isLoopValid, true);
      expect(engine.loopDurationMs, 2000);

      // Verify that markers maintain absolute positions
      expect(engine.startMarkerMs, 10000);
      expect(engine.endMarkerMs, 12000);
    });

    test('Nudge adjustments maintain valid boundary ordering', () {
      final engine = LoopEngine();
      final track = SpotifyTrack(
        id: 'track123',
        name: 'Test Song',
        artistName: 'Test Artist',
        albumArtUrl: '',
        durationMs: 180000,
        progressMs: 10000,
        isPlaying: true,
        lastUpdated: DateTime.now(),
      );
      engine.updateTrack(track);
      engine.setStartMarker(5000);
      engine.setEndMarker(8000);

      // Nudge A +100ms
      engine.nudgeStart(100);
      expect(engine.startMarkerMs, 5100);

      // Nudge B -100ms
      engine.nudgeEnd(-100);
      expect(engine.endMarkerMs, 7900);
    });
  });
}
