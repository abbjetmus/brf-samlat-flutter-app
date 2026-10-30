import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../../core/pagination/paginated.dart';
import '../../core/utils/pb_error.dart';
import '../auth/auth_store.dart' as auth;

/// One row of the overview: the invoice plus the residence address (from the
/// template snapshot, or the expanded residence for older invoices).
class OverviewInvoice {
  final InvoicesRecord invoice;
  final String residenceAddress;

  const OverviewInvoice(this.invoice, this.residenceAddress);

  factory OverviewInvoice.fromJson(Map<String, dynamic> json) {
    final invoice = InvoicesRecord.fromJson(json);
    final expand = json['expand'] as Map<String, dynamic>?;
    final residence = expand?['residence'] as Map<String, dynamic>?;
    final fromSnapshot = invoice.templateSnapshot?.residenceStreetAddress ?? '';
    return OverviewInvoice(
      invoice,
      fromSnapshot.isNotEmpty
          ? fromSnapshot
          : (residence?['street_address'] as String? ?? ''),
    );
  }
}

/// Status filter of the overview. Mirrors INVOICE_STATUS_FILTERS on the web;
/// `forfallen` is not stored but follows from the due date.
enum InvoiceStatusFilter {
  alla('Alla'),
  utestaende('Obetalda (alla)'),
  obetald('Obetald'),
  delbetald('Delbetald'),
  forfallen('Förfallen'),
  betald('Betald');

  const InvoiceStatusFilter(this.label);
  final String label;
}

class InvoicePeriodPreset {
  final String title;
  final String from;
  final String to;
  const InvoicePeriodPreset(this.title, this.from, this.to);
}

String todayIso() => DateFormat('yyyy-MM-dd').format(DateTime.now());

List<InvoicePeriodPreset> invoicePeriodPresets() {
  final now = DateTime.now();
  final f = DateFormat('yyyy-MM-dd');
  final y = now.year;
  final m = now.month;
  // DateTime normalises month overflow, and day 0 is the last day of the
  // previous month.
  return [
    InvoicePeriodPreset('I år', '$y-01-01', '$y-12-31'),
    InvoicePeriodPreset(
      'Den här månaden',
      f.format(DateTime(y, m, 1)),
      f.format(DateTime(y, m + 1, 0)),
    ),
    InvoicePeriodPreset(
      'Nästa månad',
      f.format(DateTime(y, m + 1, 1)),
      f.format(DateTime(y, m + 2, 0)),
    ),
    InvoicePeriodPreset(
      'Förra månaden',
      f.format(DateTime(y, m - 1, 1)),
      f.format(DateTime(y, m, 0)),
    ),
    InvoicePeriodPreset('Förra året', '${y - 1}-01-01', '${y - 1}-12-31'),
    const InvoicePeriodPreset('Alla', '', ''),
  ];
}

const _months = [
  'januari',
  'februari',
  'mars',
  'april',
  'maj',
  'juni',
  'juli',
  'augusti',
  'september',
  'oktober',
  'november',
  'december',
];

/// "2026-11-01" -> "november 2026" (the invoice's period is the month of its
/// invoice date).
String invoicePeriodLabel(String date) {
  final m = RegExp(r'^(\d{4})-(\d{2})').firstMatch(date);
  if (m == null) return date;
  final month = int.parse(m.group(2)!);
  return '${_months[month - 1]} ${m.group(1)}';
}

class InvoiceOverviewTotals {
  final int count;
  final double invoiced;
  final double paid;
  final double outstanding;
  final double overdue;
  final int overdueCount;

  const InvoiceOverviewTotals({
    this.count = 0,
    this.invoiced = 0,
    this.paid = 0,
    this.outstanding = 0,
    this.overdue = 0,
    this.overdueCount = 0,
  });
}

/// Fakturaöversikt: all of the association's invoices with payments. Reading is
/// gated on `invoice_payments` read; writing (register payment, mark as paid,
/// delete payment) on `invoice_payments` create/delete, and the server also
/// requires an administrator.
class InvoiceOverviewStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  InvoiceOverviewStore(this._pb, this._authStore);

  final from = ref<String>('');
  final to = ref<String>('');
  final status = ref<InvoiceStatusFilter>(InvoiceStatusFilter.alla);
  final search = ref<String>('');

  final _totals = ref<InvoiceOverviewTotals>(const InvoiceOverviewTotals());
  final _totalsLoading = ref<bool>(false);
  final _error = ref<String?>(null);

  Ref<InvoiceOverviewTotals> get totals => _totals;
  Ref<bool> get totalsLoading => _totalsLoading;

  /// Set when loading the list failed.
  Ref<String?> get error => _error;

  String _filter() {
    final parts = <String>['residence.association = {:association}'];
    final params = <String, dynamic>{
      'association': _authStore.association.value?.id ?? '',
      'today': todayIso(),
    };
    if (from.value.isNotEmpty) {
      parts.add('invoice_date >= {:from}');
      params['from'] = from.value;
    }
    if (to.value.isNotEmpty) {
      parts.add('invoice_date <= {:to}');
      params['to'] = to.value;
    }
    const notOverdue = '(invoice_due_date = "" || invoice_due_date >= {:today})';
    switch (status.value) {
      case InvoiceStatusFilter.alla:
        break;
      case InvoiceStatusFilter.utestaende:
        parts.add('payment_status != "betald"');
      case InvoiceStatusFilter.obetald:
        parts.add(
          'payment_status != "betald" && payment_status != "delbetald" && $notOverdue',
        );
      case InvoiceStatusFilter.delbetald:
        parts.add('payment_status = "delbetald" && $notOverdue');
      case InvoiceStatusFilter.forfallen:
        parts.add(
          'payment_status != "betald" && invoice_due_date != "" && invoice_due_date < {:today}',
        );
      case InvoiceStatusFilter.betald:
        parts.add('payment_status = "betald"');
    }
    final q = search.value.trim();
    if (q.isNotEmpty) {
      parts.add('(ocr ~ {:q} || residence.street_address ~ {:q})');
      params['q'] = q;
    }
    return _pb.filter(parts.join(' && '), params);
  }

  late final _invoices = Paginated<OverviewInvoice>((page, perPage) async {
    final res = await _pb
        .collection(Collections.invoices)
        .getList(
          page: page,
          perPage: perPage,
          filter: _filter(),
          sort: '-invoice_date,-created',
          expand: 'residence',
        );
    return PageResult(
      res.items.map((r) => OverviewInvoice.fromJson(r.toJson())).toList(),
      res.totalPages,
    );
  }, pageSize: 30);

  Ref<List<OverviewInvoice>> get invoices => _invoices.items;
  Ref<bool> get loading => _invoices.loading;
  Ref<bool> get loadingMore => _invoices.loadingMore;
  Ref<bool> get hasMore => _invoices.hasMore;

  Future<void> loadMore() => _invoices.loadMore();

  /// Reloads the list and the totals for the current filter.
  Future<void> refresh() async {
    _error.value = null;
    await Future.wait([_invoices.refresh(), _loadTotals()]);
  }

  /// The totals cover every invoice matching the filter, not just the loaded
  /// page, so they are summed from a light full list.
  Future<void> _loadTotals() async {
    _totalsLoading.value = true;
    try {
      final records = await _pb
          .collection(Collections.invoices)
          .getFullList(
            batch: 500,
            filter: _filter(),
            fields: 'id,amount,paid_amount,payment_status,invoice_due_date',
          );
      final today = todayIso();
      var invoiced = 0.0;
      var paid = 0.0;
      var outstanding = 0.0;
      var overdue = 0.0;
      var overdueCount = 0;
      for (final r in records) {
        final invoice = InvoicesRecord.fromJson(r.toJson());
        invoiced += invoice.amount;
        paid += invoice.paidAmount;
        final left = invoice.outstanding;
        if (left > 0) outstanding += left;
        final isOverdue =
            invoice.paymentStatus != 'betald' &&
            invoice.invoiceDueDate.isNotEmpty &&
            invoice.invoiceDueDate.compareTo(today) < 0;
        if (isOverdue) {
          overdue += left > 0 ? left : 0;
          overdueCount++;
        }
      }
      _totals.value = InvoiceOverviewTotals(
        count: records.length,
        invoiced: invoiced,
        paid: paid,
        outstanding: outstanding,
        overdue: overdue,
        overdueCount: overdueCount,
      );
    } catch (e) {
      debugPrint('InvoiceOverviewStore: Error loading totals: $e');
      _error.value = pbErrorMessage(e, 'Kunde inte hämta avierna.');
      _totals.value = const InvoiceOverviewTotals();
    } finally {
      _totalsLoading.value = false;
    }
  }

  /// Registered payments on one invoice, oldest first. Throws on failure.
  Future<List<InvoicePaymentsRecord>> payments(String invoiceId) async {
    final records = await _pb
        .collection(Collections.invoicePayments)
        .getFullList(
          filter: _pb.filter('invoice = {:invoice}', {'invoice': invoiceId}),
          sort: 'payment_date,created',
        );
    return records
        .map((r) => InvoicePaymentsRecord.fromJson(r.toJson()))
        .toList();
  }

  /// "Markera som betald": registers the whole outstanding amount. Returns null
  /// on success, otherwise an error message.
  Future<String?> markPaid(String invoiceId, {String? paymentDate}) async {
    try {
      await _pb.send(
        '/api/invoice-payments/mark-paid',
        method: 'POST',
        body: {
          'invoiceIds': [invoiceId],
          'paymentDate': paymentDate ?? todayIso(),
        },
      );
      return null;
    } catch (e) {
      debugPrint('InvoiceOverviewStore: Error marking paid: $e');
      return pbErrorMessage(e, 'Kunde inte markera avin som betald.');
    }
  }

  /// "Registrera betalning": a manual (full or partial) payment. The server sets
  /// source/created_by and recalculates the invoice's status.
  Future<String?> registerPayment({
    required String invoiceId,
    required double amount,
    required String paymentDate,
    String reference = '',
    String note = '',
  }) async {
    try {
      await _pb
          .collection(Collections.invoicePayments)
          .create(
            body: {
              'invoice': invoiceId,
              'amount': (amount * 100).roundToDouble() / 100,
              'payment_date': paymentDate,
              'reference': reference,
              'note': note,
            },
          );
      return null;
    } catch (e) {
      debugPrint('InvoiceOverviewStore: Error registering payment: $e');
      return pbErrorMessage(e, 'Betalningen kunde inte registreras.');
    }
  }

  Future<String?> deletePayment(String paymentId) async {
    try {
      await _pb.collection(Collections.invoicePayments).delete(paymentId);
      return null;
    } catch (e) {
      debugPrint('InvoiceOverviewStore: Error deleting payment: $e');
      return pbErrorMessage(e, 'Betalningen kunde inte tas bort.');
    }
  }
}
