import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../../core/pagination/paginated.dart';
import '../../core/utils/pb_error.dart';
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

  /// Issues (felanmälningar) linked to this action.
  final List<String> relatedIssues;

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
    this.relatedIssues = const [],
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
      relatedIssues:
          (json['related_issues'] as List?)?.whereType<String>().toList() ??
          const [],
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

/// What the create/edit sheet saves. Only these fields are written, so fields
/// the app doesn't edit (ansvarig, bilagor, årshjulskoppling) are kept as they
/// are on update.
class MaintenancePlanItemInput {
  final String title;
  final String component;
  final String status;
  final int plannedYear;
  final int intervalYears;
  final double estimatedCost;
  final double actualCost;
  final String description;

  const MaintenancePlanItemInput({
    required this.title,
    required this.component,
    required this.status,
    required this.plannedYear,
    required this.intervalYears,
    required this.estimatedCost,
    required this.actualCost,
    required this.description,
  });

  Map<String, dynamic> toBody() => {
    'title': title,
    'component': component,
    'status': status,
    'planned_year': plannedYear,
    'interval_years': intervalYears,
    'estimated_cost': estimatedCost,
    'actual_cost': actualCost,
    'description': description,
  };
}

/// The maintenance plan for members with `maintenance_plan` read access
/// (admins have it by default). Those with create/update/delete can also edit
/// it, mark actions as done and link issues; the server checks the same
/// permissions (permissions_enforcement.pb.js, maintenance_plan_utils.js).
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

  /// Returns null on success, otherwise an error message.
  Future<String?> save(String? id, MaintenancePlanItemInput input) async {
    try {
      final body = {
        ...input.toBody(),
        'association': _authStore.association.value?.id ?? '',
      };
      if (id == null) {
        await _pb.collection(Collections.maintenancePlanItems).create(body: body);
      } else {
        await _pb
            .collection(Collections.maintenancePlanItems)
            .update(id, body: body);
      }
      return null;
    } catch (e) {
      debugPrint('MaintenancePlanStore: Error saving: $e');
      return pbErrorMessage(e, 'Kunde inte spara åtgärden.');
    }
  }

  Future<String?> delete(String id) async {
    try {
      await _pb.collection(Collections.maintenancePlanItems).delete(id);
      return null;
    } catch (e) {
      debugPrint('MaintenancePlanStore: Error deleting: $e');
      return pbErrorMessage(e, 'Kunde inte radera åtgärden.');
    }
  }

  /// "Markera som klar" (POST /api/maintenance-plan/{id}/complete). For a
  /// recurring action the server can create the next occurrence. Returns the
  /// next occurrence's planned year (or null) on success.
  Future<({String? error, int? nextYear})> complete(
    String id, {
    required DateTime completedAt,
    double? actualCost,
    required bool createNext,
    int? nextYear,
  }) async {
    try {
      final res = await _pb.send(
        '/api/maintenance-plan/$id/complete',
        method: 'POST',
        body: {
          'completed_at': DateFormat('yyyy-MM-dd').format(completedAt),
          'actual_cost': actualCost,
          'create_next': createNext,
          'next_year': nextYear,
        },
      );
      final next = res is Map ? res['next'] : null;
      final year = next is Map ? (next['planned_year'] as num?)?.toInt() : null;
      return (error: null, nextYear: year);
    } catch (e) {
      debugPrint('MaintenancePlanStore: Error completing: $e');
      return (
        error: pbErrorMessage(e, 'Kunde inte markera som klar.'),
        nextYear: null,
      );
    }
  }

  /// Every action in the plan (for the "Koppla" picker on an issue).
  Future<List<MaintenancePlanItemsRecord>> allItems() async {
    final assocId = _authStore.association.value?.id ?? '';
    final records = await _pb
        .collection(Collections.maintenancePlanItems)
        .getFullList(
          filter: _pb.filter('association = {:a}', {'a': assocId}),
          sort: 'planned_year,title',
        );
    return records
        .map((r) => MaintenancePlanItemsRecord.fromJson(r.toJson()))
        .toList();
  }

  /// The actions an issue is linked to. Throws on failure.
  Future<List<MaintenancePlanItemsRecord>> forIssue(String issueId) async {
    final records = await _pb
        .collection(Collections.maintenancePlanItems)
        .getFullList(
          filter: _pb.filter('related_issues ~ {:id}', {'id': issueId}),
          sort: 'planned_year',
        );
    return records
        .map((r) => MaintenancePlanItemsRecord.fromJson(r.toJson()))
        .toList();
  }

  /// Links ([link] = true) or unlinks an issue from an action.
  Future<String?> linkIssue(String itemId, String issueId, bool link) async {
    try {
      await _pb
          .collection(Collections.maintenancePlanItems)
          .update(
            itemId,
            body: {link ? 'related_issues+' : 'related_issues-': issueId},
          );
      return null;
    } catch (e) {
      debugPrint('MaintenancePlanStore: Error linking issue: $e');
      return pbErrorMessage(
        e,
        link ? 'Kunde inte koppla ärendet.' : 'Kunde inte ta bort kopplingen.',
      );
    }
  }
}
