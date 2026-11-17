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
import '../../posts/pages/post_detail_page.dart';
import '../../../shared/widgets/app_menu_drawer.dart';

class DashboardPage extends CompositionWidget {
  static const String path = '/';

  const DashboardPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);
    final dashboardStore = inject(dashboardStoreKey);
    final signaturesStore = inject(signaturesStoreKey);

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
        signaturesStore.getMine();
      }
    }, immediate: true);

    // Startsidan: which counts/lists to show (associations.dashboard_config),
    // limited to what this viewer may see. Same rules as the web's Översikt.
    final dashboardConfig = computed(
      () => DashboardConfig.fromJson(
        authStore.association.value?.dashboardConfig,
      ),
    );
    final visibleWidgets = computed(
      () => dashboardConfig.value.visibleWidgets(
        isFeatureEnabled: authStore.isFeatureEnabled,
        canRead: (permission) =>
            authStore.hasPermission(permission, CrudOperation.read),
      ),
    );
    // Only fetch data for the widgets that are shown; refetch when the
    // association, config or the viewer's permissions change.
    watch(
      () =>
          '${authStore.association.value?.id ?? ''}|'
          '${visibleWidgets.value.map((w) => w.key).join(',')}',
      (key, previous) {
        if ((authStore.association.value?.id ?? '').isEmpty) return;
        dashboardStore.loadWidgets(visibleWidgets.value);
      },
      immediate: true,
    );

    return (context) {
      final user = authStore.currentUser.value;
      final association = authStore.association.value;
      final notSeenCount = dashboardStore.notSeenCount.value;
      final generalInfoList = dashboardStore.generalInfoList.value;
      final mySignatures = signaturesStore.mine.value;
      final pendingSignatures = mySignatures.where((s) => !s.isSigned).length;
      final showGeneralInfo = dashboardConfig.value.showGeneralInfo;
      final countWidgets = visibleWidgets.value
          .where((w) => w.format == DashboardWidgetFormat.count)
          .toList();
      final listWidgets = visibleWidgets.value
          .where((w) => w.format == DashboardWidgetFormat.list)
          .toList();
      final widgetCounts = dashboardStore.widgetCounts.value;
      final widgetLists = dashboardStore.widgetLists.value;
      final isAdmin = authStore.isAdmin.value;
      String? linkFor(DashboardWidget w) =>
          w.definition.adminOnlyLink && !isAdmin ? null : w.definition.route;

      // Allt i appen nås via sidomenyn (☰ i headern); startsidan visar bara
      // det föreningen har valt under Inställningar → Startsida.
      final hasContent =
          countWidgets.isNotEmpty ||
          listWidgets.isNotEmpty ||
          (showGeneralInfo && generalInfoList.isNotEmpty);

      return Scaffold(
        endDrawer: const AppMenuDrawer(),
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
                      if (pendingSignatures > 0) ...[
                        _InfoCard(
                          icon: Icons.draw_outlined,
                          title: pendingSignatures == 1
                              ? 'Du har ett protokoll att signera'
                              : 'Du har $pendingSignatures protokoll att signera',
                          subtitle: 'Tryck för att läsa och signera',
                          onTap: () => context.push('/signatures'),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (countWidgets.isNotEmpty) ...[
                        _StatGrid(
                          widgets: countWidgets,
                          counts: widgetCounts,
                          linkFor: linkFor,
                          onTap: (path) => context.push(path),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (!hasContent)
                        // Builder: Scaffold.of behöver en context under sidans Scaffold.
                        Builder(
                          builder: (inner) => _InfoCard(
                            icon: Icons.menu,
                            title: 'Hitta allt i appen i menyn',
                            subtitle:
                                'Tryck på ☰ uppe till höger för inlägg, '
                                'meddelanden, kalender och mer.',
                            onTap: () => Scaffold.of(inner).openEndDrawer(),
                          ),
                        ),
                      for (final (i, w) in listWidgets.indexed) ...[
                        // 28 mellan sektioner; räknarrutnätet har redan 14 under sig.
                        if (i > 0)
                          const SizedBox(height: 28)
                        else if (countWidgets.isNotEmpty)
                          const SizedBox(height: 14),
                        _ListWidgetSection(
                          widget: w,
                          entries: widgetLists[w.type],
                          allPath: linkFor(w),
                          onTap: (path) => context.push(path),
                        ),
                      ],
                      if (showGeneralInfo && generalInfoList.isNotEmpty) ...[
                        if (listWidgets.isNotEmpty)
                          const SizedBox(height: 28)
                        else if (countWidgets.isNotEmpty)
                          const SizedBox(height: 14),
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

  const _HeroHeader({
    required this.userName,
    required this.associationName,
    required this.notSeenCount,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

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
          // ☰ öppnar sidomenyn (Scaffold.endDrawer) — samma plats som på
          // alla andra sidor. Inställningar finns i menyn under Konto.
          _HeaderIconButton(
            icon: Icons.menu,
            onPressed: () => Scaffold.of(context).openEndDrawer(),
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

/// Counts (räknare) — two compact tiles per row.
class _StatGrid extends StatelessWidget {
  final List<DashboardWidget> widgets;
  final Map<String, int> counts;
  final String? Function(DashboardWidget) linkFor;
  final void Function(String path) onTap;

  const _StatGrid({
    required this.widgets,
    required this.counts,
    required this.linkFor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: widgets.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 84,
      ),
      itemBuilder: (context, index) {
        final w = widgets[index];
        final def = w.definition;
        final link = linkFor(w);
        final count = counts[w.type];
        return Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: link == null ? null : () => onTap(link),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: def.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(def.icon, color: def.color, size: 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          count == null ? '–' : '$count',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          w.heading,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.15,
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
      },
    );
  }
}

/// A short list (latest/upcoming) with a "Visa alla" link.
class _ListWidgetSection extends StatelessWidget {
  final DashboardWidget widget;
  final List<DashboardListEntry>? entries;
  final String? allPath;
  final void Function(String path) onTap;

  const _ListWidgetSection({
    required this.widget,
    required this.entries,
    required this.allPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final def = widget.definition;
    final rows = entries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _SectionTitle(widget.heading)),
            if (allPath != null)
              TextButton(
                onPressed: () => onTap(allPath!),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Visa alla'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (rows == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          )
        else if (rows.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Text(
              widget.type == 'issues'
                  ? 'Inga felanmälningar eller ärenden. Bra jobbat!'
                  : 'Inget att visa just nu.',
              style: TextStyle(
                fontSize: 13.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...rows.map((entry) {
            final path = entry.path;
            return _InfoCard(
              title: entry.title,
              subtitle: entry.subtitle,
              icon: entry.icon ?? def.icon,
              iconColor: entry.color ?? def.color,
              chipText: entry.chipText,
              chipColor: entry.chipColor,
              onTap: path == null ? null : () => onTap(path),
            );
          }),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final IconData icon;
  final Color? iconColor;
  final String? chipText;
  final Color? chipColor;

  const _InfoCard({
    required this.title,
    required this.subtitle,
    this.onTap,
    this.icon = Icons.campaign_outlined,
    this.iconColor,
    this.chipText,
    this.chipColor,
  });

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
                  color: iconColor?.withValues(alpha: 0.12) ??
                      AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? AppTheme.primaryDarken1,
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
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (chipText != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (chipColor ?? AppTheme.primaryDarken1).withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    chipText!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: chipColor ?? AppTheme.primaryDarken1,
                    ),
                  ),
                ),
              ],
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
