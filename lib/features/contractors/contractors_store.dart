import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../../core/pagination/paginated.dart';
import '../../core/utils/pb_error.dart';
import '../auth/auth_store.dart' as auth;

/// A contractor in the association's register (`contractors`). Mirrors the
/// web `Contractor`. Only the board (permission key `contractors`) sees these.
class ContractorsRecord {
  final String id;
  final String name;
  final String trade;
  final String contactName;
  final String email;
  final String phone;
  final String notes;

  const ContractorsRecord({
    required this.id,
    required this.name,
    required this.trade,
    this.contactName = '',
    required this.email,
    this.phone = '',
    this.notes = '',
  });

  factory ContractorsRecord.fromJson(Map<String, dynamic> json) {
    return ContractorsRecord(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      trade: json['trade'] as String? ?? 'övrigt',
      contactName: json['contact_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }
}

/// One time an issue was sent to a contractor (`issue_forwards`). Created and
/// revoked only through the server routes.
class IssueForwardsRecord {
  final String id;
  final String issue;
  final String contractorName;
  final String contractorEmail;
  final String sentBy;
  final String? sentAt;
  final String message;
  final bool includeAddress;
  final bool includeAttachments;
  final String? expiresAt;
  final bool revoked;

  /// mottagen | planerad | atgardad, empty when the contractor hasn't answered.
  final String lastStatus;
  final String? plannedDate;

  const IssueForwardsRecord({
    required this.id,
    required this.issue,
    this.contractorName = '',
    this.contractorEmail = '',
    this.sentBy = '',
    this.sentAt,
    this.message = '',
    this.includeAddress = false,
    this.includeAttachments = false,
    this.expiresAt,
    this.revoked = false,
    this.lastStatus = '',
    this.plannedDate,
  });

  bool get isExpired {
    final expires = DateTime.tryParse(expiresAt ?? '');
    return expires == null || expires.isBefore(DateTime.now());
  }

  factory IssueForwardsRecord.fromJson(Map<String, dynamic> json) {
    String? date(String key) {
      final v = json[key] as String?;
      return v == null || v.isEmpty ? null : v;
    }

    return IssueForwardsRecord(
      id: json['id'] as String? ?? '',
      issue: json['issue'] as String? ?? '',
      contractorName: json['contractor_name'] as String? ?? '',
      contractorEmail: json['contractor_email'] as String? ?? '',
      sentBy: json['sent_by'] as String? ?? '',
      sentAt: date('sent_at'),
      message: json['message'] as String? ?? '',
      includeAddress: json['include_address'] as bool? ?? false,
      includeAttachments: json['include_attachments'] as bool? ?? false,
      expiresAt: date('expires_at'),
      revoked: json['revoked'] as bool? ?? false,
      lastStatus: json['last_status'] as String? ?? '',
      plannedDate: date('planned_date'),
    );
  }
}

/// The result of "Skicka till leverantör". The status link is only returned
/// once, right after sending.
class ForwardResult {
  final IssueForwardsRecord forward;
  final String link;
  final bool emailSent;

  const ForwardResult(this.forward, this.link, this.emailSent);
}

class ContractorTrade {
  final String value;
  final String title;
  final IconData icon;
  const ContractorTrade(this.value, this.title, this.icon);
}

const contractorTrades = <ContractorTrade>[
  ContractorTrade('rörmokare', 'Rörmokare', Icons.plumbing_outlined),
  ContractorTrade('elektriker', 'Elektriker', Icons.bolt_outlined),
  ContractorTrade('hiss', 'Hiss', Icons.elevator_outlined),
  ContractorTrade('städ', 'Städ', Icons.cleaning_services_outlined),
  ContractorTrade('låssmed', 'Låssmed', Icons.key_outlined),
  ContractorTrade('ventilation', 'Ventilation', Icons.air_outlined),
  ContractorTrade('mark', 'Mark & utemiljö', Icons.grass_outlined),
  ContractorTrade('övrigt', 'Övrigt', Icons.build_outlined),
];

ContractorTrade contractorTradeMeta(String? value) => contractorTrades
    .firstWhere((t) => t.value == value, orElse: () => contractorTrades.last);

const forwardStatusLabels = <String, String>{
  'mottagen': 'Mottagen',
  'planerad': 'Planerad',
  'atgardad': 'Åtgärdad',
};

class ContractorsStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  ContractorsStore(this._pb, this._authStore);

  final search = ref<String>('');
  final trade = ref<String?>(null);

  late final _contractors = Paginated<ContractorsRecord>((page, perPage) async {
    final parts = ['association = {:a}'];
    final params = <String, dynamic>{
      'a': _authStore.association.value?.id ?? '',
    };
    if (trade.value != null) {
      parts.add('trade = {:t}');
      params['t'] = trade.value;
    }
    final q = search.value.trim();
    if (q.isNotEmpty) {
      parts.add(
        '(name ~ {:q} || contact_name ~ {:q} || email ~ {:q} || phone ~ {:q} || notes ~ {:q})',
      );
      params['q'] = q;
    }
    final res = await _pb
        .collection(Collections.contractors)
        .getList(
          page: page,
          perPage: perPage,
          filter: _pb.filter(parts.join(' && '), params),
          sort: 'name',
        );
    return PageResult(
      res.items.map((r) => ContractorsRecord.fromJson(r.toJson())).toList(),
      res.totalPages,
    );
  }, pageSize: 30);

  Ref<List<ContractorsRecord>> get contractors => _contractors.items;
  Ref<bool> get loading => _contractors.loading;
  Ref<bool> get loadingMore => _contractors.loadingMore;
  Ref<bool> get hasMore => _contractors.hasMore;

  Future<void> refresh() => _contractors.refresh();
  Future<void> loadMore() => _contractors.loadMore();

  /// Every contractor, for the picker in "Skicka till leverantör". Throws.
  Future<List<ContractorsRecord>> all() async {
    final records = await _pb
        .collection(Collections.contractors)
        .getFullList(
          filter: _pb.filter('association = {:a}', {
            'a': _authStore.association.value?.id ?? '',
          }),
          sort: 'name',
        );
    return records.map((r) => ContractorsRecord.fromJson(r.toJson())).toList();
  }

  /// Creates ([id] null) or updates a contractor. Null on success.
  Future<String?> save(String? id, Map<String, dynamic> body) async {
    try {
      final payload = {
        ...body,
        'association': _authStore.association.value?.id ?? '',
      };
      if (id == null) {
        await _pb.collection(Collections.contractors).create(body: payload);
      } else {
        await _pb.collection(Collections.contractors).update(id, body: payload);
      }
      return null;
    } catch (e) {
      debugPrint('ContractorsStore: Error saving: $e');
      return pbErrorMessage(e, 'Kunde inte spara leverantören.');
    }
  }

  Future<String?> delete(String id) async {
    try {
      await _pb.collection(Collections.contractors).delete(id);
      return null;
    } catch (e) {
      debugPrint('ContractorsStore: Error deleting: $e');
      return pbErrorMessage(e, 'Kunde inte radera leverantören.');
    }
  }

  /// The issue's forward history, newest first. Throws.
  Future<List<IssueForwardsRecord>> forwards(String issueId) async {
    final records = await _pb
        .collection(Collections.issueForwards)
        .getFullList(
          filter: _pb.filter('issue = {:i}', {'i': issueId}),
          sort: '-sent_at',
        );
    return records
        .map((r) => IssueForwardsRecord.fromJson(r.toJson()))
        .toList();
  }

  /// POST /api/issues/{id}/forward.
  Future<({ForwardResult? result, String? error})> forward(
    String issueId, {
    required String contractorId,
    required String message,
    required bool includeAddress,
    required bool includeAttachments,
  }) async {
    try {
      final res = await _pb.send(
        '/api/issues/$issueId/forward',
        method: 'POST',
        body: {
          'contractorId': contractorId,
          'message': message,
          'includeAddress': includeAddress,
          'includeAttachments': includeAttachments,
        },
      );
      final map = res as Map<String, dynamic>;
      return (
        result: ForwardResult(
          IssueForwardsRecord.fromJson(
            (map['forward'] as Map).cast<String, dynamic>(),
          ),
          map['link'] as String? ?? '',
          map['email_sent'] == true,
        ),
        error: null,
      );
    } catch (e) {
      debugPrint('ContractorsStore: Error forwarding: $e');
      return (
        result: null,
        error: pbErrorMessage(e, 'Kunde inte skicka ärendet.'),
      );
    }
  }

  /// POST /api/issue-forwards/{id}/revoke.
  Future<String?> revoke(String forwardId) async {
    try {
      await _pb.send('/api/issue-forwards/$forwardId/revoke', method: 'POST');
      return null;
    } catch (e) {
      debugPrint('ContractorsStore: Error revoking: $e');
      return pbErrorMessage(e, 'Kunde inte återkalla länken.');
    }
  }
}
