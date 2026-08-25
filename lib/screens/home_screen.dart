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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.35)),
            ),
            child: const Text(
              '✦ SUB-SECOND A-B LOOPER',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1DB954),
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Logo & Hero Icon
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954).withOpacity(0.15),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1DB954).withOpacity(0.25),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.all_inclusive_rounded, size: 64, color: Color(0xFF1DB954)),
          ),
          const SizedBox(height: 24),

          // Title & Subtitle
          const Text(
            'Master Any Song With Precision Looping',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Loop guitar riffs, solos, choreography, or vocal phrases directly inside your Spotify app with millisecond accuracy.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.white70,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),

          // Feature Highlights Grid
          _buildFeatureCard(
            icon: Icons.track_changes_rounded,
            title: 'Sub-Second Precision',
            description: 'Set millisecond A & B markers with ±50ms and ±100ms instant nudges.',
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            icon: Icons.sync_lock_rounded,
            title: 'Zero Cumulative Drift',
            description: 'Absolute timeline anchoring stays locked on time over hours of practice.',
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            icon: Icons.headphones_rounded,
            title: 'Official Spotify Sync',
            description: 'Controls native Spotify playback seamlessly on your Phone, PC, or Mac.',
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            icon: Icons.bookmark_added_rounded,
            title: 'Preset Vault',
            description: 'Save, name, and auto-load loops for any song in your repertoire.',
          ),
          const SizedBox(height: 32),

          // Primary Call To Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
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
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 6,
                shadowColor: const Color(0xFF1DB954).withOpacity(0.5),
              ),
              icon: authService.isAuthenticating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                    )
                  : const Icon(Icons.play_circle_fill_rounded, size: 24),
              label: Text(
                authService.isAuthenticating ? 'Connecting...' : 'Login with Spotify',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '100% Free & Open Source • Zero Setup Required',
            style: TextStyle(fontSize: 11.5, color: Colors.white38),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF1DB954), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
