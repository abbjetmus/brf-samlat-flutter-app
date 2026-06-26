import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../auth/auth_store.dart' as auth;

class DashboardStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  DashboardStore(this._pb, this._authStore);

  final _notifications = ref<List<UserNotificationsRecord>>([]);
  final _notSeenCount = ref<int>(0);
  final _generalInfoList = ref<List<PostsRecord>>([]);
  final _loading = ref<bool>(false);

  Ref<List<UserNotificationsRecord>> get notifications => _notifications;
  Ref<int> get notSeenCount => _notSeenCount;
  Ref<List<PostsRecord>> get generalInfoList => _generalInfoList;
  Ref<bool> get loading => _loading;

  Future<bool> getNotifications() async {
    final user = _authStore.currentUser.value;
    if (user == null) return false;

    try {
      final records = await _pb
          .collection(Collections.userNotifications)
          .getList(
            page: 1,
            perPage: 50,
            filter: 'user="${user.id}"',
            sort: '-created',
          );
      _notifications.value = records.items
          .map((r) => UserNotificationsRecord.fromJson(r.toJson()))
          .toList();
      return true;
    } catch (e) {
      debugPrint('DashboardStore: Error fetching notifications: $e');
      return false;
    }
  }

  Future<bool> getNotSeenCount() async {
    final user = _authStore.currentUser.value;
    if (user == null) return false;

    try {
      final records = await _pb
          .collection(Collections.userNotificationsNotSeenCountView)
          .getList(page: 1, perPage: 1, filter: 'user="${user.id}"');
      if (records.items.isNotEmpty) {
        final record = UserNotificationsNotSeenCountViewRecord.fromJson(
          records.items.first.toJson(),
        );
        _notSeenCount.value = record.notSeenCount;
      }
      return true;
    } catch (e) {
      debugPrint('DashboardStore: Error fetching not seen count: $e');
      return false;
    }
  }

  Future<bool> markNotificationAsSeen(String notificationId) async {
    try {
      await _pb
          .collection(Collections.userNotifications)
          .update(notificationId, body: {'seen': true});
      await getNotifications();
      await getNotSeenCount();
      return true;
    } catch (e) {
      debugPrint('DashboardStore: Error marking notification: $e');
      return false;
    }
  }

  /// Remove a notification. Updates local state optimistically so the list
  /// reflects the swipe immediately; on failure the row is restored.
  Future<bool> deleteNotification(String notificationId) async {
    final previous = _notifications.value;
    final removed = previous.firstWhere(
      (n) => n.id == notificationId,
      orElse: () => previous.first,
    );
    _notifications.value = previous
        .where((n) => n.id != notificationId)
        .toList();
    if (!removed.seen) {
      _notSeenCount.value = (_notSeenCount.value - 1).clamp(0, 1 << 31);
    }

    try {
      await _pb
          .collection(Collections.userNotifications)
          .delete(notificationId);
      return true;
    } catch (e) {
      debugPrint('DashboardStore: Error deleting notification: $e');
      _notifications.value = previous;
      if (!removed.seen) {
        _notSeenCount.value = _notSeenCount.value + 1;
      }
      return false;
    }
  }

  Future<bool> getGeneralInfoList() async {
    final assocId = _authStore.association.value?.id ?? '';
    if (assocId.isEmpty) return false;

    try {
      final records = await _pb
          .collection(Collections.posts)
          .getFullList(
            filter: 'association="$assocId" && pin_as_general_info=true',
          );
      _generalInfoList.value = records
          .map((r) => PostsRecord.fromJson(r.toJson()))
          .toList();
      return true;
    } catch (e) {
      debugPrint('DashboardStore: Error fetching general info: $e');
      return false;
    }
  }
}
