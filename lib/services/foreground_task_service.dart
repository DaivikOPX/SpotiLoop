import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(SpotiLoopTaskHandler());
}

class SpotiLoopTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('Foreground Task Started: ${starter.name}');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Keep-alive heartbeat tick
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('Foreground Task Destroyed');
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'btn_stop_loop') {
      FlutterForegroundTask.sendDataToMain({'action': 'stop_loop'});
    }
  }
}

class ForegroundTaskService {
  static void Function()? onStopLoopRequested;

  static void initCommunicationPort() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      FlutterForegroundTask.initCommunicationPort();
      FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    }
  }

  static void _onReceiveTaskData(Object data) {
    if (data is Map && data['action'] == 'stop_loop') {
      onStopLoopRequested?.call();
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
          eventAction: ForegroundTaskEventAction.repeat(3000),
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

  static Future<void> start({required String title, required String text}) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    try {
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
    } catch (e) {
      debugPrint('Start foreground service error: $e');
    }
  }

  static Future<void> update({required String title, required String text}) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
      }
    } catch (e) {
      debugPrint('Update foreground service error: $e');
    }
  }

  static Future<void> stop() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      debugPrint('Stop foreground service error: $e');
    }
  }
}
