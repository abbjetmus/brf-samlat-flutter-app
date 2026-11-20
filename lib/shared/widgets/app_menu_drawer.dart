import 'package:flutter/material.dart';

import '../../features/association/pages/association_info_page.dart';

/// One entry in the app menu (shown on the Mer tab, MorePage).
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
