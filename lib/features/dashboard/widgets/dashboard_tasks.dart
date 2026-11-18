import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Startsidans fasta block "För dig" och "Kräver åtgärd". Innehållet räknas ut
/// av brf-samlat-pb (GET /api/dashboard/tasks,
/// pb_hooks/utils/dashboard_tasks_utils.js) utifrån behörigheter och påslagna
/// funktioner. Samma block finns på webben
/// (brf-samlat-nuxt-app components/admin/DashboardTasks.vue).
class DashboardTask {
  final String key;
  final String kind;
  final String title;
  final String subtitle;
  final String? chipText;
  final String? chipTone;

  /// Route in the app.
  final String path;

  const DashboardTask({
    required this.key,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.path,
    this.chipText,
    this.chipTone,
  });

  factory DashboardTask.fromJson(Map<String, dynamic> json) {
    final chip = json['chip'];
    return DashboardTask(
      key: json['key'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      path: json['app'] as String? ?? '',
      chipText: chip is Map ? chip['text'] as String? : null,
      chipTone: chip is Map ? chip['tone'] as String? : null,
    );
  }

  static List<DashboardTask> listFrom(Object? raw) => raw is List
      ? raw
            .whereType<Map>()
            .map((m) => DashboardTask.fromJson(Map<String, dynamic>.from(m)))
            .where((t) => t.path.isNotEmpty)
            .toList()
      : const [];
}

class DashboardTasks {
  final List<DashboardTask> personal;
  final List<DashboardTask> board;

  const DashboardTasks({this.personal = const [], this.board = const []});

  bool get isEmpty => personal.isEmpty && board.isEmpty;

  factory DashboardTasks.fromJson(Map<String, dynamic> json) => DashboardTasks(
    personal: DashboardTask.listFrom(json['personal']),
    board: DashboardTask.listFrom(json['board']),
  );
}

const _kindStyles = <String, (IconData, Color)>{
  'signature': (Icons.draw_outlined, Color(0xFFF59E0B)),
  'form': (Icons.fact_check_outlined, Color(0xFF7C3AED)),
  'invoice': (Icons.receipt_long_outlined, Color(0xFFEF4444)),
  'annual_wheel': (Icons.donut_large_outlined, Color(0xFF8B5CF6)),
  'booking': (Icons.event_available_outlined, Color(0xFF10B981)),
  'issue': (Icons.report_problem_outlined, Color(0xFFF59E0B)),
  'issues_open': (Icons.report_problem_outlined, Color(0xFFEF4444)),
  'bookings_pending': (Icons.pending_actions_outlined, Color(0xFFF59E0B)),
  'applications': (Icons.assignment_outlined, Color(0xFF0D9488)),
  'protocols': (Icons.draw_outlined, Color(0xFF0EA5E9)),
  'board_meeting': (Icons.groups_outlined, Color(0xFF0EA5E9)),
};

const _toneColors = <String, Color>{
  'warning': Color(0xFFF59E0B),
  'error': Color(0xFFEF4444),
  'success': Color(0xFF22C55E),
  'info': Color(0xFF3B82F6),
};

/// One block ("För dig" or "Kräver åtgärd") with its rows in a single card.
class DashboardTaskSection extends StatelessWidget {
  final String title;
  final List<DashboardTask> tasks;
  final void Function(DashboardTask task) onTap;

  const DashboardTaskSection({
    super.key,
    required this.title,
    required this.tasks,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Column(
            children: [
              for (final (i, task) in tasks.indexed) ...[
                if (i > 0) Divider(height: 1, color: theme.colorScheme.outline),
                _TaskRow(task: task, onTap: () => onTap(task)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  final DashboardTask task;
  final VoidCallback onTap;

  const _TaskRow({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) =
        _kindStyles[task.kind] ??
        (Icons.info_outline, theme.colorScheme.primary);
    final chipColor = _toneColors[task.chipTone] ?? theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (task.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      task.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (task.chipText != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: chipColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        task.chipText!,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: chipColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
