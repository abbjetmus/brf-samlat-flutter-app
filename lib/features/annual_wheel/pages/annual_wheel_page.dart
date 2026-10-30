import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/help_tip.dart';
import '../annual_wheel_store.dart';
import '../widgets/annual_wheel_chart.dart';
import '../widgets/annual_wheel_activity_sheet.dart';

/// Föreningens årshjul: the wheel, then the activities grouped by month with a
/// per-year checkbox. Mirrors the web /admin/annual-wheel page.
class AnnualWheelPage extends CompositionWidget {
  static const String path = '/annual-wheel';

  const AnnualWheelPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final store = inject(annualWheelStoreKey);
    final authStore = inject(authStoreKey);
    final usersStore = inject(usersStoreKey);
    final contextRef = useContext();
    final mediaQuery = useMediaQuery();
    final theme = useTheme();

    final users = ref<List<UsersRecord>>([]);
    final selectedMonth = ref<int?>(null);
    final toggling = ref<String?>(null);
    final seeding = ref(false);
    final now = DateTime.now();

    void snack(String message) {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
    }

    // The association loads asynchronously on cold start — (re)load when known.
    watch(() => authStore.association.value?.id, (assocId, _) {
      if (assocId != null && assocId.isNotEmpty) store.load(now.year);
    }, immediate: true);

    onMounted(() async {
      users.value = await usersStore.getAllAssociationUsers();
    });

    String userName(String? id) {
      final u = users.value.where((x) => x.id == id).firstOrNull;
      if (u == null) return 'Okänd';
      return u.name.isNotEmpty ? u.name : (u.email ?? 'Okänd');
    }

    Future<void> openEdit([AnnualWheelActivitiesRecord? activity]) async {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      final result = await showAppBottomSheet<AnnualWheelActivityInput>(
        context: ctx,
        builder: (_) => AnnualWheelActivitySheet(
          activity: activity,
          defaultMonth: selectedMonth.value ?? now.month,
          users: users.value,
        ),
      );
      if (result == null) return;
      final ok = await store.save(
        id: activity?.id,
        title: result.title,
        description: result.description,
        month: result.month,
        day: result.day,
        category: result.category,
        responsible: result.responsible,
        reminderDaysBefore: result.reminderDaysBefore,
      );
      snack(ok ? 'Aktiviteten sparad' : 'Kunde inte spara aktiviteten');
    }

    Future<void> remove(AnnualWheelActivitiesRecord activity) async {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      final ok = await showConfirmDialog(
        ctx,
        title: 'Radera aktivitet',
        message:
            'Vill du radera "${activity.title}" från årshjulet? Historiken för tidigare år försvinner också.',
        okLabel: 'Radera',
        okColor: Colors.red,
      );
      if (!ok) return;
      final deleted = await store.remove(activity.id);
      snack(deleted ? 'Aktiviteten raderad' : 'Kunde inte radera');
    }

    Future<void> toggle(String activityId, bool done) async {
      toggling.value = activityId;
      final ok = await store.setCompleted(activityId, done);
      toggling.value = null;
      if (!ok) snack('Kunde inte uppdatera');
    }

    Future<void> seed() async {
      seeding.value = true;
      final ok = await store.seedDefaults();
      seeding.value = false;
      snack(
        ok
            ? 'Standardaktiviteter tillagda'
            : 'Kunde inte lägga till aktiviteter',
      );
    }

    return (context) {
      final canCreate = authStore.hasPermission(
        'annual_wheel',
        CrudOperation.create,
      );
      final canUpdate = authStore.hasPermission(
        'annual_wheel',
        CrudOperation.update,
      );
      final canDelete = authStore.hasPermission(
        'annual_wheel',
        CrudOperation.delete,
      );
      // Avbockning skapar/raderar en completion-rad.
      final canCheck = canCreate && canDelete;

      final year = store.year.value;
      final activities = store.activities.value;
      final completedIds = {
        for (final c in store.completions.value) c.activity,
      };
      final sorted = store.sortedActivities;
      final visible = selectedMonth.value == null
          ? sorted
          : sorted.where((a) => a.month == selectedMonth.value).toList();

      final months = <int, List<AnnualWheelActivitiesRecord>>{};
      for (final a in visible) {
        months.putIfAbsent(a.month, () => []).add(a);
      }

      Widget body;
      if (store.loading.value && activities.isEmpty) {
        body = const Center(child: CircularProgressIndicator());
      } else if (activities.isEmpty) {
        body = _EmptyState(
          canCreate: canCreate,
          seeding: seeding.value,
          onSeed: seed,
          onCreate: () => openEdit(),
        );
      } else {
        body = RefreshIndicator(
          onRefresh: () => store.load(),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              88 + mediaQuery.value.padding.bottom,
            ),
            children: [
              HelpTip(
                id: 'annual-wheel',
                padding: const EdgeInsets.only(bottom: 4),
                text: canCheck
                    ? 'Bocka av en aktivitet när den är klar. Avbockningen '
                          'gäller bara det valda året. Tryck på en månad i '
                          'hjulet för att bara visa den månadens aktiviteter.'
                    : 'Tryck på en månad i hjulet för att bara visa den '
                          'månadens aktiviteter.',
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => store.load(year - 1),
                  ),
                  Text(
                    '$year',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => store.load(year + 1),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: AnnualWheelChart(
                  activities: activities,
                  completedIds: completedIds,
                  year: year,
                  selectedMonth: selectedMonth.value,
                  onSelect: (m) => selectedMonth.value = m,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  for (final c in annualWheelCategories)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 5, backgroundColor: c.color),
                        const SizedBox(width: 4),
                        Text(c.title, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: completedIds.length / activities.length,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  '${completedIds.length} av ${activities.length} klara $year',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              if (selectedMonth.value != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: InputChip(
                    label: Text(
                      'Visar ${monthNames[selectedMonth.value! - 1]}',
                    ),
                    onDeleted: () => selectedMonth.value = null,
                  ),
                ),
              ],
              for (final entry in months.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 6),
                  child: Text(
                    monthNames[entry.key - 1].toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: year == now.year && entry.key == now.month
                          ? theme.value.colorScheme.primary
                          : Colors.grey[700],
                    ),
                  ),
                ),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final (i, a) in entry.value.indexed) ...[
                        if (i > 0) const Divider(height: 1),
                        _ActivityTile(
                          activity: a,
                          done: completedIds.contains(a.id),
                          completionLabel: () {
                            final c = store.completionFor(a.id);
                            if (c?.completedAt == null) return null;
                            final date = AppDateUtils.formatDayAndMonth(
                              DateTime.tryParse(
                                c!.completedAt!,
                              )?.toLocal().toIso8601String(),
                            );
                            return c.completedBy == null
                                ? 'Klar $date'
                                : 'Klar $date · ${userName(c.completedBy)}';
                          }(),
                          responsibleName: a.responsible == null
                              ? null
                              : userName(a.responsible),
                          enabled: canCheck && toggling.value != a.id,
                          onToggle: (v) => toggle(a.id, v),
                          actions: [
                            if (canUpdate)
                              EntityAction.update(
                                () => openEdit(a),
                                label: 'Redigera',
                              ),
                            if (canDelete) EntityAction.delete(() => remove(a)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (months.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'Inga aktiviteter i ${monthNames[(selectedMonth.value ?? 1) - 1].toLowerCase()}.',
                    ),
                  ),
                ),
            ],
          ),
        );
      }

      return GradientScaffold(
        title: 'Årshjul',
        subtitle: 'Återkommande uppgifter över året',
        floatingActionButton: canCreate && activities.isNotEmpty
            ? FloatingActionButton(
                onPressed: () => openEdit(),
                child: const Icon(Icons.add),
              )
            : null,
        body: body,
      );
    };
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.activity,
    required this.done,
    required this.completionLabel,
    required this.responsibleName,
    required this.enabled,
    required this.onToggle,
    required this.actions,
  });

  final AnnualWheelActivitiesRecord activity;
  final bool done;
  final String? completionLabel;
  final String? responsibleName;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final List<EntityAction> actions;

  @override
  Widget build(BuildContext context) {
    final category = categoryMeta(activity.category);
    final tags = <(IconData, String, Color?)>[
      (category.icon, category.title, category.color),
      if (activity.day > 0)
        (
          Icons.event_outlined,
          '${activity.day} ${monthNames[activity.month - 1].toLowerCase()}',
          null,
        ),
      if (responsibleName != null)
        (Icons.person_outline, responsibleName!, null),
      if (activity.reminderDaysBefore > 0)
        (
          Icons.notifications_none,
          '${activity.reminderDaysBefore} dagar innan',
          null,
        ),
      if (completionLabel != null)
        (Icons.check, completionLabel!, const Color(0xFF16A34A)),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: done,
            onChanged: enabled ? (v) => onToggle(v ?? false) : null,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? Colors.grey : null,
                    ),
                  ),
                  if (activity.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      activity.description,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final (icon, label, color) in tags)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (color ?? Colors.grey).withValues(
                              alpha: 0.14,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 12,
                                color: color ?? Colors.grey[700],
                              ),
                              const SizedBox(width: 3),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: color ?? Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          EntityActionMenu(actions: actions),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.canCreate,
    required this.seeding,
    required this.onSeed,
    required this.onCreate,
  });

  final bool canCreate;
  final bool seeding;
  final VoidCallback onSeed;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.donut_large_outlined,
              size: 56,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            const Text(
              'Årshjulet är tomt',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Börja med en färdig lista med typiska uppgifter för en förening '
              '(bokslut, stämma, budget, besiktning …) och anpassa den, eller lägg till egna.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (canCreate) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: seeding ? null : onSeed,
                icon: seeding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high),
                label: const Text('Lägg till standardaktiviteter'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Egen aktivitet'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
