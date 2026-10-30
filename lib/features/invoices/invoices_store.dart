import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../../core/pagination/paginated.dart';
import '../auth/auth_store.dart' as auth;

class InvoicesStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  InvoicesStore(this._pb, this._authStore) {
    _invoices = Paginated<InvoicesRecord>((page, perPage) async {
      final residenceId = _authStore.residence.value?.id;

      String? filter;
      if (residenceId != null && residenceId.isNotEmpty) {
        filter = 'residence="$residenceId"';
      }

      final records = await _pb
          .collection(Collections.invoices)
          .getList(
            page: page,
            perPage: perPage,
            filter: filter ?? '',
            sort: '-invoice_date',
          );
      return PageResult(
        records.items.map((r) => InvoicesRecord.fromJson(r.toJson())).toList(),
        records.totalPages,
      );
    });
  }

  late final Paginated<InvoicesRecord> _invoices;
  final _currentInvoice = ref<InvoicesRecord?>(null);
  final _invoiceTemplate = ref<InvoiceTemplatesRecord?>(null);
  final _currentResidence = ref<ResidencesRecord?>(null);
  final _payments = ref<List<InvoicePaymentsRecord>>([]);
  final _loading = ref<bool>(false);

  Ref<List<InvoicesRecord>> get invoices => _invoices.items;
  Ref<InvoicesRecord?> get currentInvoice => _currentInvoice;
  Ref<InvoiceTemplatesRecord?> get invoiceTemplate => _invoiceTemplate;
  Ref<ResidencesRecord?> get currentResidence => _currentResidence;

  /// Registrerade betalningar på [currentInvoice], äldst först.
  Ref<List<InvoicePaymentsRecord>> get payments => _payments;
  Ref<bool> get loading => _loading;
  Ref<bool> get listLoading => _invoices.loading;
  Ref<bool> get loadingMore => _invoices.loadingMore;
  Ref<bool> get hasMore => _invoices.hasMore;

  Future<void> getAllInvoices() => _invoices.refresh();
  Future<void> fetchNextInvoices() => _invoices.loadMore();

  /// Loads the invoice. Its template and residence are only fetched for
  /// invoices without a template snapshot (see InvoiceDisplay): an invoice
  /// with a snapshot shows what it was created with, not the current template.
  Future<bool> getInvoice(String id) async {
    _loading.value = true;
    _currentResidence.value = null;
    _invoiceTemplate.value = null;
    _payments.value = [];
    try {
      final record = await _pb.collection(Collections.invoices).getOne(id);
      final invoice = InvoicesRecord.fromJson(record.toJson());
      _currentInvoice.value = invoice;
      final snapshot = invoice.templateSnapshot;

      if (snapshot == null && invoice.invoiceTemplate.isNotEmpty) {
        try {
          final template = await _pb
              .collection(Collections.invoiceTemplates)
              .getOne(invoice.invoiceTemplate);
          _invoiceTemplate.value = InvoiceTemplatesRecord.fromJson(
            template.toJson(),
          );
        } catch (e) {
          debugPrint('InvoicesStore: Error fetching invoice template: $e');
        }
      }

      // Betalningarna är bara information; ett fel här ska inte dölja avin.
      try {
        final payments = await _pb
            .collection(Collections.invoicePayments)
            .getFullList(
              filter: _pb.filter('invoice = {:invoice}', {'invoice': id}),
              sort: 'payment_date,created',
            );
        _payments.value = payments
            .map((r) => InvoicePaymentsRecord.fromJson(r.toJson()))
            .toList();
      } catch (e) {
        debugPrint('InvoicesStore: Error fetching invoice payments: $e');
      }

      if ((snapshot == null || !snapshot.hasResidence) &&
          invoice.residence.isNotEmpty) {
        final res = await _pb
            .collection(Collections.residences)
            .getOne(invoice.residence);
        _currentResidence.value = ResidencesRecord.fromJson(res.toJson());
      }
      return true;
    } catch (e) {
      debugPrint('InvoicesStore: Error fetching invoice: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> deleteInvoice(String id) async {
    _loading.value = true;
    try {
      await _pb.collection(Collections.invoices).delete(id);
      await getAllInvoices();
      return true;
    } catch (e) {
      debugPrint('InvoicesStore: Error deleting invoice: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }
}
