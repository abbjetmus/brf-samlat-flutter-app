import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../auth/auth_store.dart' as auth;

class ResidencesStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  ResidencesStore(this._pb, this._authStore);

  final _residencesList = ref<List<ResidencesRecord>>([]);
  final _currentResidence = ref<ResidencesRecord?>(null);
  final _residenceIssues = ref<List<IssuesRecord>>([]);
  final _loading = ref<bool>(false);

  Ref<List<ResidencesRecord>> get residencesList => _residencesList;
  Ref<ResidencesRecord?> get currentResidence => _currentResidence;
  Ref<List<IssuesRecord>> get residenceIssues => _residenceIssues;
  Ref<bool> get loading => _loading;

  Future<bool> getAllResidences() async {
    _loading.value = true;
    try {
      final assocId = _authStore.association.value?.id ?? '';
      if (assocId.isEmpty) return false;

      final records = await _pb.collection(Collections.residences).getFullList(
        filter: 'association="$assocId"',
      );
      _residencesList.value = records
          .map((r) => ResidencesRecord.fromJson(r.toJson()))
          .toList();
      return true;
    } catch (e) {
      debugPrint('ResidencesStore: Error fetching residences: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> getResidence(String id) async {
    _loading.value = true;
    try {
      final record = await _pb.collection(Collections.residences).getOne(id);
      _currentResidence.value = ResidencesRecord.fromJson(record.toJson());
      return true;
    } catch (e) {
      debugPrint('ResidencesStore: Error fetching residence: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> getResidenceIssues(String id) async {
    try {
      final records = await _pb.collection(Collections.issues).getFullList(
        filter: 'residence="$id"',
      );
      _residenceIssues.value = records
          .map((r) => IssuesRecord.fromJson(r.toJson()))
          .toList();
      return true;
    } catch (e) {
      debugPrint('ResidencesStore: Error fetching residence issues: $e');
      return false;
    }
  }

  Future<bool> createResidence({
    required String streetAddress,
    required String zipCode,
    required String locality,
    required String residenceType,
    String? moveInDate,
  }) async {
    _loading.value = true;
    try {
      final assocId = _authStore.association.value?.id ?? '';

      await _pb.collection(Collections.residences).create(body: {
        'association': assocId,
        'street_address': streetAddress,
        'zip_code': zipCode,
        'locality': locality,
        'residence_type': residenceType,
        'move_in_date': moveInDate ?? '',
      });

      await getAllResidences();
      return true;
    } catch (e) {
      debugPrint('ResidencesStore: Error creating residence: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> updateResidence({
    required String id,
    required String streetAddress,
    required String zipCode,
    required String locality,
    required String residenceType,
    String? moveInDate,
    List<String>? users,
  }) async {
    _loading.value = true;
    try {
      await _pb.collection(Collections.residences).update(id, body: {
        'street_address': streetAddress,
        'zip_code': zipCode,
        'locality': locality,
        'residence_type': residenceType,
        'move_in_date': moveInDate ?? '',
        if (users != null) 'users': users,
      });

      await getResidence(id);
      return true;
    } catch (e) {
      debugPrint('ResidencesStore: Error updating residence: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> deleteResidence(String id) async {
    _loading.value = true;
    try {
      await _pb.collection(Collections.residences).delete(id);
      await getAllResidences();
      return true;
    } catch (e) {
      debugPrint('ResidencesStore: Error deleting residence: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }
}
