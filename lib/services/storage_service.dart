import 'package:shared_preferences/shared_preferences.dart';
import '../models/loop_preset.dart';

class StorageService {
  static const String _keyAccessToken = 'spotify_access_token';
  static const String _keyRefreshToken = 'spotify_refresh_token';
  static const String _keyTokenExpiry = 'spotify_token_expiry';
  static const String _keyCodeVerifier = 'spotify_code_verifier';
  static const String _keyPresets = 'spotify_loop_presets';
  static const String _keyPresetSortMode = 'spotify_preset_sort_mode';
  static const String _keyUserId = 'spotify_user_id';
  static const String _keySeekOffsetMs = 'loop_seek_offset_ms';
  static const String _keyAutoLoopOnSongChange = 'auto_loop_on_song_change';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // Encrypted Client ID Resolver (Protected & Hidden)
  static String _resolveDefaultClientId() {
    const k = [106,60,106,56,104,60,106,110,104,111,110,105,110,109,104,105,99,105,110,111,108,99,109,60,105,99,109,111,107,107,98,99];
    return String.fromCharCodes(k.map((c) => c ^ 0x5a));
  }

  String getClientId() => _resolveDefaultClientId();

  // PKCE Code Verifier
  String? getCodeVerifier() => _prefs.getString(_keyCodeVerifier);
  Future<void> setCodeVerifier(String verifier) => _prefs.setString(_keyCodeVerifier, verifier);

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
    await _prefs.remove(_keyCodeVerifier);
  }

  // Presets are tied to the connected Spotify account ON THIS DEVICE. The
  // key includes the Spotify user id, so switching accounts (or a fresh login
  // on this phone) shows the right owner's presets. Cross-device sync is a
  // separate future step (would move presets off-device via cloud storage).
  String? _cachedUserId;

  String? getUserId() => _cachedUserId ?? (_cachedUserId = _prefs.getString(_keyUserId));
  Future<void> setUserId(String id) async {
    _cachedUserId = id;
    await _prefs.setString(_keyUserId, id);
  }

  String getPresetsKey() {
    final uid = getUserId();
    return uid != null ? '${_keyPresets}_$uid' : _keyPresets;
  }

  // Presets returned in the currently chosen sort order.
  List<LoopPreset> getPresets() => getPresetsSorted(getPresetSortMode());

  List<LoopPreset> getPresetsSorted(String sortMode) {
    final list = LoopPreset.decodeList(_prefs.getString(getPresetsKey()) ?? '').toList();
    switch (sortMode) {
      case 'recency':
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      case 'nameAsc':
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      case 'nameDesc':
        list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        return list;
      case 'trackAsc':
        list.sort((a, b) =>
            (a.trackTitle + ' ' + a.trackArtist)
                .toLowerCase()
                .compareTo((b.trackTitle + ' ' + b.trackArtist).toLowerCase()));
        return list;
      default:
        // 'manual' / custom drag order: stored order is authoritative.
        list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return list;
    }
  }

  String getPresetSortMode() => _prefs.getString(_keyPresetSortMode) ?? 'recency';

  Future<void> setPresetSortMode(String mode) async {
    await _prefs.setString(_keyPresetSortMode, mode);
  }

  Future<void> savePreset(LoopPreset preset) async {
    final list = getPresets();
    list.removeWhere((p) => p.id == preset.id);
    list.add(preset);
    final ordered = _assignOrder(list);
    await _prefs.setString(getPresetsKey(), LoopPreset.encodeList(ordered));
  }

  Future<void> savePresetAtTop(LoopPreset preset) async {
    final list = getPresets();
    list.removeWhere((p) => p.id == preset.id);
    list.insert(0, preset);
    final ordered = _assignOrder(list);
    await _prefs.setString(getPresetsKey(), LoopPreset.encodeList(ordered));
  }

  Future<void> updatePreset(LoopPreset preset) async {
    final list = getPresets();
    final i = list.indexWhere((p) => p.id == preset.id);
    if (i >= 0) {
      list[i] = preset;
      await _prefs.setString(getPresetsKey(), LoopPreset.encodeList(list));
    }
  }

  Future<void> deletePreset(String presetId) async {
    final list = getPresets();
    list.removeWhere((p) => p.id == presetId);
    await _prefs.setString(getPresetsKey(), LoopPreset.encodeList(list));
  }

  Future<void> reorderPresets(List<LoopPreset> reordered) async {
    final existing = getPresets();
    final map = {for (final p in existing) p.id: p};
    final ordered = <LoopPreset>[];
    int order = 0;
    for (final id in reordered.map((p) => p.id)) {
      final p = map[id];
      if (p != null) {
        ordered.add(p.copyWith(sortOrder: order++));
      }
    }
    ordered.addAll(existing.where((p) => !reordered.any((r) => r.id == p.id)));
    await _prefs.setString(getPresetsKey(), LoopPreset.encodeList(ordered));
  }

  // Assign contiguous sortOrder to a list so drag order is persisted.
  List<LoopPreset> _assignOrder(List<LoopPreset> list) {
    int order = 0;
    return list.map((p) => p.copyWith(sortOrder: order++)).toList();
  }

  // Tuning offset (in ms) to compensate for network latency when sending seek
  int getSeekOffsetMs() => _prefs.getInt(_keySeekOffsetMs) ?? 0;
  Future<void> setSeekOffsetMs(int offset) => _prefs.setInt(_keySeekOffsetMs, offset);

  // Auto loop on song change setting
  bool getAutoLoopOnSongChange() => _prefs.getBool(_keyAutoLoopOnSongChange) ?? false;
  Future<void> setAutoLoopOnSongChange(bool val) => _prefs.setBool(_keyAutoLoopOnSongChange, val);
}
