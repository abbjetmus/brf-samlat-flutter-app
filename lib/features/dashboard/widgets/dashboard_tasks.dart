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

/// Short type label above each row ("SIGNERA", "ENKÄT" …).
const _kindLabels = <String, String>{
  'signature': 'Signera',
  'form': 'Enkät',
  'invoice': 'Faktura',
  'annual_wheel': 'Årshjul',
  'booking': 'Bokning',
  'issue': 'Felanmälan',
  'issues_open': 'Felanmälningar',
  'bookings_pending': 'Bokningar',
  'applications': 'Ansökningar',
  'protocols': 'Protokoll',
  'board_meeting': 'Styrelsemöte',
};

/// One block ("Att göra" or "Styrelsen") with its rows in a single card.
class DashboardTaskSection extends StatelessWidget {
  final String title;

  /// Small text to the right of the heading (e.g. "Kräver åtgärd").
  final String? trailing;

  /// Shows the number of rows in an amber pill beside the heading.
  final bool showCount;
  final List<DashboardTask> tasks;
  final void Function(DashboardTask task) onTap;

  const DashboardTaskSection({
    super.key,
    required this.title,
    required this.tasks,
    required this.onTap,
    this.trailing,
    this.showCount = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontSize: 18)),
            if (showCount) ...[
              const SizedBox(width: 8),
              Container(
                height: 22,
                constraints: const BoxConstraints(minWidth: 22),
                padding: const EdgeInsets.symmetric(horizontal: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.attentionFillOf(context),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '${tasks.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.attentionOf(context),
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (trailing case final text?)
              Text(text, style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: colors.outline),
          ),
          child: Column(
            children: [
              for (final (i, task) in tasks.indexed) ...[
                if (i > 0)
                  Divider(height: 1, indent: 16, color: colors.outline),
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
    final colors = theme.colorScheme;
    // warning/error = something the viewer has to do: amber label and the
    // verb ("Signera", "Besvara", "Granska") as a button.
    final needsYou = task.chipTone == 'warning' || task.chipTone == 'error';
    final kind = _kindLabels[task.kind];
    final overline = [
      ?kind,
      if (task.chipText != null && !needsYou) task.chipText!,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (overline.isNotEmpty) ...[
                    Text(
                      overline.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: needsYou
                            ? AppTheme.attentionOf(context)
                            : colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 16,
                      height: 1.3,
                    ),
                  ),
                  if (task.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      task.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (needsYou && task.chipText != null)
              FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  textStyle: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(task.chipText!),
              )
            else
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
