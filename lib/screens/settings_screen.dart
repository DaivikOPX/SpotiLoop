import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
  late TextEditingController _clientIdController;
  late int _seekOffsetMs;
  late bool _autoLoop;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _clientIdController = TextEditingController(text: widget.storage.getClientId() ?? '');
    _seekOffsetMs = widget.storage.getSeekOffsetMs();
    _autoLoop = widget.storage.getAutoLoopOnSongChange();
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    super.dispose();
  }

  Future<void> _openSpotifyDashboard() async {
    final uri = Uri.parse('https://developer.spotify.com/dashboard');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _saveAndLogin() async {
    final clientId = _clientIdController.text.trim();
    if (clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Spotify Client ID')),
      );
      return;
    }

    setState(() => _isSaving = true);
    await widget.storage.setClientId(clientId);
    await widget.storage.setSeekOffsetMs(_seekOffsetMs);
    await widget.storage.setAutoLoopOnSongChange(_autoLoop);

    final success = await widget.authService.startLogin(customClientId: clientId);
    setState(() => _isSaving = false);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to open login page. Check your internet connection.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuth = widget.authService.isAuthenticated;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('SpotiLoop Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF181818),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Connection Status Card
          Container(
            padding: const EdgeInsets.all(16),
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
                            : 'Enter Client ID below to connect',
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
          const SizedBox(height: 24),

          // Setup Guide Accordion/Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.help_outline_rounded, color: Color(0xFF1DB954), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Spotify Setup (1-Minute Guide)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '1. Open the Spotify Developer Dashboard.\n'
                  '2. Click "Create app" with any name (e.g. SpotiLoop).\n'
                  '3. In App Settings, add these Redirect URIs:\n'
                  '   • http://127.0.0.1:8888/callback (For Windows)\n'
                  '   • spotiloop://callback (For Android)\n'
                  '4. Copy your Client ID and paste it below.',
                  style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.5),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openSpotifyDashboard,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1DB954),
                    side: const BorderSide(color: Color(0xFF1DB954)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Open Spotify Developer Dashboard'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Client ID Input
          const Text(
            'Spotify Client ID',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _clientIdController,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'e.g. 3a8b4e72c81...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1DB954)),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Latency Calibration Slider
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Seek Anticipation Offset',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      '${_seekOffsetMs > 0 ? "+" : ""}$_seekOffsetMs ms',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1DB954),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Compensates for Bluetooth or network seek delay so the loop turnaround sounds seamless.',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                Slider(
                  value: _seekOffsetMs.toDouble(),
                  min: 0,
                  max: 500,
                  divisions: 20,
                  activeColor: const Color(0xFF1DB954),
                  inactiveColor: Colors.white12,
                  onChanged: (val) {
                    setState(() => _seekOffsetMs = val.toInt());
                    widget.storage.setSeekOffsetMs(_seekOffsetMs);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

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
              'Automatically activate saved A-B loops whenever a recognized song starts playing.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
            value: _autoLoop,
            onChanged: (val) {
              setState(() => _autoLoop = val);
              widget.storage.setAutoLoopOnSongChange(val);
            },
          ),
          const SizedBox(height: 28),

          // Save / Connect Button
          ElevatedButton(
            onPressed: _isSaving ? null : _saveAndLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : Text(
                    isAuth ? 'Save & Reconnect' : 'Connect to Spotify',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
