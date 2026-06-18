import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../../core/pagination/paginated.dart';
import '../auth/auth_store.dart' as auth;

class FormsStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  FormsStore(this._pb, this._authStore) {
    _userFormResponses = Paginated<FormResponsesRecord>((page, perPage) async {
      final userId = _authStore.currentUser.value?.id ?? '';
      if (userId.isEmpty) return const PageResult([], 0);
      final res = await _pb
          .collection(Collections.formResponses)
          .getList(
            page: page,
            perPage: perPage,
            filter: 'user="$userId"',
            expand: 'form',
            sort: '-created',
          );
      return PageResult(
        res.items.map((r) => FormResponsesRecord.fromJson(r.toJson())).toList(),
        res.totalPages,
      );
    });
  }

  final _forms = ref<List<FormsRecord>>([]);
  late final Paginated<FormResponsesRecord> _userFormResponses;
  final _currentForm = ref<FormsRecord?>(null);
  final _loading = ref<bool>(false);

  Ref<List<FormsRecord>> get forms => _forms;
  Ref<List<FormResponsesRecord>> get userFormResponses =>
      _userFormResponses.items;
  Ref<FormsRecord?> get currentForm => _currentForm;
  Ref<bool> get loading => _loading;
  Ref<bool> get listLoading => _userFormResponses.loading;
  Ref<bool> get loadingMore => _userFormResponses.loadingMore;
  Ref<bool> get hasMore => _userFormResponses.hasMore;

  Future<bool> getForms() async {
    _loading.value = true;
    try {
      final assocId = _authStore.association.value?.id ?? '';
      if (assocId.isEmpty) return false;

      final records = await _pb
          .collection(Collections.forms)
          .getFullList(filter: 'association="$assocId"', sort: '-created');
      _forms.value = records
          .map((r) => FormsRecord.fromJson(r.toJson()))
          .toList();
      return true;
    } catch (e) {
      debugPrint('FormsStore: Error fetching forms: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> getForm(String id) async {
    _loading.value = true;
    try {
      final record = await _pb.collection(Collections.forms).getOne(id);
      _currentForm.value = FormsRecord.fromJson(record.toJson());
      return true;
    } catch (e) {
      debugPrint('FormsStore: Error fetching form: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<void> getUserFormResponses() => _userFormResponses.refresh();

  Future<void> fetchNextForms() => _userFormResponses.loadMore();

  Future<bool> updateFormResponse({
    required String id,
    required Map<String, dynamic> answers,
  }) async {
    _loading.value = true;
    try {
      await _pb
          .collection(Collections.formResponses)
          .update(id, body: {'answers': answers});
      await getUserFormResponses();
      return true;
    } catch (e) {
      debugPrint('FormsStore: Error updating form response: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> deleteForm(String id) async {
    _loading.value = true;
    try {
      await _pb.collection(Collections.forms).delete(id);
      await getForms();
      return true;
    } catch (e) {
      debugPrint('FormsStore: Error deleting form: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }
}
