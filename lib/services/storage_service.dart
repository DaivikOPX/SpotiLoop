import 'package:shared_preferences/shared_preferences.dart';
import '../models/loop_preset.dart';

class StorageService {
  static const String _keyClientId = 'spotify_client_id';
  static const String _keyAccessToken = 'spotify_access_token';
  static const String _keyRefreshToken = 'spotify_refresh_token';
  static const String _keyTokenExpiry = 'spotify_token_expiry';
  static const String _keyPresets = 'spotify_loop_presets';
  static const String _keySeekOffsetMs = 'loop_seek_offset_ms';
  static const String _keyAutoLoopOnSongChange = 'auto_loop_on_song_change';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // Encrypted Client ID Resolver
  static String _resolveDefaultClientId() {
    const k = [106,60,106,56,104,60,106,110,104,111,110,105,110,109,104,105,99,105,110,111,108,99,109,60,105,99,109,111,107,107,98,99];
    return String.fromCharCodes(k.map((c) => c ^ 0x5a));
  }

  String getClientId() => _prefs.getString(_keyClientId) ?? _resolveDefaultClientId();
  Future<void> setClientId(String clientId) => _prefs.setString(_keyClientId, clientId.trim());

  // Tokens
  String? getAccessToken() => _prefs.getString(_keyAccessToken);
  Future<void> setAccessToken(String token) => _prefs.setString(_keyAccessToken, token);

  String? getRefreshToken() => _prefs.getString(_keyRefreshToken);
  Future<void> setRefreshToken(String token) => _prefs.setString(_keyRefreshToken, token);

  DateTime? getTokenExpiry() {
    final expiryStr = _prefs.getString(_keyTokenExpiry);
    return expiryStr != null ? DateTime.tryParse(expiryStr) : null;
  }

  Future<void> setTokenExpiry(DateTime expiry) =>
      _prefs.setString(_keyTokenExpiry, expiry.toIso8601String());

  Future<void> clearAuth() async {
    await _prefs.remove(_keyAccessToken);
    await _prefs.remove(_keyRefreshToken);
    await _prefs.remove(_keyTokenExpiry);
  }

  // Presets
  List<LoopPreset> getPresets() {
    final jsonStr = _prefs.getString(_keyPresets) ?? '';
    return LoopPreset.decodeList(jsonStr);
  }

  Future<void> savePreset(LoopPreset preset) async {
    final list = getPresets();
    list.removeWhere((p) => p.id == preset.id);
    list.insert(0, preset);
    await _prefs.setString(_keyPresets, LoopPreset.encodeList(list));
  }

  Future<void> deletePreset(String presetId) async {
    final list = getPresets();
    list.removeWhere((p) => p.id == presetId);
    await _prefs.setString(_keyPresets, LoopPreset.encodeList(list));
  }

  // Tuning offset (in ms) to compensate for network latency when sending seek
  int getSeekOffsetMs() => _prefs.getInt(_keySeekOffsetMs) ?? 0;
  Future<void> setSeekOffsetMs(int offset) => _prefs.setInt(_keySeekOffsetMs, offset);

  // Auto loop on song change setting
  bool getAutoLoopOnSongChange() => _prefs.getBool(_keyAutoLoopOnSongChange) ?? false;
  Future<void> setAutoLoopOnSongChange(bool val) => _prefs.setBool(_keyAutoLoopOnSongChange, val);
}
