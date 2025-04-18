import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

class CourierBackgroundNotificationService {
  static final CourierBackgroundNotificationService _instance =
      CourierBackgroundNotificationService._internal();
  factory CourierBackgroundNotificationService() => _instance;
  CourierBackgroundNotificationService._internal();

  final client = Supabase.instance.client;
  late RealtimeChannel _subscription;
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  final Set<String> _processedNotifications = {};

  Future<void> initialize() async {
    if (_isInitialized) return;
    print('Initializing background service...');

    await _initNotification();

    try {
      _subscription = client.channel('courier-notifications').onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notification_courier',
            callback: (payload) {
              if (payload.newRecord != null) {
                final newNotification =
                    payload.newRecord as Map<String, dynamic>;
                if (newNotification['status'] == 'unread') {
                  final notificationId = newNotification['id'] as String;
                  if (!_processedNotifications.contains(notificationId)) {
                    _processedNotifications.add(notificationId);
                    _showLocalNotification(newNotification);
                  }
                }
              }
            },
          );

      await _subscription.subscribe();
      _isInitialized = true;
    } catch (e) {
      print('Error in background service: $e');
    }
  }

  Future<void> _initNotification() async {
    AndroidInitializationSettings initializationSettingsAndroid =
        const AndroidInitializationSettings('@mipmap/ic_launcher');

    var initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) async {
        if (notificationResponse.payload != null) {
          Get.toNamed(notificationResponse.payload!);
        }
      },
    );
  }

  void _showLocalNotification(Map<String, dynamic> notification) async {
    final notificationId =
        int.parse(notification['id'].toString().substring(0, 9));

    const androidNotificationDetails = AndroidNotificationDetails(
      'courier_channel',
      'Courier Notifications',
      channelDescription: 'Channel for courier notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iOSNotificationDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iOSNotificationDetails,
    );

    await notificationsPlugin.show(
      notificationId,
      'Pesanan Baru',
      notification['message'] ?? 'Ada pesanan baru untuk Anda',
      notificationDetails,
      payload: '/courier/notifications',
    );
  }

  void dispose() {
    if (_isInitialized) {
      _subscription.unsubscribe();
      _processedNotifications.clear();
      _isInitialized = false;
    }
  }
}
