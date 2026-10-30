import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/paginated_list_view.dart';
import '../../../shared/widgets/status_chip.dart';
import '../maintenance_plan_store.dart';

/// Underhållsplanen, read-only and grouped by year. Mirrors the "Per år" view
/// on the web, which is also where the board edits the plan.
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

    return (context) {
      final items = store.items.value;

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
            children: const [
              SizedBox(height: 120),
              Icon(Icons.construction_outlined, size: 48),
              SizedBox(height: 12),
              Center(child: Text('Underhållsplanen är tom.')),
            ],
          ),
        );
      } else {
        body = PaginatedListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: rows.length,
          hasMore: store.hasMore.value,
          loadingMore: store.loadingMore.value,
          onLoadMore: store.loadMore,
          onRefresh: store.refresh,
          itemBuilder: (context, index) {
            final row = rows[index];
            if (row.item == null) {
              return _YearHeader(
                year: row.year!,
                total: row.total,
                isCurrent: row.year == currentYear,
                color: theme.value.colorScheme.primary,
              );
            }
            return _ItemTile(item: row.item!);
          },
        );
      }

      return GradientScaffold(
        title: 'Underhållsplan',
        subtitle: 'Planerat underhåll år för år',
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

  const _ItemTile({required this.item});

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
        trailing: StatusChip(
          label: maintenanceStatusLabels[item.status] ?? item.status,
          tone: _tone,
        ),
      ),
    );
  }
}
