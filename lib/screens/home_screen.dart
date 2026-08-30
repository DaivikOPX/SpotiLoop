import 'package:flutter/material.dart';
import '../services/loop_engine.dart';
import '../services/spotify_auth_service.dart';
import '../services/storage_service.dart';
import '../services/foreground_task_service.dart';
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
                        // Background Battery Optimization Notice (if not yet granted on Android)
                        _buildBatteryOptimizationBanner(),

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

  Widget _buildBatteryOptimizationBanner() {
    return FutureBuilder<bool>(
      future: ForegroundTaskService.isBatteryOptimizationIgnored(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data == false) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1B150F),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF5A3E1B)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: Color(0xFFFFB74D), size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enable Background Execution',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFFB74D),
                        ),
                      ),
                      Text(
                        'Allows uninterrupted looping when screen is locked',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    await ForegroundTaskService.requestIgnoreBatteryOptimization();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB74D).withOpacity(0.18),
                    foregroundColor: const Color(0xFFFFB74D),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Allow ➔',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
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
                Text(
                  isActive
                      ? 'Looping: ${LoopEngine.formatTime(engine.startMarkerMs ?? 0)} ➔ ${LoopEngine.formatTime(engine.endMarkerMs ?? 0)} (${engine.loopCount}x) • Background active'
                      : 'Tap switch to start continuous A-B loop playback',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isActive,
            activeColor: const Color(0xFF1DB954),
            activeTrackColor: const Color(0xFF1DB954).withOpacity(0.4),
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white12,
            onChanged: (_) => engine.toggleLoop(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF14151E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF232532)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 30),
            onPressed: () => engine.previous(),
            tooltip: 'Previous Track',
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                engine.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.black,
                size: 32,
              ),
              onPressed: () => engine.togglePlayPause(),
              tooltip: engine.isPlaying ? 'Pause' : 'Play',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 30),
            onPressed: () => engine.next(),
            tooltip: 'Next Track',
          ),
        ],
      ),
    );
  }

  Widget _buildConnectPrompt(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 1. Top Brand Icon & Hero Pill Badge
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withOpacity(0.12),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1DB954).withOpacity(0.25),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.all_inclusive_rounded,
                    size: 48,
                    color: Color(0xFF1DB954),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1DB954),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'PRECISION AUDIO LOOPER',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Color(0xFF1DB954),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Master Any Song With\nSub-Second Looping',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    height: 1.2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Loop guitar solos, drum fills, vocal runs, and dance cues with millisecond accuracy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white60,
                    height: 1.35,
                  ),
                ),
              ],
            ),

            // 2. Bento Grid 4 Feature Chips (2x2 Matrix)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildBentoFeature(
                        icon: Icons.tune_rounded,
                        title: 'Sub-Second',
                        desc: '±0.1s & ±1.0s nudges',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildBentoFeature(
                        icon: Icons.bolt_rounded,
                        title: 'Zero Drift',
                        desc: 'Locked local clock',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildBentoFeature(
                        icon: Icons.screen_lock_portrait_rounded,
                        title: 'Screen-Off',
                        desc: 'Runs in background',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildBentoFeature(
                        icon: Icons.devices_rounded,
                        title: 'All Devices',
                        desc: 'Spotify Connect sync',
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // 3. Prominent Authorize Action Button
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => authService.startLogin(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.black,
                      elevation: 8,
                      shadowColor: const Color(0xFF1DB954).withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    icon: const Icon(Icons.login_rounded, size: 20),
                    label: const Text(
                      'Authorize with Spotify',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Secured with Spotify OAuth 2.0 PKCE • No login credentials stored',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white38,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoFeature({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF14151E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF232532)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF1DB954)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Colors.white54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
