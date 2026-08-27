import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/spotify_track.dart';
import 'spotify_api_service.dart';
import 'storage_service.dart';
import 'foreground_task_service.dart';

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

  // High-frequency Progress Notifier (prevents entire UI from rebuilding on every tick)
  final ValueNotifier<int> progressNotifier = ValueNotifier<int>(0);

  Timer? _precisionTimer;
  Timer? _apiSyncTimer;
  DateTime _lastSeekDispatched = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _seekLockoutUntil = DateTime.fromMillisecondsSinceEpoch(0);

  int _volumePercent = 75;

  // Getters
  SpotifyTrack? get currentTrack => _currentTrack;
  int? get startMarkerMs => _startMarkerMs;
  int? get endMarkerMs => _endMarkerMs;
  bool get isLoopActive => _isLoopActive;
  int get loopCount => _loopCount;
  int get currentProgressMs => _currentProgressMs;
  bool get isPlaying => _isPlaying;
  int get durationMs => _currentTrack?.durationMs ?? 0;
  int get volumePercent => _volumePercent;

  bool get isLoopValid => _startMarkerMs != null && _endMarkerMs != null && _startMarkerMs! < _endMarkerMs!;
  int get loopDurationMs => isLoopValid ? (_endMarkerMs! - _startMarkerMs!) : 0;

  Future<void> setVolume(int percent) async {
    _volumePercent = percent.clamp(0, 100);
    notifyListeners();
    await _apiService.setVolume(_volumePercent);
  }

  LoopEngine(this._apiService, this._storage) {
    _startTimers();

    // Foreground service control & heartbeat integration
    ForegroundTaskService.onStopLoopRequested = () {
      if (_isLoopActive) {
        _deactivateLooping();
        notifyListeners();
      }
    };

    ForegroundTaskService.onHeartbeat = () {
      _onPrecisionTick();
    };
  }

  void _startTimers() {
    // 35ms High-precision loop tick (~30 FPS)
    _precisionTimer = Timer.periodic(const Duration(milliseconds: 35), (_) => _onPrecisionTick());

    // 1.5s Background Spotify Connect sync
    _apiSyncTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) => syncWithSpotify());

    // Initial sync
    syncWithSpotify();
  }

  @override
  void dispose() {
    _precisionTimer?.cancel();
    _apiSyncTimer?.cancel();
    progressNotifier.dispose();
    WakelockPlus.disable().catchError((_) {});
    ForegroundTaskService.stop();
    super.dispose();
  }

  Future<void> syncWithSpotify() async {
    final track = await _apiService.getPlaybackState();
    // Resilient network handling: Never cancel playback state on transient null/timeout
    if (track == null) {
      return;
    }

    final isNewTrack = _currentTrack?.id != track.id;
    _currentTrack = track;
    _isPlaying = track.isPlaying;

    final now = DateTime.now();

    // Anti-jitter: If playing, only snap if real drift is significant (> 1.2s)
    if (isNewTrack || !track.isPlaying) {
      _currentProgressMs = track.progressMs;
      _lastProgressSync = now;
      progressNotifier.value = _currentProgressMs;
    } else if (now.isAfter(_seekLockoutUntil)) {
      final currentEst = liveProgressMs;
      final drift = (currentEst - track.progressMs).abs();
      if (drift > 1200) {
        _currentProgressMs = track.progressMs;
        _lastProgressSync = now;
        progressNotifier.value = _currentProgressMs;
      }
    }

    if (isNewTrack && track.id.isNotEmpty) {
      _loopCount = 0;
    }

    notifyListeners();
  }

  void _activateLooping() {
    _isLoopActive = true;
    WakelockPlus.enable().catchError((_) {});
    
    final trackName = _currentTrack != null ? _currentTrack!.title : 'Music';
    final loopSpan = _startMarkerMs != null && _endMarkerMs != null
        ? '${formatTime(_startMarkerMs!)} ➔ ${formatTime(_endMarkerMs!)}'
        : 'Active';
    ForegroundTaskService.start(
      title: '🔁 SpotiLoop • $trackName',
      text: 'Looping: $loopSpan',
    );
  }

  void _deactivateLooping() {
    _isLoopActive = false;
    WakelockPlus.disable().catchError((_) {});
    ForegroundTaskService.stop();
  }

  void _onPrecisionTick() {
    if (!_isPlaying || _currentTrack == null) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastProgressSync).inMilliseconds;
    final estimated = _currentProgressMs + elapsed;
    final maxDuration = _currentTrack!.durationMs;

    final currentPos = (maxDuration > 0 && estimated > maxDuration) ? maxDuration : estimated;
    progressNotifier.value = currentPos;

    // Loop trigger check
    if (_isLoopActive && _startMarkerMs != null && _endMarkerMs != null && _endMarkerMs! > _startMarkerMs!) {
      final offset = _storage.getSeekOffsetMs() > 0 ? _storage.getSeekOffsetMs() : 120; // 120ms lead offset
      final triggerPoint = _endMarkerMs! - offset;

      if (currentPos >= triggerPoint) {
        // Prevent rapid duplicate seeks within 300ms
        if (now.difference(_lastSeekDispatched).inMilliseconds > 300) {
          _lastSeekDispatched = now;
          _loopCount++;

          // Optimistically reset local timer back to Point A immediately
          _currentProgressMs = _startMarkerMs!;
          _lastProgressSync = now;
          progressNotifier.value = _startMarkerMs!;
          _seekLockoutUntil = now.add(const Duration(milliseconds: 1800));

          // Dispatch seek command to Spotify Connect
          _apiService.seekTo(_startMarkerMs!);

          // Update foreground notification status
          final trackName = _currentTrack != null ? _currentTrack!.title : 'Music';
          ForegroundTaskService.update(
            title: '🔁 SpotiLoop • $trackName (${_loopCount}x)',
            text: 'Looping: ${formatTime(_startMarkerMs!)} ➔ ${formatTime(_endMarkerMs!)}',
          );

          notifyListeners();
        }
      }
    }
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
      _startMarkerMs = (_endMarkerMs! - 1000).clamp(0, durationMs > 0 ? durationMs : 3600000);
    } else {
      _startMarkerMs = pos;
    }
    notifyListeners();
  }

  void setPointBToCurrent() {
    final pos = liveProgressMs;
    if (_startMarkerMs != null && pos <= _startMarkerMs!) {
      _endMarkerMs = (_startMarkerMs! + 1000).clamp(0, durationMs > 0 ? durationMs : 3600000);
    } else {
      _endMarkerMs = pos;
    }
    notifyListeners();
  }

  void setPointA(int? ms) {
    if (ms == null) {
      _startMarkerMs = null;
    } else {
      final max = _endMarkerMs ?? (durationMs > 0 ? durationMs : 3600000);
      _startMarkerMs = ms.clamp(0, max);
    }
    notifyListeners();
  }

  void setPointB(int? ms) {
    if (ms == null) {
      _endMarkerMs = null;
    } else {
      final min = _startMarkerMs ?? 0;
      final max = durationMs > 0 ? durationMs : 3600000;
      _endMarkerMs = ms.clamp(min, max);
    }
    notifyListeners();
  }

  void nudgeA(int deltaMs) {
    if (_startMarkerMs == null) {
      _startMarkerMs = liveProgressMs;
    }
    final target = _startMarkerMs! + deltaMs;
    final max = (_endMarkerMs != null) ? _endMarkerMs! - 100 : (durationMs > 0 ? durationMs : 3600000);
    _startMarkerMs = target.clamp(0, max > 0 ? max : 3600000);
    notifyListeners();
  }

  void nudgeB(int deltaMs) {
    if (_endMarkerMs == null) {
      _endMarkerMs = durationMs > 0 ? durationMs : 30000;
    }
    final target = _endMarkerMs! + deltaMs;
    final min = (_startMarkerMs != null) ? _startMarkerMs! + 100 : 0;
    final max = durationMs > 0 ? durationMs : 3600000;
    _endMarkerMs = target.clamp(min, max);
    notifyListeners();
  }

  void jumpToA() {
    if (_startMarkerMs != null) {
      _currentProgressMs = _startMarkerMs!;
      _lastProgressSync = DateTime.now();
      progressNotifier.value = _startMarkerMs!;
      _seekLockoutUntil = DateTime.now().add(const Duration(milliseconds: 1800));
      _apiService.seekTo(_startMarkerMs!);
      notifyListeners();
    }
  }

  void jumpToB() {
    if (_endMarkerMs != null) {
      _currentProgressMs = _endMarkerMs!;
      _lastProgressSync = DateTime.now();
      progressNotifier.value = _endMarkerMs!;
      _seekLockoutUntil = DateTime.now().add(const Duration(milliseconds: 1800));
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
    
    if (!_isLoopActive) {
      _activateLooping();
      // Only seek to Point A if we are currently BEFORE Point A or AFTER Point B
      // If song is ALREADY playing inside the loop range, do not interrupt or pause!
      final currentPos = liveProgressMs;
      if (_startMarkerMs != null && (currentPos < _startMarkerMs! || (_endMarkerMs != null && currentPos >= _endMarkerMs!))) {
        jumpToA();
      }
    } else {
      _deactivateLooping();
    }
    notifyListeners();
  }

  void resetMarkers() {
    _startMarkerMs = null;
    _endMarkerMs = null;
    _deactivateLooping();
    _loopCount = 0;
    notifyListeners();
  }

  // Playback passthroughs
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      _isPlaying = false;
      _currentProgressMs = liveProgressMs;
      _lastProgressSync = DateTime.now();
      progressNotifier.value = _currentProgressMs;
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
    final maxDuration = durationMs > 0 ? durationMs : 3600000;
    final target = positionMs.clamp(0, maxDuration);
    _currentProgressMs = target;
    final now = DateTime.now();
    _lastProgressSync = now;
    progressNotifier.value = target;
    _seekLockoutUntil = now.add(const Duration(milliseconds: 1800));
    notifyListeners();
    await _apiService.seekTo(target);
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

  static String formatTime(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final tenths = (ms % 1000) ~/ 100;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.$tenths';
  }
}
