import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/loop_engine.dart';
import 'services/spotify_api_service.dart';
import 'services/spotify_auth_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize persistent storage and services
  final storage = await StorageService.init();
  final authService = SpotifyAuthService(storage);
  final apiService = SpotifyApiService(authService);
  final loopEngine = LoopEngine(apiService, storage);

  runApp(SpotiLoopApp(
    storage: storage,
    authService: authService,
    loopEngine: loopEngine,
  ));
}

class SpotiLoopApp extends StatelessWidget {
  final StorageService storage;
  final SpotifyAuthService authService;
  final LoopEngine loopEngine;

  const SpotiLoopApp({
    super.key,
    required this.storage,
    required this.authService,
    required this.loopEngine,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spoti Loop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF1DB954),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1DB954),
          secondary: Color(0xFF1ED760),
          surface: Color(0xFF1E1E1E),
          background: Color(0xFF121212),
        ),
        fontFamily: 'Segoe UI',
        useMaterial3: true,
      ),
      home: HomeScreen(
        engine: loopEngine,
        authService: authService,
        storage: storage,
      ),
    );
  }
}
