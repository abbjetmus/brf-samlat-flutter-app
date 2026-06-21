import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';
import '../auth/auth_store.dart' as auth;

/// Reads and persists the user's push notification preferences in the
/// PocketBase `user_notification_settings` collection (one record per user).
///
/// Opt-out semantics: when no record exists yet the user receives every
/// category, so on first load we create a record with all categories enabled.
/// The API (`/send-notification`) skips a category only when its boolean is
/// explicitly `false`.
class NotificationSettingsStore {
  static const String _collection = 'user_notification_settings';

  final PocketBase _pb;
  final auth.AuthStore _authStore;

  final Ref<bool> loading = Ref(true);
  final Ref<bool> posts = Ref(true);
  final Ref<bool> comments = Ref(true);
  final Ref<bool> issues = Ref(true);
  final Ref<bool> calendar = Ref(true);

  String? _recordId;

  NotificationSettingsStore(this._pb, this._authStore);

  Future<void> load() async {
    loading.value = true;
    try {
      final userId = _authStore.currentUser.value?.id;
      if (userId == null) return;

      final existing = await _pb
          .collection(_collection)
          .getFullList(filter: 'user = "$userId"');

      if (existing.isNotEmpty) {
        final record = existing.first;
        _recordId = record.id;
        posts.value = record.getBoolValue('posts');
        comments.value = record.getBoolValue('comments');
        issues.value = record.getBoolValue('issues');
        calendar.value = record.getBoolValue('calendar');
      } else {
        final record = await _pb.collection(_collection).create(body: {
          'user': userId,
          'posts': true,
          'comments': true,
          'issues': true,
          'calendar': true,
        });
        _recordId = record.id;
      }
    } catch (e) {
      debugPrint('NotificationSettingsStore: load error: $e');
    } finally {
      loading.value = false;
    }
  }

  Future<void> setPosts(bool value) => _set(posts, 'posts', value);
  Future<void> setComments(bool value) => _set(comments, 'comments', value);
  Future<void> setIssues(bool value) => _set(issues, 'issues', value);
  Future<void> setCalendar(bool value) => _set(calendar, 'calendar', value);

  Future<void> _set(Ref<bool> ref, String field, bool value) async {
    final previous = ref.value;
    ref.value = value; // optimistic
    if (_recordId == null) {
      await load();
      if (_recordId == null) return;
    }
    try {
      await _pb.collection(_collection).update(_recordId!, body: {field: value});
    } catch (e) {
      ref.value = previous; // revert on failure
      debugPrint('NotificationSettingsStore: update $field error: $e');
    }
  }
}
