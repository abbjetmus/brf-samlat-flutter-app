import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/notification_link_utils.dart';
import '../../../core/utils/permissions_utils.dart';
import '../dashboard_store.dart';
import '../../settings/pages/settings_page.dart';
import '../../posts/pages/post_detail_page.dart';

class _MenuItem {
  final String label;
  final IconData icon;
  final String path;
  final Color color;
  final String? permissionName;

  /// Feature toggle token for show/hide. Defaults to [permissionName] when null
  /// (set explicitly when the section's feature token differs, e.g. board).
  final String? featureName;

  const _MenuItem({
    required this.label,
    required this.icon,
    required this.path,
    required this.color,
    this.permissionName,
    this.featureName,
  });
}

class DashboardPage extends CompositionWidget {
  static const String path = '/';

  const DashboardPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);
    final dashboardStore = inject(dashboardStoreKey);

    onMounted(() {
      dashboardStore.getNotSeenCount();
    });

    // The association is loaded asynchronously on cold start (after this widget
    // mounts), so getGeneralInfoList() in onMounted can run before it's set and
    // return nothing. (Re)fetch the pinned general-info posts whenever the
    // association id becomes available or changes.
    watch(() => authStore.association.value?.id, (assocId, _) {
      if (assocId != null && assocId.isNotEmpty) {
        dashboardStore.getGeneralInfoList();
      }
    }, immediate: true);

    const menuItems = [
      _MenuItem(
        label: 'Inlägg',
        icon: Icons.article_outlined,
        path: '/posts',
        color: Color(0xFF3B82F6),
        permissionName: 'posts',
      ),
      _MenuItem(
        label: 'Meddelanden',
        icon: Icons.forum_outlined,
        path: '/chat',
        color: Color(0xFF06B6D4),
        permissionName: 'chat',
      ),
      _MenuItem(
        label: 'Ärenden &\nFelanmälan',
        icon: Icons.report_problem_outlined,
        path: '/issues',
        color: Color(0xFFF59E0B),
        permissionName: 'issues',
      ),
      _MenuItem(
        label: 'Kalender',
        icon: Icons.calendar_month_outlined,
        path: '/calendar',
        color: Color(0xFF8B5CF6),
        permissionName: 'calendar_events',
      ),
      _MenuItem(
        label: 'Lokaler',
        icon: Icons.meeting_room_outlined,
        path: '/places',
        color: Color(0xFF10B981),
        permissionName: 'places',
      ),
      _MenuItem(
        label: 'Prylar',
        icon: Icons.handyman_outlined,
        path: '/gadgets',
        color: Color(0xFFF97316),
        permissionName: 'gadgets',
      ),
      _MenuItem(
        label: 'Bostäder',
        icon: Icons.home_outlined,
        path: '/residences',
        color: Color(0xFF14B8A6),
        permissionName: 'residences',
      ),
      _MenuItem(
        label: 'Parkeringar',
        icon: Icons.local_parking_outlined,
        path: '/parking',
        color: Color(0xFF6366F1),
        permissionName: 'parking_lots',
      ),
      _MenuItem(
        label: 'Dokument',
        icon: Icons.folder_outlined,
        path: '/folders',
        color: Color(0xFFEAB308),
        permissionName: 'folders_and_files',
      ),
      _MenuItem(
        label: 'Styrelsen',
        icon: Icons.groups_outlined,
        path: '/board',
        color: Color(0xFF0EA5E9),
        // Members with `board` read see the roster; meetings/protocols are gated
        // separately inside the page by `board_meetings`.
        permissionName: 'board',
        featureName: 'board',
      ),
      _MenuItem(
        label: 'Användare',
        icon: Icons.people_outlined,
        path: '/users',
        color: Color(0xFFEC4899),
        permissionName: 'users',
      ),
      _MenuItem(
        label: 'Behörigheter',
        icon: Icons.admin_panel_settings_outlined,
        path: '/permissions',
        color: Color(0xFF64748B),
        permissionName: 'user_role_types',
      ),
      _MenuItem(
        label: 'Fakturor',
        icon: Icons.receipt_long_outlined,
        path: '/invoices',
        color: Color(0xFFEF4444),
        permissionName: 'invoices',
      ),
      _MenuItem(
        label: 'Formulär',
        icon: Icons.fact_check_outlined,
        path: '/forms',
        color: Color(0xFF7C3AED),
        permissionName: 'forms',
      ),
      _MenuItem(
        label: 'Hjälp',
        icon: Icons.help_outline,
        path: '/help',
        color: Color(0xFF059669),
      ),
    ];

    return (context) {
      final user = authStore.currentUser.value;
      final association = authStore.association.value;
      final notSeenCount = dashboardStore.notSeenCount.value;
      final generalInfoList = dashboardStore.generalInfoList.value;

      // Filter menu items: association feature toggles, then per-role read
      // permission.
      final visibleItems = menuItems.where((item) {
        final permission = item.permissionName;
        if (permission == null) return true;
        // Feature toggle token may differ from the permission token (e.g. board).
        if (!authStore.isFeatureEnabled(item.featureName ?? permission)) {
          return false;
        }
        return authStore.hasPermission(permission, CrudOperation.read);
      }).toList();

      return Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed header — stays in place while the content below scrolls.
            _HeroHeader(
              userName: user?.name ?? '',
              associationName: association?.name,
              notSeenCount: notSeenCount,
              onNotifications: () =>
                  _showNotificationsDialog(context, dashboardStore),
              onSettings: () => context.push(SettingsPage.path),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Padding(
                  // Add the Android system nav-bar inset so the last cards don't
                  // sit under the bottom bar.
                  padding: EdgeInsets.fromLTRB(
                    20,
                    24,
                    20,
                    28 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MenuGrid(
                        items: visibleItems,
                        onTap: (item) => context.push(item.path),
                      ),
                      if (generalInfoList.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        const _SectionTitle('Allmän information'),
                        const SizedBox(height: 14),
                        ...generalInfoList.map(
                          (post) => _InfoCard(
                            title: post.title,
                            subtitle: AppDateUtils.formatDate(post.created),
                            onTap: () => context.push(
                              '${PostDetailPage.path}/${post.id}',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    };
  }
}

class _HeroHeader extends StatelessWidget {
  final String userName;
  final String? associationName;
  final int notSeenCount;
  final VoidCallback onNotifications;
  final VoidCallback onSettings;

  const _HeroHeader({
    required this.userName,
    required this.associationName,
    required this.notSeenCount,
    required this.onNotifications,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final initial = (userName.isNotEmpty ? userName[0] : '?').toUpperCase();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset + 18, 20, 26),
      decoration: const BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Välkommen tillbaka',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userName.isEmpty ? 'BRF Samlat' : userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                if (associationName != null)
                  Text(
                    associationName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          _HeaderIconButton(
            icon: Icons.notifications_outlined,
            badgeCount: notSeenCount,
            onPressed: onNotifications,
          ),
          const SizedBox(width: 6),
          _HeaderIconButton(
            icon: Icons.settings_outlined,
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final VoidCallback onPressed;

  const _HeaderIconButton({
    required this.icon,
    this.badgeCount = 0,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.16),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryDarken1, width: 1.5),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _MenuGrid extends StatelessWidget {
  final List<_MenuItem> items;
  final void Function(_MenuItem) onTap;

  const _MenuGrid({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _MenuCard(item: item, onTap: () => onTap(item));
      },
    );
  }
}

class _MenuCard extends StatelessWidget {
  final _MenuItem item;
  final VoidCallback onTap;

  const _MenuCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: item.color, size: 26),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: Text(
                  item.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _InfoCard({required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.campaign_outlined,
                  color: AppTheme.primaryDarken1,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showNotificationsDialog(
  BuildContext context,
  DashboardStore dashboardStore,
) {
  dashboardStore.getNotifications();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.inkFaint.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(
              children: [
                const Text(
                  'Notiser',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            // ComputedBuilder, not a plain Builder: the modal sheet is built in a
            // separate element tree outside DashboardPage's reactive scope, so a
            // bare `notifications.value` read here would not subscribe and the
            // sheet would never rebuild when the async getNotifications() resolves.
            child: ComputedBuilder(
              builder: () {
                final notifications = dashboardStore.notifications.value;
                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 48,
                          color: AppTheme.inkFaint,
                        ),
                        const SizedBox(height: 12),
                        const Text('Inga notiser'),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  controller: scrollController,
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return Dismissible(
                      key: ValueKey(notification.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) =>
                          dashboardStore.deleteNotification(notification.id),
                      background: Container(
                        color: const Color(0xFFEF4444),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: notification.seen
                                ? AppTheme.inkFaint.withValues(alpha: 0.12)
                                : AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            notification.seen
                                ? Icons.notifications_none
                                : Icons.notifications_active,
                            color: notification.seen
                                ? AppTheme.inkFaint
                                : AppTheme.primaryDarken1,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.seen
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          AppDateUtils.timeAgo(notification.created),
                        ),
                        onTap: () {
                          if (!notification.seen) {
                            dashboardStore.markNotificationAsSeen(
                              notification.id,
                            );
                          }
                          // action_url carries a full universal-link URL
                          // (https://brfsamlat.se/app/posts/detail/X), a bare
                          // in-app path, or a malformed value. resolvePath
                          // returns a safe absolute path (the router's authGuard
                          // drops any /app prefix) or null when unusable.
                          // Mirrors NotificationService._navigateTo.
                          final path = NotificationLinkUtils.resolvePath(
                            notification.actionUrl,
                          );
                          if (path == null) return;
                          final router = GoRouter.of(context);
                          Navigator.of(context).pop();
                          router.go(path);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
