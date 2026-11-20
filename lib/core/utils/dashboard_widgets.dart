import 'package:flutter/material.dart';

/// The lists on the dashboard under "För dig" / "Kräver åtgärd": the latest
/// posts and the upcoming calendar events. Fixed for every association — the
/// same as the web's Översikt (brf-samlat-nuxt-app pages/portal/index.vue).
class DashboardWidgetDefinition {
  final String type;
  final String heading;
  final IconData icon;
  final Color color;

  /// Feature tokens (associations.disabled_features) that must all be on.
  final List<String> features;

  /// Permission-matrix key the viewer needs read on.
  final String permission;

  /// "Visa alla" route.
  final String route;

  const DashboardWidgetDefinition({
    required this.type,
    required this.heading,
    required this.icon,
    required this.color,
    required this.features,
    required this.permission,
    required this.route,
  });
}

const dashboardLists = <DashboardWidgetDefinition>[
  DashboardWidgetDefinition(
    type: 'posts',
    heading: 'Senaste anslag',
    icon: Icons.article_outlined,
    color: Color(0xFF3B82F6),
    features: ['posts'],
    permission: 'posts',
    route: '/posts',
  ),
  DashboardWidgetDefinition(
    type: 'calendar_events',
    heading: 'Nästa i kalendern',
    icon: Icons.calendar_month_outlined,
    color: Color(0xFF8B5CF6),
    features: ['calendar_events'],
    permission: 'calendar_events',
    route: '/calendar',
  ),
];

/// The lists this viewer may see: all features on and read permission on the
/// list's matrix key. The data is still limited by the API rules.
List<DashboardWidgetDefinition> visibleDashboardLists({
  required bool Function(String feature) isFeatureEnabled,
  required bool Function(String permission) canRead,
}) => dashboardLists
    .where((d) => d.features.every(isFeatureEnabled) && canRead(d.permission))
    .toList();

/// One row in a list widget on the dashboard.
class DashboardListEntry {
  final String id;
  final String title;
  final String subtitle;
  final String? path;
  final IconData? icon;
  final Color? color;
  final String? chipText;
  final Color? chipColor;

  /// ISO date: published (posts) or start (events) — for date blocks.
  final String? dateIso;

  /// Extra line: a post's excerpt, or an event's time and place.
  final String detail;

  const DashboardListEntry({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.path,
    this.icon,
    this.color,
    this.chipText,
    this.chipColor,
    this.dateIso,
    this.detail = '',
  });
}
