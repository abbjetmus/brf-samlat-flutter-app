import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart';
import '../auth/auth_store.dart' as auth;

/// A notification category as served by the backend (key, label, description).
class NotificationCategory {
  final String key;
  final String label;
  final String description;

  const NotificationCategory({
    required this.key,
    required this.label,
    required this.description,
  });

  factory NotificationCategory.fromJson(Map<String, dynamic> json) {
    return NotificationCategory(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}

/// Push / e-mail choice for one category.
class NotificationChannels {
  final bool push;
  final bool email;

  const NotificationChannels({required this.push, required this.email});

  NotificationChannels copyWith({bool? push, bool? email}) =>
      NotificationChannels(push: push ?? this.push, email: email ?? this.email);
}

/// Reads and persists the user's notification preferences per category via
/// `GET/PATCH /api/notification-preferences` (brf-samlat-pb,
/// pb_hooks/api/notification_preferences.pb.js).
///
/// The backend owns the category list and the defaults: push on everywhere,
/// e-mail off — except for users without any push token, who get e-mail by
/// default. Only explicit choices are stored, so toggling one switch sends
/// just that category/channel.
class NotificationSettingsStore {
  static const String _path = '/api/notification-preferences';

  final PocketBase _pb;
  // Kept for API compatibility with the settings page; the backend resolves
  // the user from the auth token.
  // ignore: unused_field
  final auth.AuthStore _authStore;

  final Ref<bool> loading = Ref(true);
  final Ref<bool> loadFailed = Ref(false);
  final Ref<bool> hasPushToken = Ref(false);
  final Ref<List<NotificationCategory>> categories = Ref(const []);
  final Ref<Map<String, NotificationChannels>> preferences = Ref(const {});

  /// "category:channel" currently being saved, to disable that switch.
  final Ref<String?> saving = Ref(null);

  NotificationSettingsStore(this._pb, this._authStore);

  void _apply(dynamic res) {
    final map = Map<String, dynamic>.from(res as Map);
    categories.value = ((map['categories'] as List?) ?? const [])
        .map(
          (c) => NotificationCategory.fromJson(
            Map<String, dynamic>.from(c as Map),
          ),
        )
        .toList();
    final prefs = Map<String, dynamic>.from(
      (map['preferences'] as Map?) ?? const {},
    );
    preferences.value = prefs.map((key, value) {
      final entry = Map<String, dynamic>.from(value as Map);
      return MapEntry(
        key,
        NotificationChannels(
          push: entry['push'] as bool? ?? true,
          email: entry['email'] as bool? ?? false,
        ),
      );
    });
    hasPushToken.value = map['has_push_token'] as bool? ?? false;
  }

  Future<void> load() async {
    loading.value = true;
    try {
      _apply(await _pb.send(_path));
      loadFailed.value = false;
    } catch (e) {
      loadFailed.value = true;
      debugPrint('NotificationSettingsStore: load error: $e');
    } finally {
      loading.value = false;
    }
  }

  Future<void> setPush(String category, bool value) =>
      _set(category, 'push', value);

  Future<void> setEmail(String category, bool value) =>
      _set(category, 'email', value);

  Future<void> _set(String category, String channel, bool value) async {
    final previous = preferences.value;
    final current = previous[category];
    if (current == null) return;

    // Optimistic update; reverted if the backend refuses.
    preferences.value = {
      ...previous,
      category: channel == 'push'
          ? current.copyWith(push: value)
          : current.copyWith(email: value),
    };
    saving.value = '$category:$channel';
    try {
      _apply(
        await _pb.send(
          _path,
          method: 'PATCH',
          body: {
            'preferences': {
              category: {channel: value},
            },
          },
        ),
      );
    } catch (e) {
      preferences.value = previous;
      debugPrint(
        'NotificationSettingsStore: update $category.$channel error: $e',
      );
    } finally {
      saving.value = null;
    }
  }
}
