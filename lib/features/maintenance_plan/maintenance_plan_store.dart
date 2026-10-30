import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../../core/pagination/paginated.dart';
import '../auth/auth_store.dart' as auth;

/// One action in the association's maintenance plan (`maintenance_plan_items`).
/// Mirrors the web `MaintenancePlanItem`.
class MaintenancePlanItemsRecord {
  final String id;
  final String association;
  final String title;

  /// tak | fasad | fönster | stammar | hiss | ventilation | el | mark |
  /// tvättstuga | övrigt
  final String component;
  final String description;
  final int plannedYear;

  /// 0 = one-off action.
  final int intervalYears;
  final double estimatedCost;
  final double actualCost;

  /// planerad | beslutad | pågår | klar | uppskjuten
  final String status;
  final String? completedAt;

  const MaintenancePlanItemsRecord({
    required this.id,
    required this.association,
    required this.title,
    required this.component,
    this.description = '',
    required this.plannedYear,
    this.intervalYears = 0,
    this.estimatedCost = 0,
    this.actualCost = 0,
    required this.status,
    this.completedAt,
  });

  /// Actual cost once done (when known), otherwise the estimate.
  double get cost =>
      status == 'klar' && actualCost > 0 ? actualCost : estimatedCost;

  factory MaintenancePlanItemsRecord.fromJson(Map<String, dynamic> json) {
    final completedAt = json['completed_at'] as String?;
    return MaintenancePlanItemsRecord(
      id: json['id'] as String? ?? '',
      association: json['association'] as String? ?? '',
      title: json['title'] as String? ?? '',
      component: json['component'] as String? ?? 'övrigt',
      description: json['description'] as String? ?? '',
      plannedYear: (json['planned_year'] as num?)?.toInt() ?? 0,
      intervalYears: (json['interval_years'] as num?)?.toInt() ?? 0,
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble() ?? 0,
      actualCost: (json['actual_cost'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'planerad',
      completedAt: completedAt == null || completedAt.isEmpty
          ? null
          : completedAt,
    );
  }
}

class MaintenanceComponent {
  final String value;
  final String title;
  final IconData icon;

  const MaintenanceComponent(this.value, this.title, this.icon);
}

const maintenanceComponents = <MaintenanceComponent>[
  MaintenanceComponent('tak', 'Tak', Icons.roofing_outlined),
  MaintenanceComponent('fasad', 'Fasad', Icons.home_work_outlined),
  MaintenanceComponent('fönster', 'Fönster', Icons.window_outlined),
  MaintenanceComponent('stammar', 'Stammar', Icons.plumbing_outlined),
  MaintenanceComponent('hiss', 'Hiss', Icons.elevator_outlined),
  MaintenanceComponent('ventilation', 'Ventilation', Icons.air_outlined),
  MaintenanceComponent('el', 'El', Icons.electrical_services_outlined),
  MaintenanceComponent('mark', 'Mark', Icons.grass_outlined),
  MaintenanceComponent(
    'tvättstuga',
    'Tvättstuga',
    Icons.local_laundry_service_outlined,
  ),
  MaintenanceComponent('övrigt', 'Övrigt', Icons.more_horiz),
];

MaintenanceComponent maintenanceComponentMeta(String? value) =>
    maintenanceComponents.firstWhere(
      (c) => c.value == value,
      orElse: () => maintenanceComponents.last,
    );

const maintenanceStatusLabels = <String, String>{
  'planerad': 'Planerad',
  'beslutad': 'Beslutad',
  'pågår': 'Pågår',
  'klar': 'Klar',
  'uppskjuten': 'Uppskjuten',
};

final _sek = NumberFormat.currency(
  locale: 'sv_SE',
  symbol: 'kr',
  decimalDigits: 0,
);

String formatSek(double value) => _sek.format(value);

/// Read-only view of the maintenance plan for members who have been given
/// `maintenance_plan` read access (admins have it by default). Editing is done
/// in the web admin.
class MaintenancePlanStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  MaintenancePlanStore(this._pb, this._authStore);

  late final _items = Paginated<MaintenancePlanItemsRecord>((
    page,
    perPage,
  ) async {
    final assocId = _authStore.association.value?.id ?? '';
    final res = await _pb
        .collection(Collections.maintenancePlanItems)
        .getList(
          page: page,
          perPage: perPage,
          filter: _pb.filter('association = {:a}', {'a': assocId}),
          // Year first, so the page can group rows under a year header.
          sort: 'planned_year,title',
        );
    return PageResult(
      res.items
          .map((r) => MaintenancePlanItemsRecord.fromJson(r.toJson()))
          .toList(),
      res.totalPages,
    );
  }, pageSize: 50);

  Ref<List<MaintenancePlanItemsRecord>> get items => _items.items;
  Ref<bool> get loading => _items.loading;
  Ref<bool> get loadingMore => _items.loadingMore;
  Ref<bool> get hasMore => _items.hasMore;

  Future<void> refresh() => _items.refresh();
  Future<void> loadMore() => _items.loadMore();
}
