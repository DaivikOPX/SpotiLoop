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

  factory SpotifyTrack.fromJson(Map<String, dynamic> json, {int oneWayLatencyMs = 0}) {
    final item = json['item'] as Map<String, dynamic>? ?? {};
    final device = json['device'] as Map<String, dynamic>?;

    final artistsList = item['artists'] as List<dynamic>? ?? [];
    final artistsString = artistsList.map((a) => a['name'] as String? ?? '').where((n) => n.isNotEmpty).join(', ');

    final albumObj = item['album'] as Map<String, dynamic>? ?? {};
    final images = albumObj['images'] as List<dynamic>? ?? [];
    final albumArt = images.isNotEmpty ? (images[0]['url'] as String? ?? '') : '';

    final rawProgress = json['progress_ms'] as int? ?? 0;
    final isPlaying = json['is_playing'] as bool? ?? false;
    final duration = item['duration_ms'] as int? ?? 0;

    // Compensate for exact HTTP network transit delay measured on local clock
    final compensated = isPlaying ? (rawProgress + oneWayLatencyMs) : rawProgress;
    final finalProgress = (duration > 0 && compensated > duration) ? duration : compensated;

    return SpotifyTrack(
      id: item['id'] as String? ?? '',
      title: item['name'] as String? ?? 'Unknown Title',
      artist: artistsString.isNotEmpty ? artistsString : 'Unknown Artist',
      album: albumObj['name'] as String? ?? 'Unknown Album',
      albumArtUrl: albumArt,
      durationMs: duration,
      progressMs: finalProgress,
      isPlaying: isPlaying,
      deviceName: device?['name'] as String?,
      deviceType: device?['type'] as String?,
      fetchedAt: DateTime.now(),
    );
  }

  int get estimatedProgressMs {
    if (!isPlaying) return progressMs;
    final elapsed = DateTime.now().difference(fetchedAt).inMilliseconds;
    final estimated = progressMs + elapsed;
    return (durationMs > 0 && estimated > durationMs) ? durationMs : estimated;
  }
}
