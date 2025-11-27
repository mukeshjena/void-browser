import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../../app.dart';
import '../../features/downloads/presentation/screens/downloads_screen_new.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Android initialization settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings (not used for Android, but required)
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize the plugin
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request notification permission for Android 13+
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - navigate to downloads screen
    if (response.payload == 'downloads') {
      // Use navigator key to navigate from anywhere
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => const DownloadsScreenNew(),
        ),
      );
    }
  }

  /// Show download started notification
  Future<void> showDownloadStartedNotification({
    required String filename,
    required int notificationId,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Android notification details
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'downloads_channel',
      'Downloads',
      channelDescription: 'Notifications for file downloads',
      importance: Importance.low,
      priority: Priority.low,
      showWhen: false,
      ongoing: false,
      autoCancel: true,
      enableVibration: false,
      playSound: false,
    );

    // iOS notification details (not used for Android, but required)
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Truncate filename if too long
    final displayFilename = filename.length > 50 
        ? '${filename.substring(0, 47)}...' 
        : filename;

    await _notifications.show(
      notificationId,
      'Download Started',
      'Downloading: $displayFilename',
      details,
      payload: 'downloads', // Payload to identify this notification
    );
  }

  /// Cancel a notification
  Future<void> cancelNotification(int notificationId) async {
    await _notifications.cancel(notificationId);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}

