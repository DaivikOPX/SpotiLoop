class SpotifyTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String albumArtUrl;
  final int durationMs;
  final int progressMs;
  final bool isPlaying;
  final String? deviceName;
  final String? deviceType;
  final DateTime fetchedAt;

  SpotifyTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArtUrl,
    required this.durationMs,
    required this.progressMs,
    required this.isPlaying,
    this.deviceName,
    this.deviceType,
    required this.fetchedAt,
  });

  factory SpotifyTrack.fromJson(Map<String, dynamic> json) {
    final item = json['item'] as Map<String, dynamic>? ?? {};
    final device = json['device'] as Map<String, dynamic>?;

    final artistsList = item['artists'] as List<dynamic>? ?? [];
    final artistsString = artistsList.map((a) => a['name'] as String? ?? '').where((n) => n.isNotEmpty).join(', ');

    final albumObj = item['album'] as Map<String, dynamic>? ?? {};
    final images = albumObj['images'] as List<dynamic>? ?? [];
    final albumArt = images.isNotEmpty ? (images[0]['url'] as String? ?? '') : '';

    final rawProgress = json['progress_ms'] as int? ?? 0;
    final serverTimestamp = json['timestamp'] as int?;
    final isPlaying = json['is_playing'] as bool? ?? false;

    // Compensate for network transit latency if server timestamp is present
    int compensatedProgress = rawProgress;
    if (serverTimestamp != null && isPlaying) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final networkLatency = nowMs - serverTimestamp;
      if (networkLatency > 0 && networkLatency < 4000) {
        compensatedProgress = rawProgress + networkLatency;
      }
    }

    final duration = item['duration_ms'] as int? ?? 0;

    return SpotifyTrack(
      id: item['id'] as String? ?? '',
      title: item['name'] as String? ?? 'Unknown Title',
      artist: artistsString.isNotEmpty ? artistsString : 'Unknown Artist',
      album: albumObj['name'] as String? ?? 'Unknown Album',
      albumArtUrl: albumArt,
      durationMs: duration,
      progressMs: (duration > 0 && compensatedProgress > duration) ? duration : compensatedProgress,
      isPlaying: isPlaying,
      deviceName: device?['name'] as String?,
      deviceType: device?['type'] as String?,
      fetchedAt: DateTime.now(),
    );
  }

  /// Calculates real-time estimated progress based on time elapsed since fetch
  int get estimatedProgressMs {
    if (!isPlaying) return progressMs;
    final elapsed = DateTime.now().difference(fetchedAt).inMilliseconds;
    final estimated = progressMs + elapsed;
    return estimated > durationMs ? durationMs : estimated;
  }
}
