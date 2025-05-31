import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:io' show Platform;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> init() async {
    if (kIsWeb) {
      print('Notifications not supported on web. Skipping initialization.');
      return;
    }

    try {
      tz.initializeTimeZones();
      await _requestPermissions();
      await _initializeLocalNotifications();
      await _initializeFirebaseMessaging();
      print('NotificationService initialized successfully');
    } catch (e) {
      print('Error initializing NotificationService: $e');
      rethrow;
    }
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;

    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      print('FCM permission status: ${settings.authorizationStatus}');

      if (!kIsWeb && Platform.isIOS) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
      }
    } catch (e) {
      print('Error requesting permissions: $e');
      rethrow;
    }
  }

  Future<void> _initializeLocalNotifications() async {
    if (kIsWeb) return;

    try {
      const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _onSelectNotification(response);
        },
      );

      if (!kIsWeb && Platform.isAndroid) {
        await _createNotificationChannels();
      }
    } catch (e) {
      print('Error initializing local notifications: $e');
      rethrow;
    }
  }

  Future<void> _createNotificationChannels() async {
    const highImportanceChannel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
      enableLights: true,
      enableVibration: true,
    );

    const scheduledChannel = AndroidNotificationChannel(
      'scheduled_channel',
      'Scheduled Notifications',
      description: 'This channel is used for scheduled notifications.',
      importance: Importance.high,
      enableVibration: true,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(highImportanceChannel);
    await androidPlugin?.createNotificationChannel(scheduledChannel);
  }

  Future<void> _initializeFirebaseMessaging() async {
    if (kIsWeb) return;

    try {
      final token = await _firebaseMessaging.getToken();
      print('FCM Token: $token');

      FirebaseMessaging.onMessage.listen((message) => _handleMessage(message));
      FirebaseMessaging.onMessageOpenedApp.listen((message) => _handleMessage(message));
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessage(initialMessage);
      }
    } catch (e) {
      print('Error initializing Firebase messaging: $e');
      rethrow;
    }
  }

  Future<void> _onSelectNotification(NotificationResponse response) async {
    try {
      print('Notification tapped: ${response.payload}');
      // TODO: Handle navigation based on payload
    } catch (e) {
      print('Error handling notification tap: $e');
    }
  }

  Future<void> _handleMessage(RemoteMessage message) async {
    try {
      print('Handling message: ${message.messageId}');
      await _showLocalNotification(
        title: message.notification?.title ?? 'New Notification',
        body: message.notification?.body ?? '',
        payload: message.data.toString(),
      );
    } catch (e) {
      print('Error handling message: $e');
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;

    try {
      final androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        enableLights: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch,
        title,
        body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: payload,
      );
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }

  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (kIsWeb) return;

    try {
      final androidDetails = AndroidNotificationDetails(
        'scheduled_channel',
        'Scheduled Notifications',
        channelDescription: 'This channel is used for scheduled notifications.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final scheduledTime = tz.TZDateTime.from(scheduledDate, tz.local);

      await _localNotifications.zonedSchedule(
        DateTime.now().millisecondsSinceEpoch,
        title,
        body,
        scheduledTime,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      print('Notification scheduled for $scheduledTime');
    } catch (e) {
      print('Error scheduling notification: $e');
      rethrow;
    }
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;

    try {
      await _localNotifications.cancel(id);
      print('Notification $id cancelled');
    } catch (e) {
      print('Error cancelling notification $id: $e');
      rethrow;
    }
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;

    try {
      await _localNotifications.cancelAll();
      print('All notifications cancelled');
    } catch (e) {
      print('Error cancelling all notifications: $e');
      rethrow;
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;

  await Firebase.initializeApp();
  print('Handling background message: ${message.messageId}');
}
