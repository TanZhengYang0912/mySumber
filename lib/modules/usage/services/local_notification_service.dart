import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/app_notification.dart';

/// Mirrors in-app [AppNotification]s as real device notifications, so a
/// user who isn't looking at the app still sees a system tray/lock-screen
/// alert. Android and iOS/macOS only — other platforms are no-ops.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _nextId = 0;

  bool get _supportsNotifications =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  Future<void> init() async {
    if (!_supportsNotifications || _initialized) return;
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: darwinSettings,
          macOS: darwinSettings,
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      _initialized = true;
    } catch (e) {
      debugPrint('Local notifications unavailable: $e');
    }
  }

  Future<void> show(AppNotification notification) async {
    if (!_supportsNotifications || !_initialized) return;
    try {
      const androidDetails = AndroidNotificationDetails(
        'mysumber_alerts',
        'mySumber Alerts',
        channelDescription: 'Usage, billing, and account alerts',
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      );
      await _plugin.show(
        _nextId++,
        notification.title,
        notification.message,
        details,
      );
    } catch (e) {
      debugPrint('Could not show local notification: $e');
    }
  }
}
