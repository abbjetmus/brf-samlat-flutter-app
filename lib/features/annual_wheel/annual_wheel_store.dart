import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../auth/auth_store.dart' as auth;

/// Category metadata shared by the wheel and the list. Mirrors the web
/// `ANNUAL_WHEEL_CATEGORIES`.
class AnnualWheelCategory {
  final String value;
  final String title;
  final Color color;
  final IconData icon;

  const AnnualWheelCategory(this.value, this.title, this.color, this.icon);
}

const annualWheelCategories = <AnnualWheelCategory>[
  AnnualWheelCategory(
    'board',
    'Styrelse',
    Color(0xFF2ED188),
    Icons.groups_outlined,
  ),
  AnnualWheelCategory(
    'finance',
    'Ekonomi',
    Color(0xFF3B82F6),
    Icons.payments_outlined,
  ),
  AnnualWheelCategory(
    'meeting',
    'Stämma',
    Color(0xFFA855F7),
    Icons.gavel_outlined,
  ),
  AnnualWheelCategory(
    'property',
    'Fastighet',
    Color(0xFFF59E0B),
    Icons.apartment_outlined,
  ),
  AnnualWheelCategory('other', 'Övrigt', Color(0xFF64748B), Icons.more_horiz),
];

AnnualWheelCategory categoryMeta(String? value) =>
    annualWheelCategories.firstWhere(
      (c) => c.value == value,
      orElse: () => annualWheelCategories.last,
    );

const monthNames = [
  'Januari',
  'Februari',
  'Mars',
  'April',
  'Maj',
  'Juni',
  'Juli',
  'Augusti',
  'September',
  'Oktober',
  'November',
  'December',
];

/// Föreningens årshjul: återkommande aktiviteter per månad och avbockning per
/// år (en rad i annual_wheel_completions per aktivitet och år).
class AnnualWheelStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  AnnualWheelStore(this._pb, this._authStore);

  final _activities = ref<List<AnnualWheelActivitiesRecord>>([]);
  final _completions = ref<List<AnnualWheelCompletionsRecord>>([]);
  final _loading = ref<bool>(false);
  final _year = ref<int>(DateTime.now().year);

  Ref<List<AnnualWheelActivitiesRecord>> get activities => _activities;

  /// Completions for [year].
  Ref<List<AnnualWheelCompletionsRecord>> get completions => _completions;
  Ref<bool> get loading => _loading;
  Ref<int> get year => _year;

  List<AnnualWheelActivitiesRecord> get sortedActivities => [
    ..._activities.value,
  ]..sort((a, b) => a.month != b.month ? a.month - b.month : a.day - b.day);

  AnnualWheelCompletionsRecord? completionFor(String activityId) =>
      _completions.value.where((c) => c.activity == activityId).firstOrNull;

  String get _assocId => _authStore.association.value?.id ?? '';

  Future<bool> load([int? year]) async {
    if (year != null) _year.value = year;
    final assocId = _assocId;
    if (assocId.isEmpty) return false;
    _loading.value = true;
    try {
      final results = await Future.wait([
        _pb
            .collection(Collections.annualWheelActivities)
            .getFullList(
              filter: _pb.filter('association = {:a}', {'a': assocId}),
            ),
        _pb
            .collection(Collections.annualWheelCompletions)
            .getFullList(
              filter: _pb.filter('association = {:a} && year = {:y}', {
                'a': assocId,
                'y': _year.value,
              }),
            ),
      ]);
      _activities.value = results[0]
          .map((r) => AnnualWheelActivitiesRecord.fromJson(r.toJson()))
          .toList();
      _completions.value = results[1]
          .map((r) => AnnualWheelCompletionsRecord.fromJson(r.toJson()))
          .toList();
      return true;
    } catch (e) {
      debugPrint('AnnualWheelStore: Error loading: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  /// Creates the activity when [id] is null, otherwise updates it.
  Future<bool> save({
    String? id,
    required String title,
    required String description,
    required int month,
    required int day,
    required String category,
    String? responsible,
    required int reminderDaysBefore,
  }) async {
    final body = <String, dynamic>{
      'association': _assocId,
      'title': title,
      'description': description,
      'month': month,
      'day': day,
      'category': category,
      'responsible': responsible ?? '',
      'reminder_days_before': reminderDaysBefore,
    };
    try {
      final collection = _pb.collection(Collections.annualWheelActivities);
      final record = id == null
          ? await collection.create(body: body)
          : await collection.update(id, body: body);
      final saved = AnnualWheelActivitiesRecord.fromJson(record.toJson());
      _activities.value = id == null
          ? [..._activities.value, saved]
          : [for (final a in _activities.value) a.id == id ? saved : a];
      return true;
    } catch (e) {
      debugPrint('AnnualWheelStore: Error saving activity: $e');
      return false;
    }
  }

  Future<bool> remove(String id) async {
    try {
      await _pb.collection(Collections.annualWheelActivities).delete(id);
      _activities.value = _activities.value.where((a) => a.id != id).toList();
      _completions.value = _completions.value
          .where((c) => c.activity != id)
          .toList();
      return true;
    } catch (e) {
      debugPrint('AnnualWheelStore: Error deleting activity: $e');
      return false;
    }
  }

  Future<bool> setCompleted(String activityId, bool completed) async {
    try {
      final existing = completionFor(activityId);
      if (!completed && existing != null) {
        await _pb
            .collection(Collections.annualWheelCompletions)
            .delete(existing.id);
        _completions.value = _completions.value
            .where((c) => c.id != existing.id)
            .toList();
      } else if (completed && existing == null) {
        // completed_by/completed_at sätts av servern.
        final record = await _pb
            .collection(Collections.annualWheelCompletions)
            .create(
              body: {
                'activity': activityId,
                'year': _year.value,
                'association': _assocId,
              },
            );
        _completions.value = [
          ..._completions.value,
          AnnualWheelCompletionsRecord.fromJson(record.toJson()),
        ];
      }
      return true;
    } catch (e) {
      debugPrint('AnnualWheelStore: Error toggling completion: $e');
      return false;
    }
  }

  Future<bool> seedDefaults() async {
    try {
      await _pb.send('/api/annual-wheel/seed-defaults', method: 'POST');
      return load();
    } catch (e) {
      debugPrint('AnnualWheelStore: Error seeding defaults: $e');
      return false;
    }
  }
}
