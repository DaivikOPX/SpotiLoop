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
          color: const Color(0xFF14151E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF232532)),
        ),
        child: Column(
          children: [
            const Icon(Icons.music_off_rounded, size: 40, color: Colors.white38),
            const SizedBox(height: 10),
            const Text(
              'Waiting for Spotify Playback',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 4),
            const Text(
              'Play any song in your Spotify app, then tap sync',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.white54),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onRefresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: const Text('Sync Spotify', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14151E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF232532)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Album Art
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: track!.albumArtUrl.isNotEmpty
                ? Image.network(
                    track!.albumArtUrl,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),
          const SizedBox(width: 14),
          // Track Metadata
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  track!.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9E9EA8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
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
                            : (track!.isPlaying ? 'Spotify Connect Ready' : 'Paused'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: track!.isPlaying ? const Color(0xFF1DB954) : Colors.white60,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Sync Button
          IconButton(
            onPressed: onRefresh,
            tooltip: 'Sync with Spotify',
            icon: const Icon(Icons.sync_rounded, color: Colors.white60, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 58,
      height: 58,
      color: const Color(0xFF1E202B),
      child: const Icon(Icons.music_note_rounded, size: 28, color: Colors.white38),
    );
  }
}
