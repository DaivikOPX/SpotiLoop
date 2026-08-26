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
      listenable: Listenable.merge([engine, authService]),
      builder: (context, _) {
        final isAuth = authService.isAuthenticated;

        return Scaffold(
          backgroundColor: const Color(0xFF090A0F),
          appBar: AppBar(
            backgroundColor: const Color(0xFF090A0F),
            elevation: 0,
            titleSpacing: 16,
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
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: -0.4,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            actions: isAuth
                ? [
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, color: Colors.white60, size: 20),
                      tooltip: 'Disconnect Spotify',
                      onPressed: () async {
                        await authService.logout();
                        engine.resetMarkers();
                      },
                    ),
                  ]
                : [],
          ),
          body: !isAuth
              ? _buildConnectPrompt(context)
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Now Playing Track Card
                        TrackHeader(
                          track: engine.currentTrack,
                          onRefresh: () => engine.syncWithSpotify(),
                        ),
                        const SizedBox(height: 12),

                        // 2. High-Precision Interactive Scrubber Timeline
                        LoopRangeSlider(engine: engine),
                        const SizedBox(height: 12),

                        // 3. Dual Marker Stations (Point A & Point B)
                        MarkerControls(engine: engine),
                        const SizedBox(height: 12),

                        // 4. Master Hardware Loop Switch Card
                        _buildLoopToggleCard(),
                        const SizedBox(height: 12),

                        // 5. Clean Floating Transport Console
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1DB954).withOpacity(0.12) : const Color(0xFF14151E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? const Color(0xFF1DB954).withOpacity(0.5) : const Color(0xFF232532),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive ? const Color(0xFF1DB954).withOpacity(0.2) : Colors.black.withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: isActive ? 1 : 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF1DB954) : const Color(0xFF1F212D),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.repeat_rounded,
              color: isActive ? Colors.black : Colors.white60,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive ? 'A-B Looper Active' : 'A-B Looper Standby',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isActive ? const Color(0xFF00E676) : Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isActive
                      ? 'Looping: ${LoopEngine.formatTime(engine.startMarkerMs ?? 0)} ➔ ${LoopEngine.formatTime(engine.endMarkerMs ?? 0)} (${engine.loopCount}x)'
                      : 'Tap switch to start continuous loop',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isActive ? Colors.white70 : Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isActive,
            activeColor: const Color(0xFF1DB954),
            activeTrackColor: const Color(0xFF1DB954).withOpacity(0.35),
            inactiveThumbColor: Colors.white60,
            inactiveTrackColor: const Color(0xFF222432),
            onChanged: (_) => engine.toggleLoop(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls(BuildContext context) {
    final isPlaying = engine.isPlaying;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF14151E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF232532)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded, size: 28, color: Colors.white),
            tooltip: 'Previous Track',
            onPressed: () => engine.previous(),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.2),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 30,
                color: Colors.black,
              ),
              tooltip: isPlaying ? 'Pause' : 'Play',
              onPressed: () => engine.togglePlayPause(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next_rounded, size: 28, color: Colors.white),
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
          const SizedBox(height: 20),

          // Error Banner if token exchange failed
          if (authService.authError != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFFF5252), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      authService.authError!,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFFFF5252), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Primary Launch Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: authService.isAuthenticating
                  ? null
                  : () async {
                      final ok = await authService.startLogin();
                      if (!ok && context.mounted && authService.authError != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(authService.authError!),
                            backgroundColor: const Color(0xFFFF5252),
                          ),
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
                authService.isAuthenticating ? 'Connecting to Spotify...' : 'Authorize with Spotify',
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
        color: const Color(0xFF14151E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF232532)),
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
