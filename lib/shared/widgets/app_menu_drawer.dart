import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection_keys.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/permissions_utils.dart';
import '../../features/association/pages/association_info_page.dart';
import '../../features/settings/pages/settings_page.dart';

/// One entry in the app menu (the side menu, [AppMenuDrawer]).
class AppMenuItem {
  final String label;
  final IconData icon;
  final String path;
  final Color color;

  /// Read permission needed to see the item (null = everyone).
  final String? permissionName;

  /// Feature toggle token for show/hide. Defaults to [permissionName] when null
  /// (set explicitly when the section's feature token differs, e.g. board).
  final String? featureName;

  /// Another read permission (and feature token) that also shows the item.
  /// Styrelsen: board roles may only read board_meetings, and the meetings are
  /// on the board page.
  final String? alsoPermissionName;

  const AppMenuItem({
    required this.label,
    required this.icon,
    required this.path,
    required this.color,
    this.permissionName,
    this.featureName,
    this.alsoPermissionName,
  });

  /// The label on one line, for search ("Förenings-\nstämma" → "Föreningsstämma").
  String get searchText =>
      label.replaceAll('-\n', '').replaceAll('\n', ' ').toLowerCase();
}

class AppMenuSection {
  final String heading;
  final List<AppMenuItem> items;

  const AppMenuSection(this.heading, this.items);
}

/// The whole app menu, grouped like the web portal's sidebar
/// (brf-samlat-nuxt-app/app/layouts/admin.vue).
const appMenuSections = [
  AppMenuSection('Kommunikation', [
    AppMenuItem(
      label: 'Inlägg',
      icon: Icons.article_outlined,
      path: '/posts',
      color: Color(0xFF3B82F6),
      permissionName: 'posts',
    ),
    AppMenuItem(
      label: 'Meddelanden',
      icon: Icons.forum_outlined,
      path: '/chat',
      color: Color(0xFF06B6D4),
      permissionName: 'chat',
    ),
    AppMenuItem(
      label: 'Kalender',
      icon: Icons.calendar_month_outlined,
      path: '/calendar',
      color: Color(0xFF8B5CF6),
      permissionName: 'calendar_events',
    ),
    AppMenuItem(
      label: 'Enkäter',
      icon: Icons.fact_check_outlined,
      path: '/forms',
      color: Color(0xFF7C3AED),
      permissionName: 'forms',
    ),
  ]),
  AppMenuSection('Fastighet', [
    AppMenuItem(
      label: 'Ärenden &\nFelanmälan',
      icon: Icons.report_problem_outlined,
      path: '/issues',
      color: Color(0xFFF59E0B),
      permissionName: 'issues',
    ),
    AppMenuItem(
      label: 'Leverantörer',
      icon: Icons.engineering_outlined,
      path: '/contractors',
      color: Color(0xFF78716C),
      permissionName: 'contractors',
      // Part of Felanmälan & ärenden on the web (feature token `issues`).
      featureName: 'issues',
    ),
    AppMenuItem(
      label: 'Bostäder',
      icon: Icons.home_outlined,
      path: '/residences',
      color: Color(0xFF14B8A6),
      permissionName: 'residences',
    ),
    AppMenuItem(
      label: 'Ansökningar',
      icon: Icons.assignment_outlined,
      path: '/residence-applications',
      color: Color(0xFF0D9488),
      permissionName: 'residence_applications',
    ),
    AppMenuItem(
      label: 'Underhållsplan',
      icon: Icons.construction_outlined,
      path: '/maintenance-plan',
      color: Color(0xFFB45309),
      permissionName: 'maintenance_plan',
    ),
    AppMenuItem(
      label: 'Lokaler',
      icon: Icons.meeting_room_outlined,
      path: '/places',
      color: Color(0xFF10B981),
      permissionName: 'places',
    ),
    AppMenuItem(
      label: 'Parkeringar',
      icon: Icons.local_parking_outlined,
      path: '/parking',
      color: Color(0xFF6366F1),
      permissionName: 'parking_lots',
    ),
    AppMenuItem(
      label: 'Prylar',
      icon: Icons.handyman_outlined,
      path: '/gadgets',
      color: Color(0xFFF97316),
      permissionName: 'gadgets',
    ),
    AppMenuItem(
      label: 'Dokument',
      icon: Icons.folder_outlined,
      path: '/folders',
      color: Color(0xFFEAB308),
      permissionName: 'folders_and_files',
    ),
  ]),
  AppMenuSection('Ekonomi', [
    AppMenuItem(
      label: 'Fakturor',
      icon: Icons.receipt_long_outlined,
      path: '/invoices',
      color: Color(0xFFEF4444),
      permissionName: 'invoices',
    ),
    AppMenuItem(
      label: 'Faktura-\növersikt',
      icon: Icons.table_chart_outlined,
      path: '/invoice-overview',
      color: Color(0xFFDC2626),
      permissionName: 'invoice_payments',
      featureName: 'invoices',
    ),
  ]),
  AppMenuSection('Föreningen', [
    AppMenuItem(
      label: 'Om\nföreningen',
      icon: Icons.apartment_outlined,
      path: AssociationInfoPage.path,
      color: Color(0xFF16A34A),
    ),
    AppMenuItem(
      label: 'Styrelsen',
      icon: Icons.groups_outlined,
      path: '/board',
      color: Color(0xFF0EA5E9),
      // Members with `board` read see the roster; meetings/protocols are gated
      // separately inside the page by `board_meetings`. Board roles that may
      // only read meetings still need the menu item to reach them.
      permissionName: 'board',
      featureName: 'board',
      alsoPermissionName: 'board_meetings',
    ),
    AppMenuItem(
      label: 'Årshjul',
      icon: Icons.donut_large_outlined,
      path: '/annual-wheel',
      color: Color(0xFF22C55E),
      permissionName: 'annual_wheel',
    ),
    AppMenuItem(
      label: 'Förenings-\nstämma',
      icon: Icons.gavel_outlined,
      path: '/general-meetings',
      color: Color(0xFFA855F7),
      permissionName: 'general_meetings',
    ),
  ]),
  AppMenuSection('Administration', [
    AppMenuItem(
      label: 'Användare',
      icon: Icons.people_outlined,
      path: '/users',
      color: Color(0xFFEC4899),
      permissionName: 'users',
    ),
    AppMenuItem(
      label: 'Rättigheter',
      icon: Icons.admin_panel_settings_outlined,
      path: '/permissions',
      color: Color(0xFF64748B),
      permissionName: 'user_role_types',
    ),
  ]),
  AppMenuSection('Hjälp', [
    AppMenuItem(
      label: 'Hjälp',
      icon: Icons.help_outline,
      path: '/help',
      color: Color(0xFF059669),
    ),
  ]),
];

/// The menu sections this user may see: association feature toggles, then
/// per-role read permission. Empty sections are dropped. Things to do (e.g.
/// protocols to sign) are on the start page under "För dig", not in the menu.
List<AppMenuSection> visibleAppMenuSections({
  required bool Function(String feature) isFeatureEnabled,
  required bool Function(String permission) canRead,
}) {
  bool visible(AppMenuItem item) {
    final permission = item.permissionName;
    if (permission == null) return true;
    final also = item.alsoPermissionName;
    if (also != null && isFeatureEnabled(also) && canRead(also)) return true;
    if (!isFeatureEnabled(item.featureName ?? permission)) return false;
    return canRead(permission);
  }

  return [
    for (final section in appMenuSections)
      if (section.items.any(visible))
        AppMenuSection(section.heading, section.items.where(visible).toList()),
  ];
}

/// Navigates from the side menu. The menu is top-level navigation: the stack
/// always becomes start page → chosen page, so back returns to the start page
/// instead of growing a long stack of pages opened from the menu.
void navigateFromMenu(GoRouter router, String path) {
  final current = router.routerDelegate.currentConfiguration.uri.path;
  if (path == '/') {
    if (current != '/') router.go('/');
    return;
  }
  if (current == path) return;
  if (current == '/') {
    router.push(path);
    return;
  }
  router.go('/');
  // push() builds on the router's current configuration, which is updated
  // after go() has been processed — wait a frame.
  WidgetsBinding.instance.addPostFrameCallback((_) => router.push(path));
}

/// The app's side menu (Scaffold.endDrawer), opened with the ☰ button at the
/// right of every page header. Grouped like the web portal's sidebar.
class AppMenuDrawer extends CompositionWidget {
  const AppMenuDrawer({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);
    final theme = useTheme();
    final (searchController, query, _) = useTextEditingController();

    final sections = computed(
      () => visibleAppMenuSections(
        isFeatureEnabled: authStore.isFeatureEnabled,
        canRead: (permission) =>
            authStore.hasPermission(permission, CrudOperation.read),
      ),
    );

    // While searching, one flat section with every match.
    final shownSections = computed(() {
      final q = query.value.trim().toLowerCase();
      if (q.isEmpty) return sections.value;
      final seen = <String>{};
      final matches = [
        for (final section in sections.value)
          for (final item in section.items)
            if (item.searchText.contains(q) && seen.add(item.path)) item,
      ];
      return matches.isEmpty
          ? const <AppMenuSection>[]
          : [AppMenuSection('Sökresultat', matches)];
    });

    return (context) {
      final colors = theme.value.colorScheme;
      final currentPath = GoRouterState.of(context).uri.path;
      final searching = query.value.trim().isNotEmpty;

      void open(String path) {
        final router = GoRouter.of(context);
        Scaffold.of(context).closeEndDrawer();
        navigateFromMenu(router, path);
      }

      bool isActive(String path) => path == '/'
          ? currentPath == '/'
          : currentPath == path || currentPath.startsWith('$path/');

      Widget tile({
        required String label,
        required IconData icon,
        required Color color,
        required String path,
      }) {
        final active = isActive(path);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
          child: ListTile(
            dense: true,
            selected: active,
            selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.10),
            selectedColor: colors.onSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            title: Text(
              label.replaceAll('-\n', '').replaceAll('\n', ' '),
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            onTap: () => open(path),
          ),
        );
      }

      Widget heading(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 6),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: colors.onSurfaceVariant,
          ),
        ),
      );

      final topInset = MediaQuery.paddingOf(context).top;
      final bottomInset = MediaQuery.paddingOf(context).bottom;

      return Drawer(
        width: 304,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              // Ingen rubrikdel: sökrutan börjar direkt under statusfältet.
              padding: EdgeInsets.fromLTRB(16, topInset + 14, 16, 4),
              child: TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Sök i menyn',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  suffixIcon: searching
                      ? IconButton(
                          tooltip: 'Rensa',
                          icon: const Icon(Icons.close),
                          onPressed: () => query.value = '',
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: 16 + bottomInset),
                children: [
                  if (!searching) ...[
                    const SizedBox(height: 6),
                    tile(
                      label: 'Startsida',
                      icon: Icons.dashboard_outlined,
                      color: AppTheme.primaryDarken1,
                      path: '/',
                    ),
                  ],
                  if (searching && shownSections.value.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        'Inget i menyn matchar "${query.value.trim()}".',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                  for (final section in shownSections.value) ...[
                    heading(section.heading),
                    for (final item in section.items)
                      tile(
                        label: item.label,
                        icon: item.icon,
                        color: item.color,
                        path: item.path,
                      ),
                  ],
                  if (!searching) ...[
                    heading('Konto'),
                    tile(
                      label: 'Inställningar',
                      icon: Icons.settings_outlined,
                      color: const Color(0xFF64748B),
                      path: SettingsPage.path,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    };
  }
}
