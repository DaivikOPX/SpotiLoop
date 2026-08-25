import 'package:flutter/material.dart';
import '../services/spotify_auth_service.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  final SpotifyAuthService authService;
  final StorageService storage;

  const SettingsScreen({
    super.key,
    required this.authService,
    required this.storage,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _autoLoop;

  @override
  void initState() {
    super.initState();
    _autoLoop = widget.storage.getAutoLoopOnSongChange();
  }

  @override
  Widget build(BuildContext context) {
    final isAuth = widget.authService.isAuthenticated;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF181818),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Connection Status Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isAuth ? const Color(0xFF1DB954).withOpacity(0.3) : Colors.white10,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isAuth ? const Color(0xFF1DB954).withOpacity(0.2) : Colors.white10,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAuth ? Icons.check_circle_rounded : Icons.account_circle_outlined,
                    color: isAuth ? const Color(0xFF1DB954) : Colors.white60,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAuth ? 'Connected to Spotify' : 'Not Connected',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAuth
                            ? 'Ready to control your Spotify playback'
                            : 'Sign in to start looping',
                        style: const TextStyle(fontSize: 13, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                if (isAuth)
                  TextButton(
                    onPressed: () async {
                      await widget.authService.logout();
                      setState(() {});
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    child: const Text('Disconnect'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (!isAuth) ...[
            ElevatedButton.icon(
              onPressed: () async {
                final ok = await widget.authService.startLogin();
                if (!ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to open Spotify login.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
              label: const Text(
                'Login with Spotify',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Auto Loop Switch
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white10),
            ),
            tileColor: const Color(0xFF1E1E1E),
            activeColor: const Color(0xFF1DB954),
            title: const Text(
              'Auto-load Presets',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
            ),
            subtitle: const Text(
              'Automatically activate saved loops when a recognized song plays.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
            value: _autoLoop,
            onChanged: (val) {
              setState(() => _autoLoop = val);
              widget.storage.setAutoLoopOnSongChange(val);
            },
          ),
          const SizedBox(height: 24),

          // About Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: const [
                Icon(Icons.all_inclusive_rounded, color: Color(0xFF1DB954), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SpotiLoop Pro',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      ),
                      Text(
                        'Version 1.0.0 • Open Source',
                        style: TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
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
