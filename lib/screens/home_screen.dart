import 'package:flutter/material.dart';
import '../services/loop_engine.dart';
import '../services/spotify_auth_service.dart';
import '../services/storage_service.dart';
import '../widgets/track_header.dart';
import '../widgets/loop_range_slider.dart';
import '../widgets/marker_controls.dart';
import '../widgets/preset_list_sheet.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  final LoopEngine engine;
  final SpotifyAuthService authService;
  final StorageService storage;

  const HomeScreen({
    super.key,
    required this.engine,
    required this.authService,
    required this.storage,
  });

  void _openPresets(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PresetListSheet(engine: engine, storage: storage),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(authService: authService, storage: storage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final isAuth = authService.isAuthenticated;

        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            backgroundColor: const Color(0xFF181818),
            elevation: 0,
            title: Row(
              children: const [
                Icon(Icons.all_inclusive_rounded, color: Color(0xFF1DB954), size: 26),
                SizedBox(width: 10),
                Text(
                  'SpotiLoop',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.bookmark_rounded, color: Colors.white70),
                tooltip: 'Saved Presets',
                onPressed: () => _openPresets(context),
              ),
              IconButton(
                icon: const Icon(Icons.settings_rounded, color: Colors.white70),
                tooltip: 'Settings',
                onPressed: () => _openSettings(context),
              ),
            ],
          ),
          body: !isAuth
              ? _buildConnectPrompt(context)
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Now Playing Track Header
                        TrackHeader(
                          track: engine.currentTrack,
                          onRefresh: () => engine.syncWithSpotify(),
                        ),
                        const SizedBox(height: 16),

                        // Visual Loop Timeline Scrubber
                        LoopRangeSlider(engine: engine),
                        const SizedBox(height: 16),

                        // Marker Controls (Set A, Set B, Nudge, Jump)
                        MarkerControls(engine: engine),
                        const SizedBox(height: 16),

                        // Master Loop Toggle Card
                        _buildLoopToggleCard(),
                        const SizedBox(height: 16),

                        // Spotify Playback Transport Controls
                        _buildPlaybackControls(),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildLoopToggleCard() {
    final isActive = engine.isLoopActive;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1DB954).withOpacity(0.15) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? const Color(0xFF1DB954) : Colors.white10,
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF1DB954).withOpacity(0.2),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF1DB954) : const Color(0xFF282828),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.repeat_on_rounded,
              color: isActive ? Colors.black : Colors.white60,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive ? 'A-B Looping Active' : 'A-B Looping Paused',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isActive ? const Color(0xFF1DB954) : Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isActive
                      ? 'Looped ${engine.loopCount} ${engine.loopCount == 1 ? "time" : "times"} continuous'
                      : 'Tap switch to start continuous loop',
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ],
            ),
          ),
          Switch(
            value: isActive,
            activeColor: const Color(0xFF1DB954),
            activeTrackColor: const Color(0xFF1DB954).withOpacity(0.4),
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: const Color(0xFF282828),
            onChanged: (_) => engine.toggleLoop(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls() {
    final isPlaying = engine.isPlaying;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded, size: 30, color: Colors.white),
            tooltip: 'Previous Track',
            onPressed: () => engine.previous(),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 32,
                color: Colors.black,
              ),
              tooltip: isPlaying ? 'Pause Spotify' : 'Play Spotify',
              onPressed: () => engine.togglePlayPause(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next_rounded, size: 30, color: Colors.white),
            tooltip: 'Next Track',
            onPressed: () => engine.next(),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectPrompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1DB954).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.all_inclusive_rounded, size: 72, color: Color(0xFF1DB954)),
            ),
            const SizedBox(height: 28),
            const Text(
              'SpotiLoop',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
            ),
            const SizedBox(height: 10),
            const Text(
              'Precision A-B Looping for Spotify',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.white70),
            ),
            const SizedBox(height: 36),
            ElevatedButton.icon(
              onPressed: authService.isAuthenticating
                  ? null
                  : () async {
                      final ok = await authService.startLogin();
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to open Spotify login. Please check connection.')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 4,
              ),
              icon: authService.isAuthenticating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.play_circle_fill_rounded, size: 22),
              label: Text(
                authService.isAuthenticating ? 'Connecting...' : 'Login with Spotify',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
