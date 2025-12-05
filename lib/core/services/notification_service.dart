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

  /// Show download progress notification
  Future<void> showDownloadProgressNotification({
    required String filename,
    required int notificationId,
    required double progress,
    required int received,
    required int total,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Format file size
    String formatBytes(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }

    final progressPercent = (progress * 100).toInt();
    final receivedStr = formatBytes(received);
    final totalStr = formatBytes(total);

    // Truncate filename if too long
    final displayFilename = filename.length > 40 
        ? '${filename.substring(0, 37)}...' 
        : filename;

    // Android notification details with progress
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'downloads_channel',
      'Downloads',
      channelDescription: 'Notifications for file downloads',
      importance: Importance.low,
      priority: Priority.low,
      showWhen: false,
      ongoing: true, // Keep notification visible during download
      autoCancel: false, // Don't auto-cancel while downloading
      enableVibration: false,
      playSound: false,
      progress: progressPercent,
      maxProgress: 100,
      indeterminate: false,
      onlyAlertOnce: true, // Only play sound/vibrate once
    );

    // iOS notification details (not used for Android, but required)
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      notificationId,
      'Downloading: $displayFilename',
      '$progressPercent% • $receivedStr / $totalStr',
      details,
      payload: 'downloads',
    );
  }

  /// Show download completed notification
  Future<void> showDownloadCompletedNotification({
    required String filename,
    required int notificationId,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Truncate filename if too long
    final displayFilename = filename.length > 50 
        ? '${filename.substring(0, 47)}...' 
        : filename;

    // Android notification details
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'downloads_channel',
      'Downloads',
      channelDescription: 'Notifications for file downloads',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      ongoing: false,
      autoCancel: true,
      enableVibration: true,
      playSound: true,
    );

    // iOS notification details (not used for Android, but required)
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      notificationId,
      'Download Complete',
      displayFilename,
      details,
      payload: 'downloads',
    );
  }

  /// Show download failed notification
  Future<void> showDownloadFailedNotification({
    required String filename,
    required int notificationId,
    String? error,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Truncate filename if too long
    final displayFilename = filename.length > 40 
        ? '${filename.substring(0, 37)}...' 
        : filename;

    final errorMessage = error != null && error.length > 30
        ? '${error.substring(0, 27)}...'
        : (error ?? 'Download failed');

    // Android notification details
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'downloads_channel',
      'Downloads',
      channelDescription: 'Notifications for file downloads',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      ongoing: false,
      autoCancel: true,
      enableVibration: false,
      playSound: false,
    );

    // iOS notification details (not used for Android, but required)
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      notificationId,
      'Download Failed: $displayFilename',
      errorMessage,
      details,
      payload: 'downloads',
    );
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}

