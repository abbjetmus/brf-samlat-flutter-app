import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';

/// Handles Firebase Cloud Messaging: permissions, token management,
/// foreground/background notifications, and PocketBase token registration.
///
/// Server side: the API's secured `POST /send-notification` pushes to the
/// tokens stored in the `push_tokens` collection (fields: `user`, `token`).
class NotificationService {
  static const String _channelId = 'brf_samlat_notifications';
  static const String _channelName = 'BRF Samlat';

  final PocketBase _pb;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _currentTokenRecordId;
  GoRouter? _router;

  NotificationService(this._pb);

  /// Set the router so notification taps can navigate.
  void setRouter(GoRouter router) {
    _router = router;
  }

  Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Notifikationer från BRF Samlat',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    _messaging.onTokenRefresh.listen(_onTokenRefresh);
  }

  Future<void> registerToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      try {
        final existing = await _pb.collection('push_tokens').getFullList(
              filter: 'user = "$userId" && token = "$token"',
            );
        if (existing.isNotEmpty) {
          _currentTokenRecordId = existing.first.id;
          return; // Token already registered
        }
      } catch (e) {
        debugPrint('NotificationService: Error checking existing token: $e');
      }

      final record = await _pb.collection('push_tokens').create(body: {
        'user': userId,
        'token': token,
      });
      _currentTokenRecordId = record.id;
      debugPrint('NotificationService: Token registered for user $userId');
    } catch (e) {
      debugPrint('NotificationService: Error registering token: $e');
    }
  }

  Future<void> unregisterToken() async {
    try {
      if (_currentTokenRecordId != null) {
        await _pb.collection('push_tokens').delete(_currentTokenRecordId!);
        _currentTokenRecordId = null;
        debugPrint('NotificationService: Token unregistered');
      }
    } catch (e) {
      debugPrint('NotificationService: Error unregistering token: $e');
    }
  }

  void _onTokenRefresh(String newToken) async {
    if (_currentTokenRecordId != null) {
      try {
        await _pb.collection('push_tokens').update(
          _currentTokenRecordId!,
          body: {'token': newToken},
        );
        debugPrint('NotificationService: Token refreshed');
      } catch (e) {
        debugPrint('NotificationService: Error refreshing token: $e');
      }
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data['url'],
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final deepLink = message.data['url'];
    if (deepLink != null && deepLink.isNotEmpty) {
      _navigateTo(deepLink);
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      _navigateTo(payload);
    }
  }

  void _navigateTo(String path) {
    if (_router == null) return;
    try {
      _router!.go(path);
    } catch (e) {
      debugPrint('NotificationService: Navigation error: $e');
    }
  }
}
