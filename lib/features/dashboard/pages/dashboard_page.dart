import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/dashboard_widgets.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/notification_link_utils.dart';
import '../../../core/utils/permissions_utils.dart';
import '../dashboard_store.dart';
import '../widgets/dashboard_tasks.dart';
import '../widgets/subscription_banner.dart';
import '../../posts/pages/post_detail_page.dart';
import '../../issues/pages/create_issue_page.dart';
import '../../settings/pages/settings_page.dart';
import '../../../core/router/app_shell.dart';
import '../../../core/utils/text_utils.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

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
        dashboardStore.loadTasks();
        dashboardStore.loadSubscription();
      }
    }, immediate: true);

    // Senaste inläggen och kommande händelser — de som den inloggade får se.
    // Hämtas igen när föreningen eller behörigheterna ändras.
    final visibleLists = computed(
      () => visibleDashboardLists(
        isFeatureEnabled: authStore.isFeatureEnabled,
        canRead: (permission) =>
            authStore.hasPermission(permission, CrudOperation.read),
      ),
    );
    watch(
      () =>
          '${authStore.association.value?.id ?? ''}|'
          '${visibleLists.value.map((d) => d.type).join(',')}',
      (key, previous) {
        if ((authStore.association.value?.id ?? '').isEmpty) return;
        dashboardStore.loadLists(visibleLists.value);
      },
      immediate: true,
    );

    final theme = useTheme();
    final topInset = useContextRef<double>(
      (context) => MediaQuery.paddingOf(context).top,
    );

    return (context) {
      final user = authStore.currentUser.value;
      final association = authStore.association.value;
      final residence = authStore.residence.value;
      final notSeenCount = dashboardStore.notSeenCount.value;
      final generalInfoList = dashboardStore.generalInfoList.value;
      final tasks = dashboardStore.tasks.value;
      final subscription = dashboardStore.subscription.value;
      final lists = visibleLists.value;
      final listRows = dashboardStore.widgetLists.value;
      final textTheme = theme.value.textTheme;
      final colors = theme.value.colorScheme;

      final canReport =
          authStore.isFeatureEnabled('issues') &&
          authStore.hasPermission('issues', CrudOperation.create);
      final canBook = appTabs.firstWhere((t) => t.path == '/book').visible(
        authStore,
      );

      final firstName = (user?.name ?? '').trim().split(' ').first;
      final hour = DateTime.now().hour;
      final greeting = hour < 5
          ? 'God natt'
          : hour < 10
          ? 'God morgon'
          : hour < 18
          ? 'Hej'
          : 'God kväll';

      final hasContent =
          !tasks.isEmpty || lists.isNotEmpty || generalInfoList.isNotEmpty;

      Future<void> refresh() => Future.wait([
        dashboardStore.loadTasks(),
        dashboardStore.loadLists(visibleLists.value),
        dashboardStore.getGeneralInfoList(),
        dashboardStore.getNotSeenCount(),
        dashboardStore.loadSubscription(),
      ]);

      Future<void> openTask(DashboardTask task) async {
        if (tabRootPaths.contains(Uri.parse(task.path).path)) {
          context.go(task.path);
          return;
        }
        await context.push(task.path);
        dashboardStore.loadTasks();
      }

      return Scaffold(
        body: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              topInset.value + 16,
              20,
              32,
            ),
            children: [
              // Förening + konto
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.pine,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      TextUtils.initials(association?.name ?? 'B').characters.first,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          association?.name ?? 'BRF Samlat',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall,
                        ),
                        if (residence != null &&
                            residence.streetAddress.isNotEmpty)
                          Text(
                            residence.streetAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  HeaderIconButton(
                    icon: Icons.notifications_none_rounded,
                    tooltip: notSeenCount > 0
                        ? 'Notiser, $notSeenCount olästa'
                        : 'Notiser',
                    badgeCount: notSeenCount,
                    onPressed: () =>
                        _showNotificationsDialog(context, dashboardStore),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Konto och inställningar',
                    child: Material(
                      color: colors.primaryContainer,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => context.push(SettingsPage.path),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Text(
                              TextUtils.initials(user?.name ?? ''),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Hälsning
              Text(
                AppDateUtils.weekdayLong(),
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                firstName.isEmpty ? greeting : '$greeting, $firstName',
                style: textTheme.headlineLarge,
              ),
              const SizedBox(height: 28),

              // Abonnemang: skrivskyddat, gratismånad, uppsagt, full lagring
              if (subscription != null &&
                  subscriptionBannerText(subscription) != null) ...[
                SubscriptionBanner(status: subscription),
                const SizedBox(height: 24),
              ],

              // Att göra
              if (tasks.personal.isNotEmpty) ...[
                DashboardTaskSection(
                  title: 'Att göra',
                  showCount: true,
                  tasks: tasks.personal,
                  onTap: openTask,
                ),
                const SizedBox(height: 24),
              ],

              // Snabbval
              if (canReport || canBook) ...[
                Row(
                  children: [
                    if (canReport)
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.build_outlined,
                          label: 'Felanmäl',
                          filled: true,
                          onTap: () => context.push(CreateIssuePage.path),
                        ),
                      ),
                    if (canReport && canBook) const SizedBox(width: 10),
                    if (canBook)
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.calendar_today_outlined,
                          label: 'Boka',
                          filled: !canReport,
                          onTap: () => context.go('/book'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
              ],

              // Styrelsen
              if (tasks.board.isNotEmpty) ...[
                DashboardTaskSection(
                  title: 'Styrelsen',
                  trailing: 'Kräver åtgärd',
                  tasks: tasks.board,
                  onTap: openTask,
                ),
                const SizedBox(height: 28),
              ],

              if (!hasContent)
                _Card(
                  onTap: () => context.go('/more'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Allt i appen hittar du under Mer, längst ner till höger.',
                          style: textTheme.bodyMedium,
                        ),
                      ),
                      Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                    ],
                  ),
                ),

              for (final d in lists) ...[
                _SectionHeader(
                  title: d.heading,
                  linkText: d.type == 'posts' ? 'Alla anslag' : 'Kalender',
                  onLink: () => openAppPath(context, d.route),
                ),
                const SizedBox(height: 12),
                if (d.type == 'posts')
                  _PostsList(
                    entries: listRows[d.type],
                    onTap: (path) => context.push(path),
                  )
                else
                  _EventsList(
                    entries: listRows[d.type],
                    onTap: (path) => openAppPath(context, path),
                  ),
                const SizedBox(height: 28),
              ],

              // Bra att veta (fästa inlägg)
              if (generalInfoList.isNotEmpty) ...[
                Text('BRA ATT VETA', style: textTheme.labelSmall),
                const SizedBox(height: 10),
                SizedBox(
                  height: 104,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: generalInfoList.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final post = generalInfoList[i];
                      return _InfoTile(
                        title: post.title,
                        highlighted: i == 0,
                        onTap: () => context.push(
                          '${PostDetailPage.path}/${post.id}',
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    };
  }
}

/// Section heading with a link to the full list.
class _SectionHeader extends StatelessWidget {
  final String title;
  final String linkText;
  final VoidCallback onLink;

  const _SectionHeader({
    required this.title,
    required this.linkText,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
          ),
        ),
        TextButton(
          onPressed: onLink,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(linkText),
        ),
      ],
    );
  }
}

/// White card with a hairline border (radius 18).
class _Card extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const _Card({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: BorderSide(color: colors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fg = filled ? colors.onPrimary : colors.onSurface;
    return Material(
      color: filled ? colors.primary : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        side: filled ? BorderSide.none : BorderSide(color: colors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon, color: fg, size: 22),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String text;
  const _EmptyLine(this.text);

  @override
  Widget build(BuildContext context) => _Card(
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

/// Latest posts: one card, date to the right, excerpt below the title.
class _PostsList extends StatelessWidget {
  final List<DashboardListEntry>? entries;
  final void Function(String path) onTap;

  const _PostsList({required this.entries, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rows = entries;
    if (rows == null) return const LinearProgressIndicator();
    if (rows.isEmpty) {
      return const _EmptyLine('Inga anslag har publicerats än.');
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, e) in rows.take(3).indexed) ...[
            if (i > 0) Divider(height: 1, indent: 16, color: colors.outline),
            InkWell(
              onTap: e.path == null ? null : () => onTap(e.path!),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            e.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(e.subtitle, style: theme.textTheme.bodySmall),
                      ],
                    ),
                    if (e.detail.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        e.detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Upcoming events: the next one as a big date block, the rest as rows.
class _EventsList extends StatelessWidget {
  final List<DashboardListEntry>? entries;
  final void Function(String path) onTap;

  const _EventsList({required this.entries, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rows = entries;
    if (rows == null) return const LinearProgressIndicator();
    if (rows.isEmpty) {
      return const _EmptyLine('Inget inplanerat i kalendern just nu.');
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    Widget dateBlock(String? iso, {double size = 60}) => Container(
      width: size,
      padding: EdgeInsets.symmetric(vertical: size > 50 ? 9 : 6),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            AppDateUtils.monthShortUpper(iso),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: colors.onPrimaryContainer,
            ),
          ),
          Text(
            AppDateUtils.dayOfMonth(iso),
            style: TextStyle(
              fontSize: size > 50 ? 28 : 20,
              height: 1.05,
              fontWeight: FontWeight.w800,
              color: colors.onPrimaryContainer,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, e) in rows.take(3).indexed) ...[
            if (i > 0) Divider(height: 1, indent: 16, color: colors.outline),
            InkWell(
              onTap: e.path == null ? null : () => onTap(e.path!),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    dateBlock(e.dateIso, size: i == 0 ? 60 : 48),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontSize: i == 0 ? 16 : 15,
                            ),
                          ),
                          if (e.detail.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              e.detail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 14,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Bra att veta" tile — pinned general-info posts.
class _InfoTile extends StatelessWidget {
  final String title;
  final bool highlighted;
  final VoidCallback onTap;

  const _InfoTile({
    required this.title,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fg = highlighted ? colors.onPrimary : colors.onSurface;
    return SizedBox(
      width: 156,
      child: Material(
        color: highlighted ? colors.primary : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusTile),
          side: highlighted ? BorderSide.none : BorderSide(color: colors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  Icons.push_pin_outlined,
                  size: 20,
                  color: highlighted ? fg : colors.primary,
                ),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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
                        color: Theme.of(context).colorScheme.error,
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
