import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show ClientException, PocketBase;
import '../../core/models/pocketbase_models.dart';
import '../../core/pagination/paginated.dart';
import '../../core/utils/pb_error.dart';
import '../auth/auth_store.dart' as auth;

class UsersStore {
  final PocketBase _pb;
  final auth.AuthStore _authStore;

  UsersStore(this._pb, this._authStore) {
    _usersPage = Paginated<UsersRecord>((page, perPage) async {
      final assocId = _authStore.association.value?.id ?? '';
      if (assocId.isEmpty) return const PageResult([], 0);

      final res = await _pb
          .collection(Collections.users)
          .getList(
            page: page,
            perPage: perPage,
            filter: 'association="$assocId"',
            sort: 'name',
          );
      return PageResult(
        res.items.map((r) => UsersRecord.fromJson(r.toJson())).toList(),
        res.totalPages,
      );
    });
  }

  late final Paginated<UsersRecord> _usersPage;
  final _invitations = ref<List<UserInvitationsRecord>>([]);
  final _loading = ref<bool>(false);

  Ref<List<UsersRecord>> get users => _usersPage.items;
  Ref<List<UserInvitationsRecord>> get invitations => _invitations;
  Ref<bool> get loading => _loading;
  Ref<bool> get listLoading => _usersPage.loading;
  Ref<bool> get loadingMore => _usersPage.loadingMore;
  Ref<bool> get hasMore => _usersPage.hasMore;

  Future<void> getUsers() => _usersPage.refresh();
  Future<void> fetchNextUsers() => _usersPage.loadMore();

  /// Full (non-paginated) list of the association's users, for selection UIs
  /// such as assigning residents to a residence.
  Future<List<UsersRecord>> getAllAssociationUsers() async {
    try {
      final assocId = _authStore.association.value?.id ?? '';
      if (assocId.isEmpty) return [];

      final records = await _pb
          .collection(Collections.users)
          .getFullList(filter: 'association="$assocId"', sort: 'name');
      return records.map((r) => UsersRecord.fromJson(r.toJson())).toList();
    } catch (e) {
      debugPrint('UsersStore: Error fetching association users: $e');
      return [];
    }
  }

  Future<bool> getInvitations() async {
    _loading.value = true;
    try {
      final assocId = _authStore.association.value?.id ?? '';
      if (assocId.isEmpty) return false;

      final records = await _pb
          .collection(Collections.userInvitations)
          .getFullList(filter: 'association="$assocId"', sort: '-created');
      _invitations.value = records
          .map((r) => UserInvitationsRecord.fromJson(r.toJson()))
          .toList();
      return true;
    } catch (e) {
      debugPrint('UsersStore: Error fetching invitations: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }

  /// Removes a member through POST /api/users/anonymize, like
  /// [auth.AuthStore.deleteAccount] does for your own account. The users
  /// deleteRule is superuser-only: the server anonymises the record instead of
  /// deleting it, so the association's history keeps "Borttagen användare" as
  /// the author (see brf-samlat-pb/pb_hooks/api/account_deletion.pb.js).
  ///
  /// Returns null on success, otherwise the server's reason — it refuses, for
  /// instance, to remove the association's last administrator.
  Future<String?> deleteUser(String id) async {
    _loading.value = true;
    try {
      await _pb.send(
        '/api/users/anonymize',
        method: 'POST',
        body: {'userId': id},
      );
      await getUsers();
      return null;
    } on ClientException catch (e) {
      debugPrint('UsersStore: Error deleting user: $e');
      return (e.response['message'] as String?) ??
          'Användaren kunde inte tas bort';
    } catch (e) {
      debugPrint('UsersStore: Error deleting user: $e');
      return 'Användaren kunde inte tas bort';
    } finally {
      _loading.value = false;
    }
  }

  /// Returns null on success, otherwise the server's reason (e.g. that the
  /// user already exists).
  Future<String?> sendInvitation({
    required String name,
    required String email,
    String? phone,
    required String userRoleType,
  }) async {
    _loading.value = true;
    try {
      final assocId = _authStore.association.value?.id ?? '';
      final assocType = _authStore.association.value?.associationType ?? 'BRF';
      if (assocId.isEmpty) return 'Kunde inte skicka inbjudan.';

      await _pb.collection(Collections.userInvitations).create(body: {
        'name': name,
        'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'association': assocId,
        'association_type': assocType,
        'user_role_type': userRoleType,
        'invitation_status': 'Skickad',
      });
      await getInvitations();
      return null;
    } catch (e) {
      debugPrint('UsersStore: Error sending invitation: $e');
      return pbErrorMessage(e, 'Kunde inte skicka inbjudan.');
    } finally {
      _loading.value = false;
    }
  }

  /// Re-sends an existing invitation: the backend regenerates the token and
  /// emails a fresh register link. Only meaningful while the invitation is not
  /// yet "Aktiverad". Returns null on success, otherwise the server's reason.
  Future<String?> resendInvitation(String id) async {
    _loading.value = true;
    try {
      await _pb.send(
        '/api/user-invitations/resend',
        method: 'POST',
        body: {'id': id},
      );
      await getInvitations();
      return null;
    } catch (e) {
      debugPrint('UsersStore: Error resending invitation: $e');
      return pbErrorMessage(e, 'Kunde inte skicka inbjudan.');
    } finally {
      _loading.value = false;
    }
  }

  Future<bool> deleteInvitation(String id) async {
    _loading.value = true;
    try {
      await _pb.collection(Collections.userInvitations).delete(id);
      await getInvitations();
      return true;
    } catch (e) {
      debugPrint('UsersStore: Error deleting invitation: $e');
      return false;
    } finally {
      _loading.value = false;
    }
  }
}
