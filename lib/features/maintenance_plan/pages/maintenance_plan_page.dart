import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/entity_action_menu.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/help_tip.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import '../../../shared/widgets/status_chip.dart';
import '../maintenance_plan_store.dart';
import '../widgets/maintenance_complete_sheet.dart';
import '../widgets/maintenance_item_sheet.dart';

/// Underhållsplanen grouped by year, like the "Per år" view on the web. Users
/// with `maintenance_plan` create/update/delete can add, edit, remove and mark
/// actions as done ("Markera som klar" creates the next occurrence of a
/// recurring action).
class MaintenancePlanPage extends CompositionWidget {
  static const String path = '/maintenance-plan';

  const MaintenancePlanPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final store = MaintenancePlanStore(
      inject(pocketBaseKey),
      inject(authStoreKey),
    );
    final authStore = inject(authStoreKey);
    final theme = useTheme();
    final currentYear = DateTime.now().year;

    // The association loads asynchronously on cold start — (re)load when known.
    watch(() => authStore.association.value?.id, (assocId, _) {
      if (assocId != null && assocId.isNotEmpty) store.refresh();
    }, immediate: true);

    final contextRef = useContext();

    void snack(String message) {
      final ctx = contextRef.value;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
    }

    Future<void> openEdit([MaintenancePlanItemsRecord? item]) async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final saved = await showAppBottomSheet<bool>(
        context: ctx,
        builder: (_) => MaintenanceItemSheet(
          item: item,
          defaultYear: currentYear,
          onSave: (input) => store.save(item?.id, input),
        ),
      );
      if (saved == true) {
        snack('Åtgärden sparad');
        await store.refresh();
      }
    }

    Future<void> openComplete(MaintenancePlanItemsRecord item) async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      int? plannedNext;
      final done = await showAppBottomSheet<bool>(
        context: ctx,
        builder: (_) => MaintenanceCompleteSheet(
          item: item,
          canCreate: authStore.hasPermission(
            'maintenance_plan',
            CrudOperation.create,
          ),
          onComplete:
              ({
                required completedAt,
                actualCost,
                required createNext,
                nextYear,
              }) async {
                final res = await store.complete(
                  item.id,
                  completedAt: completedAt,
                  actualCost: actualCost,
                  createNext: createNext,
                  nextYear: nextYear,
                );
                plannedNext = res.nextYear;
                return res.error;
              },
        ),
      );
      if (done == true) {
        snack(
          plannedNext != null
              ? 'Klar – nästa tillfälle planerat $plannedNext'
              : 'Åtgärden är klar',
        );
        await store.refresh();
      }
    }

    Future<void> remove(MaintenancePlanItemsRecord item) async {
      final ctx = contextRef.value;
      if (ctx == null) return;
      final ok = await showConfirmDialog(
        ctx,
        title: 'Radera åtgärd',
        message: 'Vill du radera "${item.title}" (${item.plannedYear})?',
        okLabel: 'Radera',
        okColor: Colors.red,
      );
      if (!ok) return;
      final message = await store.delete(item.id);
      snack(message ?? 'Åtgärden raderad');
      if (message == null) await store.refresh();
    }

    return (context) {
      final items = store.items.value;
      final canCreate = authStore.hasPermission(
        'maintenance_plan',
        CrudOperation.create,
      );
      final canUpdate = authStore.hasPermission(
        'maintenance_plan',
        CrudOperation.update,
      );
      final canDelete = authStore.hasPermission(
        'maintenance_plan',
        CrudOperation.delete,
      );
      final tip = HelpTip(
        id: 'maintenance-plan',
        padding: const EdgeInsets.only(bottom: 4),
        text: canUpdate
            ? 'Varje rad är en åtgärd ett visst år. Ange Återkommer vart X år '
                  'för åtgärder som görs regelbundet. När du väljer Markera som '
                  'klar i menyn skapas nästa tillfälle automatiskt.'
            : 'Varje rad är en åtgärd ett visst år, med beräknad kostnad. '
                  'Summan per år visas vid årtalet.',
      );

      // Flatten into a year header followed by that year's items. Totals are
      // over the loaded items; the page size is large enough that a year is
      // rarely split across pages.
      final rows = <_Row>[];
      int? year;
      for (final item in items) {
        if (item.plannedYear != year) {
          year = item.plannedYear;
          final total = items
              .where((i) => i.plannedYear == year)
              .fold<double>(0, (sum, i) => sum + i.cost);
          rows.add(_Row.header(year, total));
        }
        rows.add(_Row.item(item));
      }

      final Widget body;
      if (store.loading.value && items.isEmpty) {
        body = const Center(child: CircularProgressIndicator());
      } else if (items.isEmpty) {
        body = RefreshIndicator(
          onRefresh: store.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              tip,
              const SizedBox(height: 100),
              const Icon(Icons.construction_outlined, size: 48),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  canCreate
                      ? 'Underhållsplanen är tom. Tryck på + för att lägga till en åtgärd.'
                      : 'Underhållsplanen är tom.',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      } else {
        body = PaginatedListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: rows.length + 1,
          hasMore: store.hasMore.value,
          loadingMore: store.loadingMore.value,
          onLoadMore: store.loadMore,
          onRefresh: store.refresh,
          itemBuilder: (context, index) {
            if (index == 0) return tip;
            final row = rows[index - 1];
            if (row.item == null) {
              return _YearHeader(
                year: row.year!,
                total: row.total,
                isCurrent: row.year == currentYear,
                color: theme.value.colorScheme.primary,
              );
            }
            final item = row.item!;
            return _ItemTile(
              item: item,
              actions: [
                if (canUpdate && item.status != 'klar')
                  EntityAction(
                    icon: Icons.check_circle_outline,
                    label: 'Markera som klar',
                    onSelected: () => openComplete(item),
                  ),
                if (canUpdate) EntityAction.update(() => openEdit(item)),
                if (canDelete) EntityAction.delete(() => remove(item)),
              ],
            );
          },
        );
      }

      return GradientScaffold(
        title: 'Underhållsplan',
        subtitle: 'Planerat underhåll år för år',
        floatingActionButton: canCreate
            ? FloatingActionButton(
                onPressed: () => openEdit(),
                tooltip: 'Ny åtgärd',
                child: const Icon(Icons.add),
              )
            : null,
        body: body,
      );
    };
  }
}

class _Row {
  final int? year;
  final double total;
  final MaintenancePlanItemsRecord? item;

  const _Row.header(this.year, this.total) : item = null;
  const _Row.item(this.item) : year = null, total = 0;
}

class _YearHeader extends StatelessWidget {
  final int year;
  final double total;
  final bool isCurrent;
  final Color color;

  const _YearHeader({
    required this.year,
    required this.total,
    required this.isCurrent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Row(
        children: [
          Text(
            '$year',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isCurrent ? color : null,
            ),
          ),
          if (isCurrent) ...[
            const SizedBox(width: 8),
            const StatusChip(label: 'I år', tone: StatusTone.info),
          ],
          const Spacer(),
          Text(
            formatSek(total),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final MaintenancePlanItemsRecord item;
  final List<EntityAction> actions;

  const _ItemTile({required this.item, this.actions = const []});

  StatusTone get _tone => switch (item.status) {
    'klar' => StatusTone.success,
    'pågår' => StatusTone.warning,
    'beslutad' => StatusTone.info,
    'uppskjuten' => StatusTone.danger,
    _ => StatusTone.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final component = maintenanceComponentMeta(item.component);
    final details = <String>[
      component.title,
      if (item.intervalYears > 0) 'vart ${item.intervalYears}:e år',
      formatSek(item.cost),
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(component.icon),
        title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(details.join(' · ')),
            if (item.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusChip(
              label: maintenanceStatusLabels[item.status] ?? item.status,
              tone: _tone,
            ),
            EntityActionMenu(actions: actions),
          ],
        ),
      ),
    );
  }
}
