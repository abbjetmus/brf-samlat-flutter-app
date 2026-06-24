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
  final _loading = ref<bool>(false);

  Ref<List<InvoicesRecord>> get invoices => _invoices.items;
  Ref<InvoicesRecord?> get currentInvoice => _currentInvoice;
  Ref<InvoiceTemplatesRecord?> get invoiceTemplate => _invoiceTemplate;
  Ref<ResidencesRecord?> get currentResidence => _currentResidence;
  Ref<bool> get loading => _loading;
  Ref<bool> get listLoading => _invoices.loading;
  Ref<bool> get loadingMore => _invoices.loadingMore;
  Ref<bool> get hasMore => _invoices.hasMore;

  Future<void> getAllInvoices() => _invoices.refresh();
  Future<void> fetchNextInvoices() => _invoices.loadMore();

  Future<bool> getInvoice(String id) async {
    _loading.value = true;
    _currentResidence.value = null;
    try {
      final record = await _pb.collection(Collections.invoices).getOne(id);
      _currentInvoice.value = InvoicesRecord.fromJson(record.toJson());
      final residenceId = _currentInvoice.value?.residence ?? '';
      if (residenceId.isNotEmpty) {
        final res = await _pb
            .collection(Collections.residences)
            .getOne(residenceId);
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

  Future<bool> getInvoiceTemplate() async {
    try {
      final assocId = _authStore.association.value?.id ?? '';
      if (assocId.isEmpty) return false;

      final records = await _pb
          .collection(Collections.invoiceTemplates)
          .getFullList(filter: 'association="$assocId"');
      if (records.isNotEmpty) {
        _invoiceTemplate.value = InvoiceTemplatesRecord.fromJson(
          records.first.toJson(),
        );
      }
      return true;
    } catch (e) {
      debugPrint('InvoicesStore: Error fetching invoice template: $e');
      return false;
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
