import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../../core/utils/dashboard_widgets.dart';
import '../../core/utils/date_utils.dart';
import '../auth/auth_store.dart' as auth;

class DashboardStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  DashboardStore(this._pb, this._authStore);

  final _notifications = ref<List<UserNotificationsRecord>>([]);
  final _notSeenCount = ref<int>(0);
  final _generalInfoList = ref<List<PostsRecord>>([]);
  final _loading = ref<bool>(false);
  final _widgetCounts = ref<Map<String, int>>({});
  final _widgetLists = ref<Map<String, List<DashboardListEntry>>>({});

  Ref<List<UserNotificationsRecord>> get notifications => _notifications;
  Ref<int> get notSeenCount => _notSeenCount;
  Ref<List<PostsRecord>> get generalInfoList => _generalInfoList;
  Ref<bool> get loading => _loading;

  /// Count per widget type (startsidan, see core/utils/dashboard_widgets.dart).
  Ref<Map<String, int>> get widgetCounts => _widgetCounts;

  /// Rows per list widget type.
  Ref<Map<String, List<DashboardListEntry>>> get widgetLists => _widgetLists;

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
  Future<void> loadWidgets(List<DashboardWidget> widgets) async {
    final assocId = _authStore.association.value?.id ?? '';
    if (assocId.isEmpty) return;
    await Future.wait(
      widgets.map(
        (w) => w.format == DashboardWidgetFormat.count
            ? _loadCount(w.type, assocId)
            : _loadList(w.type, assocId),
      ),
    );
  }

  /// Collection + filter per type. Upcoming = not ended yet (`@now`).
  ({String collection, String filter}) _query(String type, String assocId) {
    final own = 'association="$assocId"';
    switch (type) {
      case 'residences':
        return (collection: Collections.residences, filter: own);
      case 'parking_lots':
        return (collection: Collections.parkingLots, filter: own);
      case 'users':
        return (collection: Collections.users, filter: own);
      case 'issues':
        return (
          collection: Collections.issuesView,
          filter: '$own && is_resolved=false',
        );
      case 'posts':
        return (
          collection: Collections.posts,
          filter: '$own && pin_as_general_info=false',
        );
      case 'calendar_events':
        return (
          collection: Collections.calendarEvents,
          filter: '$own && end_at >= @now',
        );
      case 'place_bookings':
        return (
          collection: Collections.placeBookings,
          filter:
              'place.association="$assocId" && end_at >= @now && is_block=false && approval_status!="rejected"',
        );
      case 'gadget_bookings':
        return (
          collection: Collections.gadgetBookings,
          filter:
              'gadget.association="$assocId" && end_at >= @now && is_block=false',
        );
      case 'board_meetings':
        return (
          collection: Collections.boardMeetings,
          filter: '$own && end_at >= @now',
        );
      default:
        throw ArgumentError('Unknown dashboard widget type: $type');
    }
  }

  Future<void> _loadCount(String type, String assocId) async {
    try {
      final q = _query(type, assocId);
      final res = await _pb
          .collection(q.collection)
          .getList(page: 1, perPage: 1, filter: q.filter, skipTotal: false);
      _widgetCounts.value = {..._widgetCounts.value, type: res.totalItems};
    } catch (e) {
      debugPrint('DashboardStore: Error fetching $type count: $e');
    }
  }

  Future<void> _loadList(String type, String assocId) async {
    try {
      final def = dashboardWidgetDefinitions[type]!;
      final q = _query(type, assocId);
      // Issues: the latest, open or resolved. Everything else: upcoming first.
      final filter = type == 'issues' ? 'association="$assocId"' : q.filter;
      final sort = (type == 'issues' || type == 'posts') ? '-created' : 'start_at';
      final expand = type == 'place_bookings'
          ? 'place'
          : type == 'gadget_bookings'
          ? 'gadget'
          : null;
      final res = await _pb
          .collection(q.collection)
          .getList(
            page: 1,
            perPage: _listSize,
            filter: filter,
            sort: sort,
            expand: expand,
            skipTotal: true,
          );
      final entries = res.items.map((r) {
        final json = r.toJson();
        return _toEntry(type, def, json);
      }).toList();
      _widgetLists.value = {..._widgetLists.value, type: entries};
    } catch (e) {
      debugPrint('DashboardStore: Error fetching $type list: $e');
    }
  }

  DashboardListEntry _toEntry(
    String type,
    DashboardWidgetDefinition def,
    Map<String, dynamic> json,
  ) {
    final id = json['id'] as String? ?? '';
    String str(String key) => (json[key] as String? ?? '').trim();
    String expanded(String relation, String field) {
      final expand = json['expand'];
      if (expand is Map && expand[relation] is Map) {
        return ((expand[relation] as Map)[field] as String? ?? '').trim();
      }
      return '';
    }

    switch (type) {
      case 'issues':
        final resolved = json['is_resolved'] == true;
        return DashboardListEntry(
          id: id,
          title: str('title'),
          subtitle: AppDateUtils.formatDate(str('created')),
          path: '/issues/detail/$id',
          icon: resolved ? Icons.check : Icons.report_problem_outlined,
          color: resolved ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
          chipText: resolved ? 'Löst' : 'Öppen',
          chipColor: resolved ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
        );
      case 'posts':
        final published = str('published_at');
        return DashboardListEntry(
          id: id,
          title: str('title'),
          subtitle: AppDateUtils.formatDate(
            published.isNotEmpty ? published : str('created'),
          ),
          path: '/posts/detail/$id',
        );
      case 'calendar_events':
        return DashboardListEntry(
          id: id,
          title: str('title'),
          subtitle: [
            AppDateUtils.formatDateTime(str('start_at')),
            str('location'),
          ].where((s) => s.isNotEmpty).join(' · '),
          path: def.route,
        );
      case 'place_bookings':
        final place = str('place');
        final pending = str('approval_status') == 'pending';
        return DashboardListEntry(
          id: id,
          title: _firstNonEmpty([expanded('place', 'name'), str('title')]),
          subtitle: AppDateUtils.formatDateTime(str('start_at')),
          path: place.isNotEmpty ? '/places/detail/$place' : def.route,
          chipText: pending ? 'Väntar' : null,
          chipColor: pending ? const Color(0xFFF59E0B) : null,
        );
      case 'gadget_bookings':
        final gadget = str('gadget');
        return DashboardListEntry(
          id: id,
          title: _firstNonEmpty([expanded('gadget', 'name'), str('title')]),
          subtitle: AppDateUtils.formatDateTime(str('start_at')),
          path: gadget.isNotEmpty ? '/gadgets/detail/$gadget' : def.route,
        );
      case 'board_meetings':
        return DashboardListEntry(
          id: id,
          title: 'Styrelsemöte ${AppDateUtils.formatDateTime(str('start_at'))}',
          subtitle: [
            str('street_address'),
            str('locality'),
          ].where((s) => s.isNotEmpty).join(', '),
          path: '/board/detail/$id',
        );
      default:
        return DashboardListEntry(id: id, title: str('title'), path: def.route);
    }
  }

  static String _firstNonEmpty(List<String> values) =>
      values.firstWhere((v) => v.isNotEmpty, orElse: () => 'Bokning');
}
