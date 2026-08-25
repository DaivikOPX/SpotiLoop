import 'package:flutter/material.dart';
import '../services/loop_engine.dart';
import '../services/spotify_auth_service.dart';
import '../services/storage_service.dart';
import '../widgets/track_header.dart';
import '../widgets/loop_range_slider.dart';
import '../widgets/marker_controls.dart';

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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final isAuth = authService.isAuthenticated;

        return Scaffold(
          backgroundColor: const Color(0xFF070709),
          appBar: AppBar(
            backgroundColor: const Color(0xFF070709),
            elevation: 0,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.all_inclusive_rounded,
                      color: Color(0xFF1DB954),
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Spoti Loop',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.white),
                ),
              ],
            ),
          ),
          body: !isAuth
              ? _buildConnectPrompt(context)
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Now Playing Track Header
                        TrackHeader(
                          track: engine.currentTrack,
                          onRefresh: () => engine.syncWithSpotify(),
                        ),
                        const SizedBox(height: 14),

                        // Visual Loop Timeline Scrubber
                        LoopRangeSlider(engine: engine),
                        const SizedBox(height: 14),

                        // Marker Controls (Set A, Set B, Nudge, Jump)
                        MarkerControls(engine: engine),
                        const SizedBox(height: 14),

                        // Master Loop Toggle Card
                        _buildLoopToggleCard(),
                        const SizedBox(height: 14),

                        // Clean Centered Playback Transport Controls
                        _buildPlaybackControls(context),
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
        color: isActive ? const Color(0xFF1DB954).withOpacity(0.12) : const Color(0xFF15151C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? const Color(0xFF1DB954).withOpacity(0.45) : Colors.white10,
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF1DB954).withOpacity(0.2),
                  blurRadius: 16,
                  spreadRadius: 1,
                )
              ]
            : [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF1DB954) : const Color(0xFF22222C),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.repeat_on_rounded,
              color: isActive ? Colors.black : Colors.white60,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive ? 'A-B Looper Active' : 'A-B Looper Paused',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: isActive ? const Color(0xFF1DB954) : Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isActive
                      ? 'Looping: ${LoopEngine.formatTime(engine.startMarkerMs ?? 0)} ➔ ${LoopEngine.formatTime(engine.endMarkerMs ?? 0)} (${engine.loopCount}x)'
                      : 'Tap to start looping between Point A and Point B',
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
            inactiveTrackColor: const Color(0xFF252530),
            onChanged: (_) => engine.toggleLoop(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls(BuildContext context) {
    final isPlaying = engine.isPlaying;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF15151C),
        borderRadius: BorderRadius.circular(20),
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
            width: 52,
            height: 52,
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
              tooltip: isPlaying ? 'Pause' : 'Play',
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Hero Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.35)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '✦ ',
                  style: TextStyle(color: Color(0xFF1DB954), fontWeight: FontWeight.bold),
                ),
                Text(
                  'Precision Spotify Audio Looper',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1DB954),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Title
          const Text(
            'Loop Every Riff, Beat & Solo with Millisecond Precision',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.6,
              height: 1.22,
            ),
          ),
          const SizedBox(height: 10),

          // Description
          const Text(
            'Seamlessly set custom A-B repeat zones with sub-second accuracy, zero drift, and instant Spotify Connect sync. Perfect for guitarists, dancers, transcribers, and music practice.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.white70,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),

          // Primary Launch Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: authService.isAuthenticating
                  ? null
                  : () async {
                      final ok = await authService.startLogin();
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to open Spotify authorization. Please check connection.')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 6,
                shadowColor: const Color(0xFF1DB954).withOpacity(0.4),
              ),
              icon: authService.isAuthenticating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                    )
                  : const Icon(Icons.play_circle_fill_rounded, size: 22),
              label: Text(
                authService.isAuthenticating ? 'Authorizing...' : 'Authorize with Spotify',
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // 2x2 Bento Features (Matching Landing Page Exactly)
          Row(
            children: [
              Expanded(
                child: _buildBentoCard(
                  icon: '🎯',
                  title: 'Sub-Second Nudges',
                  desc: '±50ms & ±100ms micro-steps for exact beats.',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBentoCard(
                  icon: '⚡',
                  title: 'Zero Drift',
                  desc: 'Absolute timeline anchoring stays on beat.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildBentoCard(
                  icon: '🎛️',
                  title: 'Live Scrubbing',
                  desc: 'Smooth dragging along timeline & quick seeks.',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBentoCard(
                  icon: '🎧',
                  title: 'Spotify Connect',
                  desc: 'Seamless sync across Phone, PC, Mac or TV.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBentoCard({
    required String icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF15151C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white60,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
