import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../auth/auth_store.dart' as auth;

class CalendarStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  CalendarStore(this._pb, this._authStore);

  final _events = ref<List<CalendarEventsRecord>>([]);
  final _postEvents = ref<List<PostsRecord>>([]);
  final _loading = ref<bool>(false);

  Ref<List<CalendarEventsRecord>> get events => _events;
  Ref<bool> get loading => _loading;

  /// Calendar events merged with post-derived events (posts that have
  /// `add_to_calendar` enabled), sorted chronologically. Post entries are
  /// read-only here — they're managed under Inlägg.
  late final _items = computed<List<CalendarItem>>(() {
    final list = <CalendarItem>[];
    for (final e in _events.value) {
      final item = CalendarItem.fromEvent(e);
      if (item != null) list.add(item);
    }
    for (final p in _postEvents.value) {
      final item = CalendarItem.fromPost(p);
      if (item != null) list.add(item);
    }
    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  });

  ReadonlyRef<List<CalendarItem>> get items => _items;

  Future<bool> getAllEvents() async {
    _loading.value = true;
    try {
      final assocId = _authStore.association.value?.id ?? '';
      if (assocId.isEmpty) return false;

      final records = await _pb.collection(Collections.calendarEvents).getFullList(
        filter: 'association="$assocId"',
        sort: 'start_at',
      );
      _events.value = records
          .map((r) => CalendarEventsRecord.fromJson(r.toJson()))
          .toList();

      // Posts flagged for the calendar are shown alongside calendar events.
      final postRecords = await _pb.collection(Collections.posts).getFullList(
        filter: 'association="$assocId" && add_to_calendar=true',
        sort: 'start_at',
      );
      _postEvents.value = postRecords
          .map((r) => PostsRecord.fromJson(r.toJson()))
          .toList();
      return true;
    } catch (e) {
      debugPrint('CalendarStore: Error fetching events: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> createEvent({
    required String title,
    String? description,
    required String startAt,
    required String endAt,
    String color = '#2196F3',
    String? eventType,
  }) async {
    _loading.value = true;
    try {
      final assocId = _authStore.association.value?.id ?? '';
      final userId = _authStore.currentUser.value?.id ?? '';

      await _pb.collection(Collections.calendarEvents).create(body: {
        'title': title,
        'description': description ?? '',
        'association': assocId,
        'user': userId,
        'start_at': startAt,
        'end_at': endAt,
        'color': color,
        'event_type': eventType ?? '',
      });

      await getAllEvents();
      return true;
    } catch (e) {
      debugPrint('CalendarStore: Error creating event: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> updateEvent({
    required String id,
    required String title,
    String? description,
    required String startAt,
    required String endAt,
    String? color,
    String? eventType,
  }) async {
    _loading.value = true;
    try {
      final body = <String, dynamic>{
        'title': title,
        'description': description ?? '',
        'start_at': startAt,
        'end_at': endAt,
      };
      if (color != null) body['color'] = color;
      if (eventType != null) body['event_type'] = eventType;

      await _pb.collection(Collections.calendarEvents).update(id, body: body);
      await getAllEvents();
      return true;
    } catch (e) {
      debugPrint('CalendarStore: Error updating event: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> deleteEvent(String id) async {
    _loading.value = true;
    try {
      await _pb.collection(Collections.calendarEvents).delete(id);
      await getAllEvents();
      return true;
    } catch (e) {
      debugPrint('CalendarStore: Error deleting event: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  static Color parseColor(String colorStr) {
    try {
      final hex = colorStr.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF2196F3);
    }
  }
}

/// A unified calendar entry, derived either from a [CalendarEventsRecord] or
/// from a [PostsRecord] flagged with `add_to_calendar`.
class CalendarItem {
  final String id;
  final String title;
  final String description;
  final DateTime start;
  final DateTime end;
  final Color color;

  /// True when this entry comes from a post (read-only in the calendar).
  final bool isPost;

  const CalendarItem({
    required this.id,
    required this.title,
    required this.description,
    required this.start,
    required this.end,
    required this.color,
    required this.isPost,
  });

  /// Fixed colour for post-derived calendar entries (purple).
  static const String postColor = '#9C27B0';

  static DateTime? _parse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    return DateTime.tryParse(iso)?.toLocal();
  }

  static CalendarItem? fromEvent(CalendarEventsRecord e) {
    final start = _parse(e.startAt);
    final end = _parse(e.endAt);
    if (start == null || end == null) return null;
    return CalendarItem(
      id: e.id,
      title: e.title,
      description: e.description ?? '',
      start: start,
      end: end,
      color: CalendarStore.parseColor(e.color),
      isPost: false,
    );
  }

  static CalendarItem? fromPost(PostsRecord p) {
    final start = _parse(p.startAt);
    final end = _parse(p.endAt);
    if (start == null || end == null) return null;
    return CalendarItem(
      id: p.id,
      title: p.title,
      description: p.description,
      start: start,
      end: end,
      color: CalendarStore.parseColor(postColor),
      isPost: true,
    );
  }
}
