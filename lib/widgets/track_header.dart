import 'package:flutter/material.dart';
import '../models/spotify_track.dart';

class TrackHeader extends StatelessWidget {
  final SpotifyTrack? track;
  final VoidCallback onRefresh;

  const TrackHeader({
    super.key,
    required this.track,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (track == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            const Icon(Icons.music_off_rounded, size: 48, color: Colors.white38),
            const SizedBox(height: 12),
            const Text(
              'No active Spotify playback',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 6),
            const Text(
              'Play any song in your official Spotify app, then tap sync',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white54),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onRefresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: const Text('Sync Spotify', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Album Art
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: track!.albumArtUrl.isNotEmpty
                ? Image.network(
                    track!.albumArtUrl,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),
          const SizedBox(width: 16),
          // Track Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  track!.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Color(0xFFB3B3B3)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: track!.isPlaying ? const Color(0xFF1DB954) : Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        track!.deviceName != null
                            ? '${track!.isPlaying ? "Playing on" : "Paused on"} ${track!.deviceName}'
                            : (track!.isPlaying ? 'Playing on Spotify' : 'Paused'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: track!.isPlaying ? const Color(0xFF1DB954) : Colors.white60,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            tooltip: 'Sync with Spotify',
            icon: const Icon(Icons.sync_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 72,
      height: 72,
      color: const Color(0xFF282828),
      child: const Icon(Icons.music_note_rounded, size: 36, color: Colors.white38),
    );
  }
}
