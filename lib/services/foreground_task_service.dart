import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:http/http.dart' as http;

@pragma('vm:entry-point')
void startForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(SpotiLoopTaskHandler());
}

class SpotiLoopTaskHandler extends TaskHandler {
  int? _startMs;
  int? _endMs;
  String? _accessToken;
  String _trackTitle = 'Music';
  int _seekOffsetMs = 120;
  bool _isLooping = false;
  int _loopCount = 0;

  int _currentPos = 0;
  DateTime _lastSyncTime = DateTime.now();
  
  // Exact Target-Time Event Timer (survives Android CPU throttling)
  Timer? _exactLoopTimer;
  // High-resolution UI progress ticker
  Timer? _highResTicker;
  
  DateTime _lastSeekDispatched = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _seekLockoutUntil = DateTime.fromMillisecondsSinceEpoch(0);
  http.Client? _client;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _client = http.Client();
    _startBackgroundTimers();
  }

  void _startBackgroundTimers() {
    _highResTicker?.cancel();
    _highResTicker = Timer.periodic(const Duration(milliseconds: 50), (_) => _checkProgressTick());
    _scheduleNextLoopTarget();
  }

  void _scheduleNextLoopTarget() {
    _exactLoopTimer?.cancel();
    if (!_isLooping || _startMs == null || _endMs == null || _endMs! <= _startMs!) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastSyncTime).inMilliseconds;
    final currentEstimated = _currentPos + elapsed;

    final triggerPoint = _endMs! - _seekOffsetMs;
    final remainingMs = triggerPoint - currentEstimated;

    if (remainingMs <= 0) {
      _triggerLoopSeek();
    } else {
      _exactLoopTimer = Timer(Duration(milliseconds: remainingMs), () {
        _triggerLoopSeek();
      });
    }
  }

  void _checkProgressTick() {
    if (!_isLooping || _startMs == null || _endMs == null || _endMs! <= _startMs!) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastSyncTime).inMilliseconds;
    final currentEstimated = _currentPos + elapsed;

    final triggerPoint = _endMs! - _seekOffsetMs;
    if (currentEstimated >= triggerPoint && now.isAfter(_seekLockoutUntil)) {
      _triggerLoopSeek();
    }
  }

  void _triggerLoopSeek() {
    if (!_isLooping || _startMs == null || _endMs == null || _endMs! <= _startMs!) return;

    final now = DateTime.now();
    if (now.difference(_lastSeekDispatched).inMilliseconds < 400) return;

    _lastSeekDispatched = now;
    _seekLockoutUntil = now.add(const Duration(milliseconds: 1800));
    _loopCount++;

    // 1. Instantly reset local clock to Point A
    _currentPos = _startMs!;
    _lastSyncTime = now;

    // 2. Dispatch HTTP seek command to Spotify
    _dispatchBackgroundSeek(_startMs!);

    // 3. Update persistent notification in status bar
    final span = '${_formatTime(_startMs!)} ➔ ${_formatTime(_endMs!)}';
    FlutterForegroundTask.updateService(
      notificationTitle: '🔁 SpotiLoop • $_trackTitle (${_loopCount}x)',
      notificationText: 'Looping: $span (Background Active)',
    );

    // 4. Send event to main Flutter UI
    FlutterForegroundTask.sendDataToMain({
      'action': 'bg_loop_triggered',
      'loopCount': _loopCount,
      'pos': _startMs,
    });

    // 5. Schedule the next exact loop arrival
    _scheduleNextLoopTarget();
  }

  Future<void> _dispatchBackgroundSeek(int positionMs) async {
    if (_accessToken == null || _accessToken!.isEmpty) return;
    try {
      _client ??= http.Client();
      final uri = Uri.parse('https://api.spotify.com/v1/me/player/seek?position_ms=$positionMs');
      final res = await _client!.put(
        uri,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Length': '0',
        },
      ).timeout(const Duration(milliseconds: 2800));
      debugPrint('Background seek -> Status: ${res.statusCode}');
    } catch (e) {
      debugPrint('Background seek network error: $e');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 1-second native Android OS watchdog pulse
    if (_isLooping && _startMs != null && _endMs != null) {
      final now = DateTime.now();
      final elapsed = now.difference(_lastSyncTime).inMilliseconds;
      final currentEstimated = _currentPos + elapsed;
      final triggerPoint = _endMs! - _seekOffsetMs;

      if (currentEstimated >= triggerPoint && now.isAfter(_seekLockoutUntil)) {
        _triggerLoopSeek();
      } else if (_exactLoopTimer == null || !_exactLoopTimer!.isActive) {
        _scheduleNextLoopTarget();
      }
    }
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      final action = data['action'];
      if (action == 'start_loop' || action == 'update_params') {
        _startMs = data['startMs'] as int?;
        _endMs = data['endMs'] as int?;
        _accessToken = data['accessToken'] as String?;
        _trackTitle = (data['trackTitle'] as String?) ?? _trackTitle;
        _seekOffsetMs = (data['seekOffsetMs'] as int?) ?? _seekOffsetMs;
        _currentPos = (data['currentProgressMs'] as int?) ?? (_startMs ?? 0);
        _lastSyncTime = DateTime.now();
        _isLooping = true;
        _scheduleNextLoopTarget();
      } else if (action == 'sync_progress') {
        if (DateTime.now().isAfter(_seekLockoutUntil)) {
          _currentPos = (data['currentProgressMs'] as int?) ?? _currentPos;
          _lastSyncTime = DateTime.now();
          _scheduleNextLoopTarget();
        }
      } else if (action == 'stop_loop') {
        _isLooping = false;
        _exactLoopTimer?.cancel();
        _highResTicker?.cancel();
      }
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _exactLoopTimer?.cancel();
    _highResTicker?.cancel();
    _isLooping = false;
    _client?.close();
    _client = null;
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'btn_stop_loop') {
      _isLooping = false;
      _exactLoopTimer?.cancel();
      _highResTicker?.cancel();
      _client?.close();
      _client = null;
      FlutterForegroundTask.sendDataToMain({'action': 'stop_loop'});
      FlutterForegroundTask.stopService();
    }
  }

  static String _formatTime(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final tenths = (ms % 1000) ~/ 100;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.$tenths';
  }
}

class ForegroundTaskService {
  static void Function()? onStopLoopRequested;
  static void Function(int loopCount, int pos)? onBackgroundLoopTriggered;

  static void initCommunicationPort() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      FlutterForegroundTask.initCommunicationPort();
      FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    }
  }

  static void _onReceiveTaskData(Object data) {
    if (data is Map) {
      if (data['action'] == 'stop_loop') {
        onStopLoopRequested?.call();
      } else if (data['action'] == 'bg_loop_triggered') {
        final count = data['loopCount'] as int? ?? 0;
        final pos = data['pos'] as int? ?? 0;
        onBackgroundLoopTriggered?.call(count, pos);
      }
    }
  }

  static Future<void> initService() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    try {
      // 1. Request Notification Permission on Android 13+
      final notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      // 2. Request Battery Optimization Exemption
      if (Platform.isAndroid) {
        final isIgnoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
        if (!isIgnoring) {
          await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        }
      }

      // 3. Initialize Foreground Service with High-Priority WakeLock & WifiLock
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'spotiloop_looper_channel',
          channelName: 'SpotiLoop Active Playback',
          channelDescription: 'Keeps audio looper active when screen is locked or in background.',
          channelImportance: NotificationChannelImportance.DEFAULT,
          priority: NotificationPriority.DEFAULT,
          onlyAlertOnce: true,
          showWhen: true,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(1000), // 1s native OS pulse
          autoRunOnBoot: false,
          autoRunOnMyPackageReplaced: false,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
    } catch (e) {
      debugPrint('Foreground task init error: $e');
    }
  }

  static Future<bool> isBatteryOptimizationIgnored() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        return await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      } catch (_) {}
    }
    return true;
  }

  static Future<void> requestIgnoreBatteryOptimization() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      } catch (_) {}
    }
  }

  static Future<void> startLoopTask({
    required int? startMs,
    required int? endMs,
    required String? accessToken,
    required String trackTitle,
    required int currentProgressMs,
    required int seekOffsetMs,
  }) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    try {
      final span = (startMs != null && endMs != null)
          ? '${_formatTime(startMs)} ➔ ${_formatTime(endMs)}'
          : 'Active';
      final title = '🔁 SpotiLoop • $trackTitle';
      final text = 'Looping: $span (Background Active)';

      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
      } else {
        await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: title,
          notificationText: text,
          notificationButtons: [
            const NotificationButton(id: 'btn_stop_loop', text: '⏹ Stop Loop'),
          ],
          callback: startForegroundCallback,
        );
      }

      FlutterForegroundTask.sendDataToTask({
        'action': 'start_loop',
        'startMs': startMs,
        'endMs': endMs,
        'accessToken': accessToken,
        'trackTitle': trackTitle,
        'currentProgressMs': currentProgressMs,
        'seekOffsetMs': seekOffsetMs,
      });
    } catch (e) {
      debugPrint('Start loop task error: $e');
    }
  }

  static void updateLoopParams({
    required int? startMs,
    required int? endMs,
    required String? accessToken,
    required String trackTitle,
    required int currentProgressMs,
    required int seekOffsetMs,
  }) {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      FlutterForegroundTask.sendDataToTask({
        'action': 'update_params',
        'startMs': startMs,
        'endMs': endMs,
        'accessToken': accessToken,
        'trackTitle': trackTitle,
        'currentProgressMs': currentProgressMs,
        'seekOffsetMs': seekOffsetMs,
      });
    } catch (e) {
      debugPrint('Update loop params error: $e');
    }
  }

  static void syncProgressToTask(int currentProgressMs) {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      FlutterForegroundTask.sendDataToTask({
        'action': 'sync_progress',
        'currentProgressMs': currentProgressMs,
      });
    } catch (e) {
      debugPrint('Sync progress error: $e');
    }
  }

  static Future<void> stop() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    try {
      FlutterForegroundTask.sendDataToTask({'action': 'stop_loop'});
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      debugPrint('Stop foreground service error: $e');
    }
  }

  static String _formatTime(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final tenths = (ms % 1000) ~/ 100;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.$tenths';
  }
}
