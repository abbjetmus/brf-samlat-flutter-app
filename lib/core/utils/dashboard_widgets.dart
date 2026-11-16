import 'dart:convert';

import 'package:flutter/material.dart';

/// Startsidan: what the dashboard shows is set per association in
/// `associations.dashboard_config` (edited on the web under Inställningar →
/// Startsida):
///
///   { "show_general_info": true,
///     "widgets": [ { "type": "issues", "format": "list" }, … ] }
///
/// `widgets` is ordered. When unset, [DashboardConfig.defaults] is used (the
/// same as the web's Översikt has always shown).
///
/// The types are shared with the web (brf-samlat-nuxt-app
/// app/utils/dashboardWidgets.ts) and validated by brf-samlat-pb
/// (pb_hooks/utils/dashboard_config_utils.js) — keep them in sync.
///
/// Formats: `count` = one number, `list` = the latest/upcoming records.
/// Residences, parking lots and users are count only, posts list only.
class DashboardWidgetFormat {
  static const String count = 'count';
  static const String list = 'list';
}

class DashboardWidgetDefinition {
  final String type;

  /// Name of the type in the settings.
  final String label;
  final String countLabel;
  final String listLabel;
  final IconData icon;
  final Color color;
  final List<String> formats;

  /// Feature tokens (associations.disabled_features) that must all be on.
  final List<String> features;

  /// Permission-matrix key the viewer needs read on (null = everyone).
  final String? permission;

  /// The "Visa alla" target is only reachable for admins (e.g. the user list).
  final bool adminOnlyLink;

  /// "Visa alla" route.
  final String route;

  const DashboardWidgetDefinition({
    required this.type,
    required this.label,
    required this.countLabel,
    required this.listLabel,
    required this.icon,
    required this.color,
    required this.formats,
    required this.route,
    this.features = const [],
    this.permission,
    this.adminOnlyLink = false,
  });
}

const dashboardWidgetDefinitions = <String, DashboardWidgetDefinition>{
  'residences': DashboardWidgetDefinition(
    type: 'residences',
    label: 'Bostäder',
    countLabel: 'Bostäder',
    listLabel: 'Bostäder',
    icon: Icons.home_outlined,
    color: Color(0xFF14B8A6),
    formats: [DashboardWidgetFormat.count],
    features: ['residences'],
    permission: 'residences',
    route: '/residences',
  ),
  'parking_lots': DashboardWidgetDefinition(
    type: 'parking_lots',
    label: 'Parkeringar',
    countLabel: 'Parkeringar',
    listLabel: 'Parkeringar',
    icon: Icons.local_parking_outlined,
    color: Color(0xFF6366F1),
    formats: [DashboardWidgetFormat.count],
    features: ['parking_lots'],
    permission: 'parking_lots',
    route: '/parking',
  ),
  'users': DashboardWidgetDefinition(
    type: 'users',
    label: 'Registrerade användare',
    countLabel: 'Registrerade användare',
    listLabel: 'Registrerade användare',
    icon: Icons.people_outlined,
    color: Color(0xFFEC4899),
    formats: [DashboardWidgetFormat.count],
    adminOnlyLink: true,
    route: '/users',
  ),
  'issues': DashboardWidgetDefinition(
    type: 'issues',
    label: 'Felanmälningar & ärenden',
    countLabel: 'Öppna felanmälningar & ärenden',
    listLabel: 'Senaste felanmälningar & ärenden',
    icon: Icons.report_problem_outlined,
    color: Color(0xFFEF4444),
    formats: [DashboardWidgetFormat.count, DashboardWidgetFormat.list],
    features: ['issues'],
    permission: 'issues',
    route: '/issues',
  ),
  'posts': DashboardWidgetDefinition(
    type: 'posts',
    label: 'Inlägg',
    countLabel: 'Inlägg',
    listLabel: 'Senaste inläggen',
    icon: Icons.article_outlined,
    color: Color(0xFF3B82F6),
    formats: [DashboardWidgetFormat.list],
    features: ['posts'],
    permission: 'posts',
    route: '/posts',
  ),
  'calendar_events': DashboardWidgetDefinition(
    type: 'calendar_events',
    label: 'Kalender',
    countLabel: 'Kommande händelser',
    listLabel: 'Kommande händelser',
    icon: Icons.calendar_month_outlined,
    color: Color(0xFF8B5CF6),
    formats: [DashboardWidgetFormat.count, DashboardWidgetFormat.list],
    features: ['calendar_events'],
    permission: 'calendar_events',
    route: '/calendar',
  ),
  'place_bookings': DashboardWidgetDefinition(
    type: 'place_bookings',
    label: 'Lokalbokningar',
    countLabel: 'Kommande lokalbokningar',
    listLabel: 'Kommande lokalbokningar',
    icon: Icons.meeting_room_outlined,
    color: Color(0xFF10B981),
    formats: [DashboardWidgetFormat.count, DashboardWidgetFormat.list],
    features: ['places'],
    permission: 'place_bookings',
    route: '/places',
  ),
  'gadget_bookings': DashboardWidgetDefinition(
    type: 'gadget_bookings',
    label: 'Prylbokningar',
    countLabel: 'Kommande prylbokningar',
    listLabel: 'Kommande prylbokningar',
    icon: Icons.handyman_outlined,
    color: Color(0xFFF97316),
    formats: [DashboardWidgetFormat.count, DashboardWidgetFormat.list],
    features: ['gadgets'],
    permission: 'gadget_bookings',
    route: '/gadgets',
  ),
  'board_meetings': DashboardWidgetDefinition(
    type: 'board_meetings',
    label: 'Styrelsemöten',
    countLabel: 'Kommande styrelsemöten',
    listLabel: 'Kommande styrelsemöten',
    icon: Icons.groups_outlined,
    color: Color(0xFF0EA5E9),
    formats: [DashboardWidgetFormat.count, DashboardWidgetFormat.list],
    features: ['board', 'board_meetings'],
    permission: 'board_meetings',
    route: '/board',
  ),
};

class DashboardWidget {
  final String type;
  final String format;

  const DashboardWidget(this.type, this.format);

  DashboardWidgetDefinition get definition => dashboardWidgetDefinitions[type]!;

  String get key => '$type-$format';

  String get heading => format == DashboardWidgetFormat.count
      ? definition.countLabel
      : definition.listLabel;
}

class DashboardConfig {
  final bool showGeneralInfo;
  final List<DashboardWidget> widgets;

  const DashboardConfig({required this.showGeneralInfo, required this.widgets});

  static const defaults = DashboardConfig(
    showGeneralInfo: true,
    widgets: [
      DashboardWidget('residences', DashboardWidgetFormat.count),
      DashboardWidget('parking_lots', DashboardWidgetFormat.count),
      DashboardWidget('users', DashboardWidgetFormat.count),
      DashboardWidget('issues', DashboardWidgetFormat.count),
      DashboardWidget('issues', DashboardWidgetFormat.list),
    ],
  );

  /// Parses the raw `dashboard_config` value (map, JSON string or null).
  /// Unknown types, unsupported formats and duplicates are dropped; anything
  /// unreadable falls back to [defaults].
  factory DashboardConfig.fromJson(Object? raw) {
    Object? value = raw;
    if (value is String) {
      try {
        value = value.trim().isEmpty ? null : jsonDecode(value);
      } catch (_) {
        value = null;
      }
    }
    if (value is! Map) return defaults;

    final rawWidgets = value['widgets'];
    final widgets = <DashboardWidget>[];
    if (rawWidgets is List) {
      final seen = <String>{};
      for (final item in rawWidgets) {
        if (item is! Map) continue;
        final type = item['type'];
        final format = item['format'];
        final def = dashboardWidgetDefinitions[type];
        if (def == null || format is! String || !def.formats.contains(format)) {
          continue;
        }
        final widget = DashboardWidget(def.type, format);
        if (!seen.add(widget.key)) continue;
        widgets.add(widget);
      }
    }
    return DashboardConfig(
      showGeneralInfo: value['show_general_info'] != false,
      widgets: rawWidgets is List ? widgets : defaults.widgets,
    );
  }

  /// The widgets this viewer may see: all features on and read permission on
  /// the widget's matrix key. The data is still limited by the API rules.
  List<DashboardWidget> visibleWidgets({
    required bool Function(String feature) isFeatureEnabled,
    required bool Function(String permission) canRead,
  }) {
    return widgets.where((w) {
      final def = w.definition;
      if (def.features.any((f) => !isFeatureEnabled(f))) return false;
      final permission = def.permission;
      if (permission != null && !canRead(permission)) return false;
      return true;
    }).toList();
  }
}

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

  const DashboardListEntry({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.path,
    this.icon,
    this.color,
    this.chipText,
    this.chipColor,
  });
}
