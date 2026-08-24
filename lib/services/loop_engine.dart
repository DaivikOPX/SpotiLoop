import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/spotify_track.dart';
import '../models/loop_preset.dart';
import 'spotify_api_service.dart';
import 'storage_service.dart';

class LoopEngine extends ChangeNotifier {
  final SpotifyApiService _apiService;
  final StorageService _storage;

  SpotifyTrack? _currentTrack;
  int? _startMarkerMs; // Point A
  int? _endMarkerMs; // Point B
  bool _isLoopActive = false;
  int _loopCount = 0;

  int _currentProgressMs = 0;
  DateTime _lastProgressSync = DateTime.now();
  bool _isPlaying = false;

  Timer? _precisionTimer;
  Timer? _apiSyncTimer;
  DateTime _lastSeekDispatched = DateTime.fromMillisecondsSinceEpoch(0);

  // Getters
  SpotifyTrack? get currentTrack => _currentTrack;
  int? get startMarkerMs => _startMarkerMs;
  int? get endMarkerMs => _endMarkerMs;
  bool get isLoopActive => _isLoopActive;
  int get loopCount => _loopCount;
  int get currentProgressMs => _currentProgressMs;
  bool get isPlaying => _isPlaying;
  int get durationMs => _currentTrack?.durationMs ?? 0;

  LoopEngine(this._apiService, this._storage) {
    _startTimers();
  }

  void _startTimers() {
    // High-precision local tick timer for smooth progress UI and sub-second loop triggering
    _precisionTimer = Timer.periodic(const Duration(milliseconds: 35), (_) => _onPrecisionTick());

    // Background Spotify API polling to detect external track changes, pauses, device switches
    _apiSyncTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) => syncWithSpotify());

    // Initial sync
    syncWithSpotify();
  }

  @override
  void dispose() {
    _precisionTimer?.cancel();
    _apiSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> syncWithSpotify() async {
    final track = await _apiService.getPlaybackState();
    if (track == null) {
      if (_currentTrack != null) {
        _currentTrack = null;
        _isPlaying = false;
        notifyListeners();
      }
      return;
    }

    final isNewTrack = _currentTrack?.id != track.id;
    _currentTrack = track;
    _currentProgressMs = track.progressMs;
    _lastProgressSync = DateTime.now();
    _isPlaying = track.isPlaying;

    if (isNewTrack && track.id.isNotEmpty) {
      _loopCount = 0;
      _autoLoadPresetForTrack(track.id);
    }

    notifyListeners();
  }

  void _autoLoadPresetForTrack(String trackId) {
    final presets = _storage.getPresets();
    final match = presets.where((p) => p.trackId == trackId).firstOrNull;
    if (match != null) {
      _startMarkerMs = match.startMs;
      _endMarkerMs = match.endMs;
      if (_storage.getAutoLoopOnSongChange()) {
        _isLoopActive = true;
      }
    }
  }

  void _onPrecisionTick() {
    if (!_isPlaying || _currentTrack == null) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastProgressSync).inMilliseconds;
    final estimated = _currentProgressMs + elapsed;
    final maxDuration = _currentTrack!.durationMs;

    final currentPos = estimated > maxDuration ? maxDuration : estimated;

    // Loop trigger check
    if (_isLoopActive && _startMarkerMs != null && _endMarkerMs != null) {
      // If we reached or passed Point B (accounting for user-configured latency offset)
      final offset = _storage.getSeekOffsetMs();
      final triggerPoint = _endMarkerMs! - offset;

      if (currentPos >= triggerPoint) {
        // Prevent rapid duplicate seeks within 250ms
        if (now.difference(_lastSeekDispatched).inMilliseconds > 250) {
          _lastSeekDispatched = now;
          _loopCount++;

          // Optimistically reset local timer back to Point A immediately
          _currentProgressMs = _startMarkerMs!;
          _lastProgressSync = now;

          // Dispatch seek command to Spotify
          _apiService.seekTo(_startMarkerMs!);
          notifyListeners();
          return;
        }
      }
    }

    notifyListeners();
  }

  int get liveProgressMs {
    if (!_isPlaying) return _currentProgressMs;
    final elapsed = DateTime.now().difference(_lastProgressSync).inMilliseconds;
    final estimated = _currentProgressMs + elapsed;
    final maxDuration = _currentTrack?.durationMs ?? 0;
    return (maxDuration > 0 && estimated > maxDuration) ? maxDuration : estimated;
  }

  // Marker Controls
  void setPointAToCurrent() {
    final pos = liveProgressMs;
    if (_endMarkerMs != null && pos >= _endMarkerMs!) {
      _startMarkerMs = (_endMarkerMs! - 1000).clamp(0, durationMs);
    } else {
      _startMarkerMs = pos;
    }
    notifyListeners();
  }

  void setPointBToCurrent() {
    final pos = liveProgressMs;
    if (_startMarkerMs != null && pos <= _startMarkerMs!) {
      _endMarkerMs = (_startMarkerMs! + 1000).clamp(0, durationMs);
    } else {
      _endMarkerMs = pos;
    }
    notifyListeners();
  }

  void setPointA(int ms) {
    _startMarkerMs = ms.clamp(0, _endMarkerMs ?? durationMs);
    notifyListeners();
  }

  void setPointB(int ms) {
    _endMarkerMs = ms.clamp(_startMarkerMs ?? 0, durationMs);
    notifyListeners();
  }

  void nudgeA(int deltaMs) {
    if (_startMarkerMs == null) {
      _startMarkerMs = liveProgressMs;
    }
    final target = _startMarkerMs! + deltaMs;
    final max = (_endMarkerMs != null) ? _endMarkerMs! - 100 : durationMs;
    _startMarkerMs = target.clamp(0, max > 0 ? max : durationMs);
    notifyListeners();
  }

  void nudgeB(int deltaMs) {
    if (_endMarkerMs == null) {
      _endMarkerMs = durationMs;
    }
    final target = _endMarkerMs! + deltaMs;
    final min = (_startMarkerMs != null) ? _startMarkerMs! + 100 : 0;
    _endMarkerMs = target.clamp(min, durationMs);
    notifyListeners();
  }

  void jumpToA() {
    if (_startMarkerMs != null) {
      _currentProgressMs = _startMarkerMs!;
      _lastProgressSync = DateTime.now();
      _apiService.seekTo(_startMarkerMs!);
      notifyListeners();
    }
  }

  void jumpToB() {
    if (_endMarkerMs != null) {
      _currentProgressMs = _endMarkerMs!;
      _lastProgressSync = DateTime.now();
      _apiService.seekTo(_endMarkerMs!);
      notifyListeners();
    }
  }

  void toggleLoop() {
    if (_startMarkerMs == null) {
      _startMarkerMs = 0;
    }
    if (_endMarkerMs == null) {
      _endMarkerMs = durationMs > 0 ? durationMs : 30000;
    }
    _isLoopActive = !_isLoopActive;
    notifyListeners();
  }

  void resetMarkers() {
    _startMarkerMs = null;
    _endMarkerMs = null;
    _isLoopActive = false;
    _loopCount = 0;
    notifyListeners();
  }

  // Playback passthroughs
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      _isPlaying = false;
      _currentProgressMs = liveProgressMs;
      _lastProgressSync = DateTime.now();
      notifyListeners();
      await _apiService.pause();
    } else {
      _isPlaying = true;
      _lastProgressSync = DateTime.now();
      notifyListeners();
      await _apiService.play();
    }
    await syncWithSpotify();
  }

  Future<void> seek(int positionMs) async {
    _currentProgressMs = positionMs.clamp(0, durationMs);
    _lastProgressSync = DateTime.now();
    notifyListeners();
    await _apiService.seekTo(_currentProgressMs);
  }

  Future<void> next() async {
    await _apiService.next();
    await Future.delayed(const Duration(milliseconds: 400));
    await syncWithSpotify();
  }

  Future<void> previous() async {
    await _apiService.previous();
    await Future.delayed(const Duration(milliseconds: 400));
    await syncWithSpotify();
  }

  // Preset management
  Future<void> saveCurrentAsPreset(String name) async {
    if (_currentTrack == null || _startMarkerMs == null || _endMarkerMs == null) return;

    final preset = LoopPreset(
      id: '${_currentTrack!.id}_${DateTime.now().millisecondsSinceEpoch}',
      trackId: _currentTrack!.id,
      trackTitle: _currentTrack!.title,
      trackArtist: _currentTrack!.artist,
      name: name.trim().isEmpty ? 'Loop (${formatTime(_startMarkerMs!)} - ${formatTime(_endMarkerMs!)})' : name.trim(),
      startMs: _startMarkerMs!,
      endMs: _endMarkerMs!,
      createdAt: DateTime.now(),
    );

    await _storage.savePreset(preset);
    notifyListeners();
  }

  void applyPreset(LoopPreset preset) {
    _startMarkerMs = preset.startMs;
    _endMarkerMs = preset.endMs;
    _isLoopActive = true;
    jumpToA();
    notifyListeners();
  }

  static String formatTime(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final tenths = (ms % 1000) ~/ 100;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.$tenths';
  }
}
