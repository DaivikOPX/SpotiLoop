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
  Timer? _bgTickTimer;
  DateTime _lastSeekDispatched = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _startBgTicker();
  }

  void _startBgTicker() {
    _bgTickTimer?.cancel();
    // 50ms High-Precision background loop ticker inside the Background Service Isolate
    _bgTickTimer = Timer.periodic(const Duration(milliseconds: 50), (_) => _onBgTick());
  }

  void _onBgTick() {
    if (!_isLooping || _startMs == null || _endMs == null || _endMs! <= _startMs!) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastSyncTime).inMilliseconds;
    final pos = _currentPos + elapsed;

    final triggerPoint = _endMs! - _seekOffsetMs;
    if (pos >= triggerPoint) {
      if (now.difference(_lastSeekDispatched).inMilliseconds > 350) {
        _lastSeekDispatched = now;
        _loopCount++;

        // Optimistically snap local time back to Point A
        _currentPos = _startMs!;
        _lastSyncTime = now;

        // Perform HTTP seek directly from Background Service Isolate
        _dispatchBackgroundSeek(_startMs!);

        // Update Notification Bar
        final span = '${_formatTime(_startMs!)} ➔ ${_formatTime(_endMs!)}';
        FlutterForegroundTask.updateService(
          notificationTitle: '🔁 SpotiLoop • $_trackTitle (${_loopCount}x)',
          notificationText: 'Looping: $span (Background Active)',
        );

        // Notify Main UI Isolate
        FlutterForegroundTask.sendDataToMain({
          'action': 'bg_loop_triggered',
          'loopCount': _loopCount,
          'pos': _startMs,
        });
      }
    }
  }

  Future<void> _dispatchBackgroundSeek(int positionMs) async {
    if (_accessToken == null || _accessToken!.isEmpty) return;
    try {
      final uri = Uri.parse('https://api.spotify.com/v1/me/player/seek?position_ms=$positionMs');
      await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Length': '0',
        },
      ).timeout(const Duration(milliseconds: 2500));
    } catch (e) {
      debugPrint('Background seek network error: $e');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Regular pulse to ensure foreground service stays active
    if (_isLooping && _startMs != null && _endMs != null) {
      _onBgTick();
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
      } else if (action == 'sync_progress') {
        _currentPos = (data['currentProgressMs'] as int?) ?? _currentPos;
        _lastSyncTime = DateTime.now();
      } else if (action == 'stop_loop') {
        _isLooping = false;
      }
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _bgTickTimer?.cancel();
    _isLooping = false;
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'btn_stop_loop') {
      _isLooping = false;
      _bgTickTimer?.cancel();
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
      // 1. Request Notification Permission on Android 13+ (Required for Foreground Service)
      final notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      // 2. Request Battery Optimization Exemption (Immunity from Android Doze Mode)
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
          eventAction: ForegroundTaskEventAction.repeat(1000), // 1s background pulse
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
