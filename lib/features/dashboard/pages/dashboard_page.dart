import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/permissions_utils.dart';
import '../dashboard_store.dart';
import '../../settings/pages/settings_page.dart';

class _MenuItem {
  final String label;
  final IconData icon;
  final String path;
  final String? permissionName;

  const _MenuItem({
    required this.label,
    required this.icon,
    required this.path,
    this.permissionName,
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
      dashboardStore.getGeneralInfoList();
    });

    const menuItems = [
      _MenuItem(label: 'Nyheter', icon: Icons.article_outlined, path: '/posts', permissionName: 'posts'),
      _MenuItem(label: 'Meddelanden', icon: Icons.chat_outlined, path: '/chat', permissionName: 'chat'),
      _MenuItem(label: 'Felanmälan & ärenden', icon: Icons.report_problem_outlined, path: '/issues', permissionName: 'issues'),
      _MenuItem(label: 'Kalender', icon: Icons.calendar_month_outlined, path: '/calendar', permissionName: 'calendar_events'),
      _MenuItem(label: 'Lokaler', icon: Icons.meeting_room_outlined, path: '/places', permissionName: 'places'),
      _MenuItem(label: 'Prylar', icon: Icons.handyman_outlined, path: '/gadgets', permissionName: 'gadgets'),
      _MenuItem(label: 'Bostäder', icon: Icons.home_outlined, path: '/residences', permissionName: 'residences'),
      _MenuItem(label: 'Parkeringar', icon: Icons.local_parking_outlined, path: '/parking-lots', permissionName: 'parking_lots'),
      _MenuItem(label: 'Dokument', icon: Icons.folder_outlined, path: '/folders', permissionName: 'folders_and_files'),
      _MenuItem(label: 'Styrelsen', icon: Icons.groups_outlined, path: '/board', permissionName: 'board_meetings'),
      _MenuItem(label: 'Användare', icon: Icons.people_outlined, path: '/users', permissionName: 'users'),
      _MenuItem(label: 'Behörigheter', icon: Icons.admin_panel_settings_outlined, path: '/permissions', permissionName: 'user_role_types'),
      _MenuItem(label: 'Fakturor', icon: Icons.receipt_long_outlined, path: '/invoices', permissionName: 'invoices'),
      _MenuItem(label: 'Formulär', icon: Icons.quiz_outlined, path: '/forms', permissionName: 'forms'),
      _MenuItem(label: 'Hjälp', icon: Icons.help_outline, path: '/help'),
    ];

    return (context) {
      final user = authStore.currentUser.value;
      final association = authStore.association.value;
      final notSeenCount = dashboardStore.notSeenCount.value;
      final generalInfoList = dashboardStore.generalInfoList.value;

      // Filter menu items based on permissions
      final visibleItems = menuItems.where((item) {
        if (item.permissionName == null) return true;
        return authStore.hasPermission(item.permissionName!, CrudOperation.read);
      }).toList();

      return Scaffold(
        appBar: AppBar(
          title: Text(association?.name ?? 'BRF Samlat'),
          actions: [
            // Notifications
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => _showNotificationsDialog(context, dashboardStore),
                ),
                if (notSeenCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$notSeenCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push(SettingsPage.path),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome message
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.primaryColor,
                        child: Text(
                          (user?.name ?? '?')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Välkommen, ${user?.name ?? ''}!',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (association != null)
                              Text(
                                association.name,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Menu grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: visibleItems.length,
                itemBuilder: (context, index) {
                  final item = visibleItems[index];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => context.push(item.path),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.icon,
                            size: 32,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.label,
                            style: const TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // General info
              if (generalInfoList.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Allmän information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...generalInfoList.map((post) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(post.title),
                    subtitle: Text(
                      AppDateUtils.formatDate(post.created),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                )),
              ],
            ],
          ),
        ),
      );
    };
  }
}

void _showNotificationsDialog(BuildContext context, DashboardStore dashboardStore) {
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Notiser',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
            child: Builder(
              builder: (context) {
                final notifications = dashboardStore.notifications.value;
                if (notifications.isEmpty) {
                  return const Center(
                    child: Text('Inga notiser'),
                  );
                }
                return ListView.separated(
                  controller: scrollController,
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return ListTile(
                      leading: Icon(
                        notification.seen
                            ? Icons.notifications_none
                            : Icons.notifications_active,
                        color: notification.seen ? Colors.grey : AppTheme.primaryColor,
                      ),
                      title: Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight:
                              notification.seen ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        AppDateUtils.timeAgo(notification.created),
                      ),
                      onTap: () {
                        if (!notification.seen) {
                          dashboardStore.markNotificationAsSeen(notification.id);
                        }
                      },
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
