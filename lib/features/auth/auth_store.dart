import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:pocketbase/pocketbase.dart' show PocketBase, ClientException;
import 'package:http/http.dart' as http;
import '../../core/models/pocketbase_models.dart';
import '../../core/utils/permissions_utils.dart';

class AuthStore {
  final PocketBase _pb;

  AuthStore(this._pb) {
    _initialize();
  }

  final _token = ref<String?>(null);
  final _currentUser = ref<UsersRecord?>(null);
  final _association = ref<AssociationsRecord?>(null);
  final _residence = ref<ResidencesRecord?>(null);
  final _userRoleTypes = ref<List<UserRoleTypesRecord>>([]);
  final _associationRoleTypes = ref<List<AssociationRoleTypesRecord>>([]);
  final _menuPermissions = ref<DashboardMenuPermissions>([]);

  Ref<String?> get token => _token;
  Ref<UsersRecord?> get currentUser => _currentUser;
  Ref<AssociationsRecord?> get association => _association;
  Ref<ResidencesRecord?> get residence => _residence;
  Ref<List<UserRoleTypesRecord>> get userRoleTypes => _userRoleTypes;
  Ref<List<AssociationRoleTypesRecord>> get associationRoleTypes => _associationRoleTypes;
  Ref<DashboardMenuPermissions> get menuPermissions => _menuPermissions;

  late final _isAuthenticated = computed(() => _currentUser.value != null);
  late final _isAdmin = computed(() {
    final adminRole = _userRoleTypes.value
        .where((r) => r.name == 'admin')
        .firstOrNull;
    return adminRole != null && _currentUser.value?.userRoleType == adminRole.id;
  });
  late final _isBoardMember = computed(
    () => (_currentUser.value?.associationRoleTypes ?? []).isNotEmpty,
  );

  ReadonlyRef<bool> get isAuthenticated => _isAuthenticated;
  ReadonlyRef<bool> get isAdmin => _isAdmin;
  ReadonlyRef<bool> get isBoardMember => _isBoardMember;

  void _initialize() {
    _pb.authStore.onChange.listen((event) {
      if (_pb.authStore.isValid) {
        final record = _pb.authStore.record;
        if (record != null) {
          _token.value = _pb.authStore.token;
          _currentUser.value = UsersRecord.fromJson(record.toJson());
        }
      } else {
        _token.value = null;
        _currentUser.value = null;
        _association.value = null;
        _residence.value = null;
      }
    });

    if (_pb.authStore.isValid && _pb.authStore.record != null) {
      _token.value = _pb.authStore.token;
      _currentUser.value = UsersRecord.fromJson(_pb.authStore.record!.toJson());
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      await _pb.collection(Collections.users).authWithPassword(email, password);
      final record = _pb.authStore.record;
      if (record != null) {
        _token.value = _pb.authStore.token;
        _currentUser.value = UsersRecord.fromJson(record.toJson());
        await _loadUserData();
      }
      return true;
    } on ClientException catch (e) {
      final response = e.response;
      if (response['message'] != null) {
        throw Exception(response['message'] as String);
      }
      throw Exception('Inloggning misslyckades: ${e.toString()}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Inloggning misslyckades: ${e.toString()}');
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String invitationToken,
  }) async {
    try {
      // Get invitation details
      final invitation = await _pb
          .collection(Collections.userInvitations)
          .getFirstListItem('invitation_token="$invitationToken"', expand: 'association');

      final invitationData = UserInvitationsRecord.fromJson(invitation.toJson());

      // Create user account
      await _pb.collection(Collections.users).create(body: {
        'email': email,
        'emailVisibility': true,
        'password': password,
        'passwordConfirm': password,
        'name': name,
        'user_role_type': invitationData.userRoleType,
        'association': invitationData.association,
        'association_role_types': invitationData.associationRoleTypes,
      });

      // Update invitation status
      await _pb.collection(Collections.userInvitations).update(
        invitationData.id,
        body: {'invitation_status': 'Aktiverad'},
      );

      return true;
    } catch (e) {
      debugPrint('AuthStore: Error in signUp: $e');
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    try {
      await _pb.collection(Collections.users).requestPasswordReset(email);
      return true;
    } catch (e) {
      debugPrint('AuthStore: Error in forgotPassword: $e');
      return false;
    }
  }

  void signOut() {
    _pb.authStore.clear();
    _token.value = null;
    _currentUser.value = null;
    _association.value = null;
    _residence.value = null;
    _menuPermissions.value = [];
  }

  Future<void> _loadUserData() async {
    await Future.wait([
      loadAssociation(),
      loadUserRoleTypes(),
      loadAssociationRoleTypes(),
      _loadResidence(),
    ]);
  }

  Future<void> loadAssociation() async {
    final user = _currentUser.value;
    if (user == null || user.association.isEmpty) return;

    try {
      final record = await _pb
          .collection(Collections.associations)
          .getOne(user.association);
      _association.value = AssociationsRecord.fromJson(record.toJson());
      _menuPermissions.value = parseMenuPermissions(
        record.toJson()['permissions'],
      );
    } catch (e) {
      debugPrint('AuthStore: Error loading association: $e');
    }
  }

  Future<void> loadUserRoleTypes() async {
    try {
      final records = await _pb
          .collection(Collections.userRoleTypes)
          .getFullList();
      _userRoleTypes.value = records
          .map((r) => UserRoleTypesRecord.fromJson(r.toJson()))
          .toList();
    } catch (e) {
      debugPrint('AuthStore: Error loading user role types: $e');
    }
  }

  Future<void> loadAssociationRoleTypes() async {
    try {
      final records = await _pb
          .collection(Collections.associationRoleTypes)
          .getFullList();
      _associationRoleTypes.value = records
          .map((r) => AssociationRoleTypesRecord.fromJson(r.toJson()))
          .toList();
    } catch (e) {
      debugPrint('AuthStore: Error loading association role types: $e');
    }
  }

  Future<void> _loadResidence() async {
    final user = _currentUser.value;
    if (user == null || user.association.isEmpty) return;

    try {
      final records = await _pb
          .collection(Collections.residences)
          .getList(
            page: 1,
            perPage: 1,
            filter: 'association="${user.association}" && users~"${user.id}"',
          );
      if (records.items.isNotEmpty) {
        _residence.value = ResidencesRecord.fromJson(records.items.first.toJson());
      }
    } catch (e) {
      debugPrint('AuthStore: Error loading residence: $e');
    }
  }

  // Permission checking
  bool hasPermission(String menuName, CrudOperation operation) {
    final user = _currentUser.value;
    if (user == null) return false;

    final permissions = <({RoleCategory roleCategory, String roleTypeId})>[
      (roleCategory: RoleCategory.user, roleTypeId: user.userRoleType),
      ...user.associationRoleTypes.map(
        (roleId) => (roleCategory: RoleCategory.association, roleTypeId: roleId),
      ),
    ];

    return isOperationAllowedForPermissions(
      _menuPermissions.value,
      menuName,
      permissions,
      operation,
    );
  }

  // User profile management
  Future<bool> updateUserName(String name) async {
    if (_currentUser.value == null) return false;
    try {
      await _pb.collection(Collections.users).update(
        _currentUser.value!.id,
        body: {'name': name},
      );
      _currentUser.value = _currentUser.value!.copyWith(name: name);
      return true;
    } catch (e) {
      debugPrint('AuthStore: Error updating name: $e');
      return false;
    }
  }

  Future<bool> updateUserEmail(String email) async {
    if (_currentUser.value == null) return false;
    try {
      await _pb.collection(Collections.users).update(
        _currentUser.value!.id,
        body: {'email': email},
      );
      _currentUser.value = _currentUser.value!.copyWith(email: email);
      return true;
    } catch (e) {
      debugPrint('AuthStore: Error updating email: $e');
      return false;
    }
  }

  Future<bool> updateUserPassword({
    required String oldPassword,
    required String password,
    required String passwordConfirm,
  }) async {
    if (_currentUser.value == null) return false;
    try {
      await _pb.collection(Collections.users).update(
        _currentUser.value!.id,
        body: {
          'oldPassword': oldPassword,
          'password': password,
          'passwordConfirm': passwordConfirm,
        },
      );
      return true;
    } catch (e) {
      debugPrint('AuthStore: Error updating password: $e');
      return false;
    }
  }

  Future<bool> updateUserImage(dynamic image) async {
    if (_currentUser.value == null) return false;
    try {
      if (image is List && image.isEmpty) {
        await _pb.collection(Collections.users).update(
          _currentUser.value!.id,
          body: {'avatar': ''},
        );
      } else if (image is File) {
        final fileBytes = await image.readAsBytes();
        final multipartFile = http.MultipartFile.fromBytes(
          'avatar',
          fileBytes,
          filename: image.path.split('/').last,
        );
        await _pb.collection(Collections.users).update(
          _currentUser.value!.id,
          body: {},
          files: [multipartFile],
        );
      } else {
        return false;
      }

      final updated = await _pb
          .collection(Collections.users)
          .getOne(_currentUser.value!.id);
      _currentUser.value = _currentUser.value!.copyWith(
        avatar: updated.data['avatar'] as String?,
      );
      return true;
    } catch (e) {
      debugPrint('AuthStore: Error updating image: $e');
      return false;
    }
  }
}
