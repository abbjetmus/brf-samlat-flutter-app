import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../auth/auth_store.dart' as auth;

class FormsStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  FormsStore(this._pb, this._authStore);

  final _forms = ref<List<FormsRecord>>([]);
  final _userFormResponses = ref<List<FormResponsesRecord>>([]);
  final _currentForm = ref<FormsRecord?>(null);
  final _loading = ref<bool>(false);

  Ref<List<FormsRecord>> get forms => _forms;
  Ref<List<FormResponsesRecord>> get userFormResponses => _userFormResponses;
  Ref<FormsRecord?> get currentForm => _currentForm;
  Ref<bool> get loading => _loading;

  Future<bool> getForms() async {
    _loading.value = true;
    try {
      final assocId = _authStore.association.value?.id ?? '';
      if (assocId.isEmpty) return false;

      final records = await _pb.collection(Collections.forms).getFullList(
        filter: 'association="$assocId"',
        sort: '-created',
      );
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

  Future<bool> getUserFormResponses() async {
    _loading.value = true;
    try {
      final userId = _authStore.currentUser.value?.id ?? '';
      if (userId.isEmpty) return false;

      final records = await _pb.collection(Collections.formResponses).getFullList(
        filter: 'user="$userId"',
        expand: 'form',
        sort: '-created',
      );
      _userFormResponses.value = records
          .map((r) => FormResponsesRecord.fromJson(r.toJson()))
          .toList();
      return true;
    } catch (e) {
      debugPrint('FormsStore: Error fetching user form responses: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> updateFormResponse({
    required String id,
    required Map<String, dynamic> answers,
  }) async {
    _loading.value = true;
    try {
      await _pb.collection(Collections.formResponses).update(
        id,
        body: {'answers': answers},
      );
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
