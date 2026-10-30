import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart' show ClientException, PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../../core/pagination/paginated.dart';
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
  });

  /// The applicant may withdraw while the board hasn't decided.
  bool get isOpen => status == 'inskickad' || status == 'under behandling';

  factory ResidenceApplicationsRecord.fromJson(Map<String, dynamic> json) {
    String? date(String key) {
      final v = json[key] as String?;
      return v == null || v.isEmpty ? null : v;
    }

    final expand = json['expand'] as Map<String, dynamic>?;
    final residence = expand?['residence'] as Map<String, dynamic>?;
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

/// The current user's own applications. The API rules already limit members to
/// their own; the explicit `applicant` filter keeps the app's list personal for
/// admins too (the board handles everyone's applications in the web admin).
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
          .getOne(id, expand: 'residence');
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
