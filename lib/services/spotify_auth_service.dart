import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'storage_service.dart';

class SpotifyAuthService extends ChangeNotifier {
  final StorageService _storage;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  HttpServer? _localServer;

  String? _currentCodeVerifier;
  bool _isAuthenticating = false;

  bool get isAuthenticating => _isAuthenticating;
  bool get isAuthenticated => _storage.getAccessToken() != null;
  String? get clientId => _storage.getClientId();

  SpotifyAuthService(this._storage) {
    _initDeepLinks();
  }

  void _initDeepLinks() {
    // 1. Check for initial link on cold launch
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleIncomingUri(uri);
      }
    }).catchError((e) {
      debugPrint('Error getting initial link: $e');
    });

    // 2. Listen for incoming deep links while app is open / backgrounded
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingUri(uri);
    }, onError: (e) {
      debugPrint('Deep link stream error: $e');
    });
  }

  void _handleIncomingUri(Uri uri) {
    if (uri.scheme == 'spotiloop') {
      final code = uri.queryParameters['code'];
      final error = uri.queryParameters['error'];
      if (code != null && code.isNotEmpty) {
        _handleAuthCode(code);
      } else if (error != null) {
        _isAuthenticating = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _localServer?.close(force: true);
    super.dispose();
  }

  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  String get redirectUri {
    if (kIsWeb) {
      return 'http://localhost:8888/callback';
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return 'http://127.0.0.1:8888/callback';
    } else {
      return 'spotiloop://callback';
    }
  }

  Future<bool> startLogin({String? customClientId}) async {
    final activeClientId = customClientId ?? _storage.getClientId();
    if (activeClientId == null || activeClientId.isEmpty) {
      return false;
    }

    if (customClientId != null) {
      await _storage.setClientId(customClientId);
    }

    _isAuthenticating = true;
    notifyListeners();

    _currentCodeVerifier = _generateRandomString(64);
    await _storage.setCodeVerifier(_currentCodeVerifier!);

    final codeChallenge = _generateCodeChallenge(_currentCodeVerifier!);
    final state = _generateRandomString(16);

    const scopes = 'user-read-playback-state user-modify-playback-state user-read-currently-playing';

    final authUrl = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': activeClientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'code_challenge_method': 'S256',
      'code_challenge': codeChallenge,
      'state': state,
      'scope': scopes,
    });

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      await _startLocalServer();
    }

    final launched = await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    if (!launched) {
      _isAuthenticating = false;
      notifyListeners();
      return false;
    }

    return true;
  }

  Future<void> _startLocalServer() async {
    await _localServer?.close(force: true);
    try {
      _localServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 8888);
      _localServer!.listen((HttpRequest request) async {
        if (request.uri.path == '/callback') {
          final code = request.uri.queryParameters['code'];
          final error = request.uri.queryParameters['error'];

          request.response.headers.contentType = ContentType.html;
          if (code != null) {
            request.response.write('''
              <!DOCTYPE html>
              <html>
                <head>
                  <title>SpotiLoop - Connected!</title>
                  <style>
                    body { font-family: 'Segoe UI', system-ui, sans-serif; background: #121212; color: #fff; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; }
                    .card { background: #181818; padding: 40px; border-radius: 16px; border: 1px solid #282828; text-align: center; max-width: 400px; }
                    h1 { color: #1DB954; font-size: 24px; margin-bottom: 12px; }
                    p { color: #b3b3b3; line-height: 1.5; font-size: 15px; }
                  </style>
                </head>
                <body>
                  <div class="card">
                    <h1>Connected to Spotify!</h1>
                    <p>Authorization successful. You can close this window and return to the SpotiLoop app.</p>
                  </div>
                </body>
              </html>
            ''');
            await request.response.close();
            await _localServer?.close();
            _localServer = null;
            await _handleAuthCode(code);
          } else {
            request.response.write('''
              <!DOCTYPE html>
              <html>
                <head><title>Authorization Failed</title></head>
                <body style="background:#121212;color:#ff5555;padding:40px;font-family:sans-serif;">
                  <h2>Authorization Cancelled / Failed: $error</h2>
                </body>
              </html>
            ''');
            await request.response.close();
            await _localServer?.close();
            _localServer = null;
            _isAuthenticating = false;
            notifyListeners();
          }
        }
      });
    } catch (e) {
      debugPrint('Failed to bind local loopback server: $e');
    }
  }

  Future<void> _handleAuthCode(String code) async {
    final clientId = _storage.getClientId();
    final verifier = _storage.getCodeVerifier() ?? _currentCodeVerifier;
    if (clientId == null || verifier == null) {
      _isAuthenticating = false;
      notifyListeners();
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
          'client_id': clientId,
          'code_verifier': verifier,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String?;
        final expiresIn = data['expires_in'] as int;

        await _storage.setAccessToken(accessToken);
        if (refreshToken != null) {
          await _storage.setRefreshToken(refreshToken);
        }
        await _storage.setTokenExpiry(DateTime.now().add(Duration(seconds: expiresIn - 60)));
      } else {
        debugPrint('Token exchange error: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error exchanging auth code: $e');
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<String?> getValidAccessToken() async {
    final token = _storage.getAccessToken();
    final expiry = _storage.getTokenExpiry();
    final refreshToken = _storage.getRefreshToken();
    final clientId = _storage.getClientId();

    if (token == null) return null;

    if (expiry != null && DateTime.now().isAfter(expiry) && refreshToken != null && clientId != null) {
      // Refresh token
      try {
        final response = await http.post(
          Uri.parse('https://accounts.spotify.com/api/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
            'client_id': clientId,
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final newAccessToken = data['access_token'] as String;
          final newRefreshToken = data['refresh_token'] as String?;
          final expiresIn = data['expires_in'] as int;

          await _storage.setAccessToken(newAccessToken);
          if (newRefreshToken != null) {
            await _storage.setRefreshToken(newRefreshToken);
          }
          await _storage.setTokenExpiry(DateTime.now().add(Duration(seconds: expiresIn - 60)));
          return newAccessToken;
        }
      } catch (e) {
        debugPrint('Token refresh failed: $e');
      }
    }

    return token;
  }

  Future<void> logout() async {
    await _storage.clearAuth();
    notifyListeners();
  }
}
