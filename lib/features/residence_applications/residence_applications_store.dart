import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' show DateFormat;
import 'package:pocketbase/pocketbase.dart' show ClientException, PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../../core/pagination/paginated.dart';
import '../../core/utils/pb_error.dart';
import '../../shared/widgets/status_chip.dart';
import '../auth/auth_store.dart' as auth;

/// A member's application for their residence (`residence_applications`):
/// andrahand, överlåtelse, medlemskap or ombyggnad. Mirrors the web
/// `ResidenceApplication`.
class ResidenceApplicationsRecord {
  final String id;
  final String collectionId;
  final String? created;
  final String association;
  final String residence;
  final String residenceAddress;
  final String type;
  final String applicant;
  final String status;
  final String? periodFrom;
  final String? periodTo;
  final String tenantName;
  final String tenantEmail;
  final String tenantPhone;
  final String reason;
  final String buyerNames;
  final String? accessDate;
  final double price;
  final String description;
  final List<String> attachments;
  final String decisionNote;
  final String? decidedAt;

  /// From `expand=applicant` / `expand=decided_by` (board view).
  final String applicantName;
  final String decidedByName;

  const ResidenceApplicationsRecord({
    required this.id,
    this.collectionId = '',
    this.created,
    required this.association,
    required this.residence,
    this.residenceAddress = '',
    required this.type,
    required this.applicant,
    required this.status,
    this.periodFrom,
    this.periodTo,
    this.tenantName = '',
    this.tenantEmail = '',
    this.tenantPhone = '',
    this.reason = '',
    this.buyerNames = '',
    this.accessDate,
    this.price = 0,
    this.description = '',
    this.attachments = const [],
    this.decisionNote = '',
    this.decidedAt,
    this.applicantName = '',
    this.decidedByName = '',
  });

  /// The applicant may withdraw while the board hasn't decided.
  bool get isOpen => status == 'inskickad' || status == 'under behandling';

  /// Days until an approved sublet ends (null without an end date).
  int? get daysLeft {
    final end = DateTime.tryParse(periodTo ?? '');
    if (end == null) return null;
    final today = DateTime.now();
    final endDay = DateTime(end.year, end.month, end.day);
    return endDay.difference(DateTime(today.year, today.month, today.day)).inDays;
  }

  /// Approved sublets ending within 30 days need the board's attention.
  bool get endingSoon {
    if (type != 'andrahand' || status != 'beviljad') return false;
    final d = daysLeft;
    return d != null && d >= 0 && d <= 30;
  }

  factory ResidenceApplicationsRecord.fromJson(Map<String, dynamic> json) {
    String? date(String key) {
      final v = json[key] as String?;
      return v == null || v.isEmpty ? null : v;
    }

    final expand = json['expand'] as Map<String, dynamic>?;
    final residence = expand?['residence'] as Map<String, dynamic>?;
    final applicant = expand?['applicant'] as Map<String, dynamic>?;
    final decidedBy = expand?['decided_by'] as Map<String, dynamic>?;
    return ResidenceApplicationsRecord(
      id: json['id'] as String? ?? '',
      collectionId: json['collectionId'] as String? ?? '',
      created: date('created'),
      association: json['association'] as String? ?? '',
      residence: json['residence'] as String? ?? '',
      residenceAddress: residence?['street_address'] as String? ?? '',
      type: json['type'] as String? ?? 'andrahand',
      applicant: json['applicant'] as String? ?? '',
      status: json['status'] as String? ?? 'inskickad',
      periodFrom: date('period_from'),
      periodTo: date('period_to'),
      tenantName: json['tenant_name'] as String? ?? '',
      tenantEmail: json['tenant_email'] as String? ?? '',
      tenantPhone: json['tenant_phone'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      buyerNames: json['buyer_names'] as String? ?? '',
      accessDate: date('access_date'),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String? ?? '',
      attachments:
          (json['attachments'] as List?)?.whereType<String>().toList() ??
          const [],
      decisionNote: json['decision_note'] as String? ?? '',
      decidedAt: date('decided_at'),
      applicantName: applicant?['name'] as String? ?? '',
      decidedByName: decidedBy?['name'] as String? ?? '',
    );
  }
}

class ApplicationType {
  final String value;
  final String title;
  final String description;
  final IconData icon;

  const ApplicationType(this.value, this.title, this.description, this.icon);
}

const applicationTypes = <ApplicationType>[
  ApplicationType(
    'andrahand',
    'Andrahandsuthyrning',
    'Hyra ut bostaden i andra hand under en begränsad period.',
    Icons.key_outlined,
  ),
  ApplicationType(
    'överlåtelse',
    'Överlåtelse',
    'Bostadsrätten säljs eller överlåts till någon annan.',
    Icons.swap_horiz,
  ),
  ApplicationType(
    'medlemskap',
    'Medlemskap',
    'Ansökan om medlemskap i föreningen.',
    Icons.person_add_alt_outlined,
  ),
  ApplicationType(
    'ombyggnad',
    'Ombyggnad',
    'Väsentliga förändringar, t.ex. rivning av vägg eller flytt av kök/badrum.',
    Icons.handyman_outlined,
  ),
];

ApplicationType applicationTypeMeta(String? value) => applicationTypes
    .firstWhere((t) => t.value == value, orElse: () => applicationTypes.first);

const applicationStatusLabels = <String, String>{
  'inskickad': 'Inskickad',
  'under behandling': 'Under behandling',
  'beviljad': 'Beviljad',
  'avslagen': 'Avslagen',
  'återkallad': 'Återkallad',
};

StatusTone applicationStatusTone(String status) => switch (status) {
  'inskickad' => StatusTone.info,
  'under behandling' => StatusTone.warning,
  'beviljad' => StatusTone.success,
  'avslagen' => StatusTone.danger,
  _ => StatusTone.neutral,
};

/// Status filter of the board view (web: residence-applications/index.vue).
enum ApplicationFilter {
  active('Att hantera'),
  all('Alla'),
  inskickad('Inskickad'),
  underBehandling('Under behandling'),
  beviljad('Beviljad'),
  avslagen('Avslagen'),
  aterkallad('Återkallad');

  const ApplicationFilter(this.label);
  final String label;

  String? get status => switch (this) {
    inskickad => 'inskickad',
    underBehandling => 'under behandling',
    beviljad => 'beviljad',
    avslagen => 'avslagen',
    aterkallad => 'återkallad',
    _ => null,
  };
}

/// Members see their own applications ([mine], filtered on `applicant`).
/// Those with `residence_applications` update (the board) also get [all], every
/// application in the association, and can decide on them.
class ResidenceApplicationsStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  ResidenceApplicationsStore(this._pb, this._authStore);

  late final _mine = Paginated<ResidenceApplicationsRecord>((
    page,
    perPage,
  ) async {
    final user = _authStore.currentUser.value;
    final res = await _pb
        .collection(Collections.residenceApplications)
        .getList(
          page: page,
          perPage: perPage,
          filter: _pb.filter('association = {:a} && applicant = {:u}', {
            'a': user?.association ?? '',
            'u': user?.id ?? '',
          }),
          sort: '-created',
          expand: 'residence',
        );
    return PageResult(
      res.items
          .map((r) => ResidenceApplicationsRecord.fromJson(r.toJson()))
          .toList(),
      res.totalPages,
    );
  });

  final filter = ref<ApplicationFilter>(ApplicationFilter.active);
  final typeFilter = ref<String?>(null);

  late final _all = Paginated<ResidenceApplicationsRecord>((
    page,
    perPage,
  ) async {
    final parts = ['association = {:a}'];
    final params = <String, dynamic>{
      'a': _authStore.currentUser.value?.association ?? '',
    };
    final f = filter.value;
    if (f == ApplicationFilter.active) {
      // Open applications, plus approved sublets ending within 30 days.
      final day = DateFormat('yyyy-MM-dd');
      final now = DateTime.now();
      parts.add(
        '(status = "inskickad" || status = "under behandling" || '
        '(type = "andrahand" && status = "beviljad" && '
        'period_to >= {:today} && period_to <= {:soon}))',
      );
      params['today'] = '${day.format(now)} 00:00:00.000Z';
      params['soon'] =
          '${day.format(now.add(const Duration(days: 30)))} 23:59:59.999Z';
    } else if (f.status != null) {
      parts.add('status = {:s}');
      params['s'] = f.status;
    }
    if (typeFilter.value != null) {
      parts.add('type = {:t}');
      params['t'] = typeFilter.value;
    }
    final res = await _pb
        .collection(Collections.residenceApplications)
        .getList(
          page: page,
          perPage: perPage,
          filter: _pb.filter(parts.join(' && '), params),
          sort: '-created',
          expand: 'residence,applicant',
        );
    return PageResult(
      res.items
          .map((r) => ResidenceApplicationsRecord.fromJson(r.toJson()))
          .toList(),
      res.totalPages,
    );
  });

  Ref<List<ResidenceApplicationsRecord>> get all => _all.items;
  Ref<bool> get allLoading => _all.loading;
  Ref<bool> get allLoadingMore => _all.loadingMore;
  Ref<bool> get allHasMore => _all.hasMore;
  Future<void> refreshAll() => _all.refresh();
  Future<void> loadMoreAll() => _all.loadMore();

  final _current = ref<ResidenceApplicationsRecord?>(null);

  Ref<List<ResidenceApplicationsRecord>> get mine => _mine.items;
  Ref<bool> get loading => _mine.loading;
  Ref<bool> get loadingMore => _mine.loadingMore;
  Ref<bool> get hasMore => _mine.hasMore;
  Ref<ResidenceApplicationsRecord?> get current => _current;

  Future<void> refresh() => _mine.refresh();
  Future<void> loadMore() => _mine.loadMore();

  Future<bool> load(String id) async {
    try {
      final record = await _pb
          .collection(Collections.residenceApplications)
          .getOne(id, expand: 'residence,applicant,decided_by');
      _current.value = ResidenceApplicationsRecord.fromJson(record.toJson());
      return true;
    } catch (e) {
      debugPrint('ResidenceApplicationsStore: Error loading $id: $e');
      _current.value = null;
      return false;
    }
  }

  /// The residences the current user lives in — the only ones they may apply
  /// for (the server enforces the same).
  Future<List<ResidencesRecord>> ownResidences() async {
    final user = _authStore.currentUser.value;
    if (user == null) return [];
    try {
      final records = await _pb
          .collection(Collections.residences)
          .getFullList(
            filter: _pb.filter('association = {:a} && users.id ?= {:u}', {
              'a': user.association,
              'u': user.id,
            }),
            sort: 'street_address',
          );
      return records
          .map((r) => ResidencesRecord.fromJson(r.toJson()))
          .toList();
    } catch (e) {
      debugPrint('ResidenceApplicationsStore: Error loading residences: $e');
      return [];
    }
  }

  /// Returns null on success, otherwise an error message for the user.
  /// Applicant, status and decision fields are set by the server.
  Future<String?> create(
    Map<String, dynamic> body,
    List<http.MultipartFile> files,
  ) async {
    try {
      await _pb
          .collection(Collections.residenceApplications)
          .create(
            body: {
              ...body,
              'association': _authStore.currentUser.value?.association ?? '',
            },
            files: files,
          );
      return null;
    } on ClientException catch (e) {
      debugPrint('ResidenceApplicationsStore: Error creating: $e');
      final message = e.response['message'] as String?;
      return message == null || message.isEmpty
          ? 'Kunde inte skicka ansökan.'
          : message;
    } catch (e) {
      debugPrint('ResidenceApplicationsStore: Error creating: $e');
      return 'Kunde inte skicka ansökan.';
    }
  }

  /// The board's decision. An approved sublet may be granted for a shorter
  /// period than applied for ([periodTo], YYYY-MM-DD). The server sets
  /// decided_by/decided_at and notifies the applicant.
  Future<String?> decide(
    String id, {
    required String status,
    required String note,
    String? periodTo,
  }) async {
    try {
      await _pb
          .collection(Collections.residenceApplications)
          .update(
            id,
            body: {
              'status': status,
              'decision_note': note,
              if (periodTo != null) 'period_to': '$periodTo 00:00:00.000Z',
            },
          );
      await load(id);
      return null;
    } catch (e) {
      debugPrint('ResidenceApplicationsStore: Error deciding: $e');
      return pbErrorMessage(e, 'Kunde inte spara beslutet.');
    }
  }

  Future<String?> delete(String id) async {
    try {
      await _pb.collection(Collections.residenceApplications).delete(id);
      return null;
    } catch (e) {
      debugPrint('ResidenceApplicationsStore: Error deleting: $e');
      return pbErrorMessage(e, 'Kunde inte radera ansökan.');
    }
  }

  Future<bool> withdraw(String id) async {
    try {
      await _pb.send(
        '/api/residence-applications/$id/withdraw',
        method: 'POST',
      );
      await load(id);
      return true;
    } catch (e) {
      debugPrint('ResidenceApplicationsStore: Error withdrawing: $e');
      return false;
    }
  }
}
