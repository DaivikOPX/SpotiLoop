import 'package:flutter/material.dart';
import '../services/loop_engine.dart';
import '../services/spotify_auth_service.dart';
import '../services/storage_service.dart';
import '../services/foreground_task_service.dart';
import '../ui_theme.dart';
import '../widgets/track_header.dart';
import '../widgets/loop_range_slider.dart';
import '../widgets/marker_controls.dart';
import '../widgets/preset_list_sheet.dart';

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
          backgroundColor: SpotiTheme.bg,
          appBar: AppBar(
            backgroundColor: SpotiTheme.bg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            titleSpacing: 16,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 30,
                    height: 30,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: SpotiTheme.surface2,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: SpotiTheme.stroke),
                      ),
                      child: const Icon(
                        Icons.all_inclusive_rounded,
                        color: SpotiTheme.green,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                const Text(
                  'Spoti Loop',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17.5,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            actions: [
              if (isAuth) ...[
                IconButton(
                  icon: const Icon(Icons.bookmark_rounded,
                      color: SpotiTheme.green, size: 21),
                  tooltip: 'Saved Loop Presets',
                  onPressed: () => _openPresets(context),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded,
                      color: SpotiTheme.muted, size: 21),
                  tooltip: 'Disconnect Spotify',
                  onPressed: () async {
                    await authService.logout();
                    engine.resetMarkers();
                  },
                ),
              ],
            ],
          ),
          body: !isAuth
              ? _buildConnectPrompt(context)
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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

                        // 4. Master Loop Switch Card
                        _buildLoopToggleCard(),
                        const SizedBox(height: 12),

                        // 5. Floating Transport Console
                        _buildPlaybackControls(),
                        const SizedBox(height: 14),

                        // 6. Saved Loop Presets entry card
                        _buildPresetsEntryCard(context),
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
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x14FFB74D),
              borderRadius: BorderRadius.circular(SpotiTheme.insetRadius),
              border: Border.all(color: const Color(0x4DFFB74D)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded,
                    color: Color(0xFFFFB74D), size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enable background execution',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFFB74D),
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Keeps looping running when the screen is off',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0x99FFB74D),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    await ForegroundTaskService
                        .requestIgnoreBatteryOptimization();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0x24FFB74D),
                    foregroundColor: const Color(0xFFFFB74D),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                  child: const Text(
                    'Allow →',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0x1A1ED760), SpotiTheme.surface1],
                stops: [0.0, 0.65],
              )
            : null,
        color: isActive ? null : SpotiTheme.surface1,
        borderRadius: BorderRadius.circular(SpotiTheme.cardRadius),
        border: Border.all(
          color: isActive ? const Color(0x661ED760) : SpotiTheme.stroke,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? const Color(0x221ED760)
                : Colors.black.withOpacity(0.45),
            blurRadius: isActive ? 22 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isActive ? SpotiTheme.green : SpotiTheme.surface3,
              shape: BoxShape.circle,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                          color: SpotiTheme.green.withOpacity(0.4),
                          blurRadius: 14)
                    ]
                  : null,
            ),
            child: Icon(
              Icons.repeat_rounded,
              color: isActive ? SpotiTheme.onGreen : SpotiTheme.muted,
              size: 19,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: isActive ? SpotiTheme.green : Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isActive
                      ? '${LoopEngine.formatTime(engine.startMarkerMs ?? 0)} → ${LoopEngine.formatTime(engine.endMarkerMs ?? 0)} · ${engine.loopCount} loops · running in background'
                      : 'Toggle to loop continuously between A and B',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: isActive ? SpotiTheme.muted : SpotiTheme.faint),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(
            value: isActive,
            activeColor: SpotiTheme.onGreen,
            activeTrackColor: SpotiTheme.green,
            inactiveThumbColor: SpotiTheme.muted,
            inactiveTrackColor: SpotiTheme.surface3,
            onChanged: (_) => engine.toggleLoop(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Container(
      decoration: BoxDecoration(
        color: SpotiTheme.surface1,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SpotiTheme.stroke),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded,
                color: Color(0xFFE8ECF2), size: 30),
            onPressed: () => engine.previous(),
            tooltip: 'Previous Track',
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: SpotiTheme.green
                      .withOpacity(engine.isPlaying ? 0.35 : 0.0),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                engine.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: SpotiTheme.bg,
                size: 30,
              ),
              onPressed: () => engine.togglePlayPause(),
              tooltip: engine.isPlaying ? 'Pause' : 'Play',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next_rounded,
                color: Color(0xFFE8ECF2), size: 30),
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
            // 1. Hero identity
            Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: SpotiTheme.greenTint,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x331ED760)),
                    boxShadow: [
                      BoxShadow(
                        color: SpotiTheme.green.withOpacity(0.22),
                        blurRadius: 40,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.all_inclusive_rounded,
                    size: 44,
                    color: SpotiTheme.green,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                  decoration: BoxDecoration(
                    color: SpotiTheme.greenTint,
                    border: Border.all(color: SpotiTheme.greenStroke),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'PRECISION AUDIO LOOPER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: SpotiTheme.green,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Master Any Song With\nSub-Second Looping',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                    height: 1.15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Loop guitar solos, drum fills, vocal runs, and dance cues with millisecond accuracy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: SpotiTheme.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),

            // 2. Feature chips (2x2)
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

            // 3. Authorize action
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => authService.startLogin(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SpotiTheme.green,
                      foregroundColor: SpotiTheme.onGreen,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      overlayColor: Colors.white.withOpacity(0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    icon: const Icon(Icons.login_rounded, size: 19),
                    label: const Text(
                      'Authorize with Spotify',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (authService.authError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0x14FF5252),
                      borderRadius:
                          BorderRadius.circular(SpotiTheme.insetRadius),
                      border: Border.all(color: const Color(0x66FF5252)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: SpotiTheme.pointB, size: 17),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            authService.authError!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFF8A80),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (authService.isAuthenticating) ...[
                  const LinearProgressIndicator(
                    color: SpotiTheme.green,
                    backgroundColor: SpotiTheme.surface2,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                  const SizedBox(height: 10),
                ],
                const Text(
                  'Secured with Spotify OAuth 2.0 PKCE · No credentials stored',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10,
                      color: SpotiTheme.faint,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPresets(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0C0F15),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PresetListSheet(engine: engine),
        ),
      ),
    );
  }

  Widget _buildPresetsEntryCard(BuildContext context) {
    final sortLabel = switch (engine.presetSortMode) {
      'recency' => 'recently saved',
      'nameAsc' => 'A → Z',
      'nameDesc' => 'Z → A',
      'trackAsc' => 'track name',
      'manual' => 'custom order',
      _ => '',
    };

    return GestureDetector(
      onTap: () => _openPresets(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [SpotiTheme.greenTint, SpotiTheme.surface1],
            stops: const [0.0, 0.62],
          ),
          borderRadius: BorderRadius.circular(SpotiTheme.cardRadius),
          border: Border.all(color: SpotiTheme.greenStroke),
          boxShadow: [
            BoxShadow(
              color: SpotiTheme.green.withOpacity(0.14),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: SpotiTheme.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bookmark_rounded,
                color: SpotiTheme.onGreen,
                size: 17,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saved Loop Presets',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${engine.presets.length} saved · $sortLabel',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: SpotiTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: SpotiTheme.faint,
              size: 22,
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
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: SpotiTheme.surface1,
        borderRadius: BorderRadius.circular(SpotiTheme.insetRadius + 2),
        border: Border.all(color: SpotiTheme.stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: SpotiTheme.greenTint,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0x331ED760)),
            ),
            child: Icon(icon, size: 14, color: SpotiTheme.green),
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
                    letterSpacing: -0.2,
                    color: Colors.white,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: SpotiTheme.muted,
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
