import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';

/// The number on the app icon: unseen notifications (the bell on the dashboard).
///
/// The app sets it while it runs. While the app is closed, each push from
/// brf-samlat-api carries the current count (`aps.badge` / `notificationCount`)
/// and the OS sets it. Android launchers without numeric badges show a dot for
/// the pushes in the notification shade instead.
class AppIconBadgeService {
  int? _shown;

  Future<void> show(int count) async {
    final value = count < 0 ? 0 : count;
    if (value == _shown) return;
    _shown = value;
    try {
      await AppBadgePlus.updateBadge(value);
    } catch (e) {
      // Launchers without badge support; nothing to show there.
      debugPrint('[AppIconBadge] update failed: $e');
    }
  }
}
