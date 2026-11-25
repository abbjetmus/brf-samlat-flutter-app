import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketbase/pocketbase.dart';
import '../utils/notification_link_utils.dart';

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

  GoRouter? _router;

  /// A notification opened before the router was set (cold start from a
  /// notification); navigated to in [setRouter].
  String? _pendingLink;

  // --- Token registration state ---
  //
  // Registration is best-effort but must not silently give up: on iOS
  // getToken() throws until APNs has handed the app its device token, which
  // can take a while after launch. So registration waits for initialize(),
  // waits (bounded) for the APNs token, upserts the (user, token) row, and
  // is retried on app resume and on FCM token refresh.

  /// The signed-in user we register for; null when logged out.
  String? _userId;

  /// The FCM token and push_tokens row last registered for [_userId].
  String? _currentToken;
  String? _currentTokenRecordId;
  DateTime? _lastRegisteredAt;

  /// The user's PocketBase auth token, kept so logout can still delete the
  /// row: the app clears the auth store before [unregisterToken] runs, and
  /// push_tokens only lets the owner delete their row.
  String? _authToken;

  /// Serializes register/refresh/unregister so they never interleave.
  Future<void> _queue = Future.value();

  Future<void>? _initFuture;
  AppLifecycleListener? _lifecycleListener;

  /// Don't re-check the registration on every resume.
  static const Duration _resumeInterval = Duration(minutes: 5);

  late final StreamController<void> _unseenMayHaveChangedController =
      StreamController<void>.broadcast();

  /// Fires when the unseen-notification count may be out of date: a push
  /// arrived while the app was open, or the app came back to the foreground
  /// (pushes received meanwhile).
  Stream<void> get unseenMayHaveChanged =>
      _unseenMayHaveChangedController.stream;

  NotificationService(this._pb) {
    _pb.authStore.onChange.listen((event) {
      if (_pb.authStore.isValid && event.token.isNotEmpty) {
        _authToken = event.token;
      }
    });
  }

  /// Set the router so notification taps can navigate.
  void setRouter(GoRouter router) {
    _router = router;
    final pending = _pendingLink;
    _pendingLink = null;
    if (pending != null) _navigateTo(pending);
  }

  /// Safe to call more than once; later calls return the first run.
  Future<void> initialize() => _initFuture ??= _initialize();

  Future<void> _initialize() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('NotificationService: Error requesting permission: $e');
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
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
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    _messaging.onTokenRefresh.listen(_onTokenRefresh);

    _lifecycleListener ??= AppLifecycleListener(onResume: _onResume);
  }

  /// Registers this device's FCM token for [userId]. Waits for
  /// [initialize] (and on iOS for the APNs token), then upserts the
  /// (user, token) row. Never throws.
  Future<void> registerToken(String userId) {
    _userId = userId;
    _authToken = _pb.authStore.isValid ? _pb.authStore.token : _authToken;
    return _enqueue(() => _register(userId, null));
  }

  /// Removes this device's token for the user who was signed in. Works after
  /// the auth store has been cleared (see [_authToken]). Never throws.
  Future<void> unregisterToken() {
    final userId = _userId;
    final authToken = _authToken;
    // Stop pending registrations/refreshes for this user right away.
    _userId = null;
    _authToken = null;
    return _enqueue(() async {
      final token = _currentToken;
      final recordId = _currentTokenRecordId;
      _currentToken = null;
      _currentTokenRecordId = null;
      _lastRegisteredAt = null;
      if (userId == null || authToken == null || authToken.isEmpty) return;

      // A throwaway client with the signed-out user's token.
      final pb = PocketBase(
        _pb.baseURL,
        authStore: AuthStore()..save(authToken, null),
      );
      try {
        final ids = <String>{?recordId};
        if (token != null) {
          final rows = await pb
              .collection('push_tokens')
              .getFullList(
                filter: pb.filter('user = {:user} && token = {:token}', {
                  'user': userId,
                  'token': token,
                }),
              );
          ids.addAll(rows.map((r) => r.id));
        }
        for (final id in ids) {
          try {
            await pb.collection('push_tokens').delete(id);
          } catch (e) {
            debugPrint('NotificationService: Error deleting token row: $e');
          }
        }
        debugPrint('NotificationService: Token unregistered');
      } catch (e) {
        debugPrint('NotificationService: Error unregistering token: $e');
      }
    });
  }

  Future<void> _enqueue(Future<void> Function() task) {
    final next = _queue.then((_) => task()).catchError((Object e) {
      debugPrint('NotificationService: $e');
    });
    _queue = next;
    return next;
  }

  void _onResume() {
    _unseenMayHaveChangedController.add(null);
    final userId = _userId;
    if (userId == null || !_pb.authStore.isValid) return;
    final last = _lastRegisteredAt;
    final registered = _currentTokenRecordId != null;
    if (registered &&
        last != null &&
        DateTime.now().difference(last) < _resumeInterval) {
      return;
    }
    _enqueue(() => _register(userId, null));
  }

  void _onTokenRefresh(String newToken) {
    final userId = _userId;
    if (userId == null) return;
    _enqueue(() => _register(userId, newToken));
  }

  Future<void> _register(String userId, String? knownToken) async {
    try {
      await initialize();
    } catch (e) {
      // Local notification setup failing must not stop push registration.
      debugPrint('NotificationService: initialize failed: $e');
    }
    if (_userId != userId) return; // Logged out meanwhile.

    final token = knownToken ?? await _fetchToken();
    if (token == null || token.isEmpty) {
      debugPrint('NotificationService: No FCM token yet; will retry on resume');
      return;
    }
    if (_userId != userId || !_pb.authStore.isValid) return;

    try {
      await _upsert(userId, token);
      _lastRegisteredAt = DateTime.now();
      debugPrint('NotificationService: Token registered for user $userId');
    } catch (e) {
      debugPrint('NotificationService: Error registering token: $e');
    }
  }

  /// The FCM token, or null. On iOS FCM can't produce one before APNs has
  /// delivered the device token, so wait for that with a bounded backoff
  /// (~30 s); getToken() itself is retried a few times as well.
  Future<String?> _fetchToken() async {
    const delays = [1, 2, 3, 5, 8, 13];

    if (Platform.isIOS) {
      String? apns;
      for (var i = 0; i <= delays.length; i++) {
        try {
          apns = await _messaging.getAPNSToken();
        } catch (e) {
          debugPrint('NotificationService: getAPNSToken failed: $e');
        }
        if (apns != null || i == delays.length) break;
        await Future<void>.delayed(Duration(seconds: delays[i]));
      }
      if (apns == null) return null;
    }

    for (var i = 0; i < 4; i++) {
      try {
        final token = await _messaging.getToken();
        if (token != null && token.isNotEmpty) return token;
      } catch (e) {
        debugPrint('NotificationService: getToken failed: $e');
      }
      if (i < 3) await Future<void>.delayed(Duration(seconds: delays[i + 1]));
    }
    return null;
  }

  /// One row per (user, token): update it if it exists, otherwise move this
  /// device's previous row to the new token (refresh), otherwise create one.
  /// The server removes other users' rows for the same token
  /// (brf-samlat-pb/pb_hooks/collections/push_tokens.pb.js).
  Future<void> _upsert(String userId, String token) async {
    final collection = _pb.collection('push_tokens');
    final existing = await collection.getFullList(
      filter: _pb.filter('user = {:user} && token = {:token}', {
        'user': userId,
        'token': token,
      }),
      sort: '-updated',
    );

    if (existing.isNotEmpty) {
      final keep = existing.first;
      // Touch the row so `updated` shows the device is still in use.
      await collection.update(keep.id, body: {'token': token});
      for (final dup in existing.skip(1)) {
        try {
          await collection.delete(dup.id);
        } catch (_) {}
      }
      _currentTokenRecordId = keep.id;
      _currentToken = token;
      return;
    }

    final previousId = _currentTokenRecordId;
    if (previousId != null && _currentToken != token) {
      try {
        await collection.update(previousId, body: {'token': token});
        _currentToken = token;
        return;
      } catch (e) {
        // Row gone (e.g. removed by the server) — create a new one below.
        debugPrint('NotificationService: Previous token row not updated: $e');
      }
    }

    final record = await collection.create(
      body: {'user': userId, 'token': token},
    );
    _currentTokenRecordId = record.id;
    _currentToken = token;
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _unseenMayHaveChangedController.add(null);
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

  void _navigateTo(String link) {
    if (_router == null) {
      _pendingLink = link;
      return;
    }
    try {
      // Notification payloads carry full universal-link URLs
      // (https://brfsamlat.se/app/posts/detail/X), bare in-app paths, or
      // malformed values. resolvePath returns a safe absolute path (the
      // router's authGuard strips any /app prefix) or null when unusable.
      final path = NotificationLinkUtils.resolvePath(link);
      if (path == null) return;
      _router!.go(path);
    } catch (e) {
      debugPrint('NotificationService: Navigation error: $e');
    }
  }
}
