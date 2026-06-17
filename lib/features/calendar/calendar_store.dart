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
  final _loading = ref<bool>(false);

  Ref<List<CalendarEventsRecord>> get events => _events;
  Ref<bool> get loading => _loading;

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
