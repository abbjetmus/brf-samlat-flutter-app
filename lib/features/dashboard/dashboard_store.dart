import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../../core/utils/dashboard_widgets.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/text_utils.dart';
import '../auth/auth_store.dart' as auth;
import 'widgets/dashboard_tasks.dart';
import 'widgets/subscription_banner.dart';

class DashboardStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  DashboardStore(this._pb, this._authStore);

  final _notifications = ref<List<UserNotificationsRecord>>([]);
  final _notSeenCount = ref<int>(0);
  final _generalInfoList = ref<List<PostsRecord>>([]);
  final _loading = ref<bool>(false);
  final _widgetLists = ref<Map<String, List<DashboardListEntry>>>({});
  final _tasks = ref<DashboardTasks>(const DashboardTasks());
  final _subscription = ref<SubscriptionStatus?>(null);

  Ref<List<UserNotificationsRecord>> get notifications => _notifications;
  Ref<int> get notSeenCount => _notSeenCount;
  Ref<List<PostsRecord>> get generalInfoList => _generalInfoList;
  Ref<bool> get loading => _loading;

  /// Rows per dashboard list (posts, calendar_events).
  Ref<Map<String, List<DashboardListEntry>>> get widgetLists => _widgetLists;

  /// "För dig" och "Kräver åtgärd" (widgets/dashboard_tasks.dart).
  Ref<DashboardTasks> get tasks => _tasks;

  /// Föreningens abonnemang, för bannern (widgets/subscription_banner.dart).
  Ref<SubscriptionStatus?> get subscription => _subscription;

  Future<void> loadSubscription() async {
    try {
      final res = await _pb.send('/api/subscription');
      if (res is Map) {
        _subscription.value = SubscriptionStatus.fromJson(
          Map<String, dynamic>.from(res),
        );
      }
    } catch (e) {
      // Ett äldre PB utan endpointen, eller nätverksfel: ingen banner.
      debugPrint('DashboardStore: Error fetching subscription: $e');
    }
  }

  Future<void> loadTasks() async {
    try {
      final res = await _pb.send('/api/dashboard/tasks');
      if (res is Map) {
        _tasks.value = DashboardTasks.fromJson(Map<String, dynamic>.from(res));
      }
    } catch (e) {
      debugPrint('DashboardStore: Error fetching tasks: $e');
    }
  }

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

  // --- Startsidan ------------------------------------------------------------

  static const int _listSize = 5;

  /// Loads the data for [widgets] only (the ones the viewer can see).
  /// Loads the rows of the dashboard lists (core/utils/dashboard_widgets.dart).
  Future<void> loadLists(List<DashboardWidgetDefinition> lists) async {
    final assocId = _authStore.association.value?.id ?? '';
    if (assocId.isEmpty) return;
    await Future.wait(lists.map((d) => _loadList(d, assocId)));
  }

  Future<void> _loadList(DashboardWidgetDefinition def, String assocId) async {
    try {
      final isPosts = def.type == 'posts';
      final res = await _pb
          .collection(isPosts ? Collections.posts : Collections.calendarEvents)
          .getList(
            page: 1,
            perPage: _listSize,
            filter: isPosts
                ? 'association="$assocId" && pin_as_general_info=false'
                : 'association="$assocId" && end_at >= @now',
            sort: isPosts ? '-created' : 'start_at',
            skipTotal: true,
          );
      final entries = res.items.map((r) {
        final json = r.toJson();
        final id = json['id'] as String? ?? '';
        String str(String key) => (json[key] as String? ?? '').trim();
        if (isPosts) {
          final published = str('published_at');
          final date = published.isNotEmpty ? published : str('created');
          return DashboardListEntry(
            id: id,
            title: str('title'),
            subtitle: AppDateUtils.friendlyDay(date),
            path: '/posts/detail/$id',
            dateIso: date,
            detail: TextUtils.excerpt(str('description'), maxLength: 110),
          );
        }
        return DashboardListEntry(
          id: id,
          title: str('title'),
          subtitle: [
            AppDateUtils.formatDateTime(str('start_at')),
            str('location'),
          ].where((s) => s.isNotEmpty).join(' · '),
          path: def.route,
          dateIso: str('start_at'),
          detail: [
            AppDateUtils.eventWhen(str('start_at'), str('end_at')),
            str('location'),
          ].where((s) => s.isNotEmpty).join(' · '),
        );
      }).toList();
      _widgetLists.value = {..._widgetLists.value, def.type: entries};
    } catch (e) {
      debugPrint('DashboardStore: Error fetching ${def.type} list: $e');
    }
  }
}
