import 'package:flutter/material.dart';
import '../models/spotify_track.dart';
import '../ui_theme.dart';

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
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: SpotiTheme.surface1,
          borderRadius: BorderRadius.circular(SpotiTheme.cardRadius),
          border: Border.all(color: SpotiTheme.stroke),
        ),
        child: Column(
          children: [
            const Icon(Icons.music_note_rounded,
                size: 34, color: SpotiTheme.faint),
            const SizedBox(height: 10),
            const Text(
              'Waiting for Spotify playback',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Play any song in your Spotify app, then sync',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: SpotiTheme.muted),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRefresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: SpotiTheme.green,
                foregroundColor: SpotiTheme.onGreen,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                overlayColor: Colors.white.withOpacity(0.08),
              ),
              icon: const Icon(Icons.sync_rounded, size: 17),
              label: const Text(
                'Sync Spotify',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ),
          ],
        ),
      );
    }

    final isPlaying = track!.isPlaying;
    final deviceColor = isPlaying ? SpotiTheme.green : SpotiTheme.muted;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: SpotiTheme.surface1,
        borderRadius: BorderRadius.circular(SpotiTheme.cardRadius),
        border: Border.all(color: SpotiTheme.stroke),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          // Album Art
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: track!.albumArtUrl.isNotEmpty
                ? Image.network(
                    track!.albumArtUrl,
                    width: 64,
                    height: 64,
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
                    letterSpacing: -0.3,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  track!.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: SpotiTheme.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isPlaying
                            ? SpotiTheme.green
                            : const Color(0xFFB7942F),
                        shape: BoxShape.circle,
                        boxShadow: isPlaying
                            ? [
                                BoxShadow(
                                    color: SpotiTheme.green.withOpacity(0.5),
                                    blurRadius: 6)
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        track!.deviceName != null
                            ? '${isPlaying ? "Playing on" : "Paused on"} ${track!.deviceName}'
                            : (isPlaying ? 'Spotify Connect ready' : 'Paused'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: deviceColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Sync button
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: SpotiTheme.surface2,
              shape: BoxShape.circle,
              border: Border.all(color: SpotiTheme.stroke),
            ),
            child: IconButton(
              onPressed: onRefresh,
              tooltip: 'Sync with Spotify',
              icon: const Icon(Icons.sync_rounded,
                  color: SpotiTheme.muted, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 64,
      height: 64,
      color: SpotiTheme.surface3,
      child: const Icon(Icons.music_note_rounded,
          size: 26, color: SpotiTheme.faint),
    );
  }
}
