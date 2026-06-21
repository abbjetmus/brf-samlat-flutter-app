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
  Ref<List<AssociationRoleTypesRecord>> get associationRoleTypes =>
      _associationRoleTypes;
  Ref<DashboardMenuPermissions> get menuPermissions => _menuPermissions;

  late final _isAuthenticated = computed(() => _currentUser.value != null);
  late final _isAdmin = computed(() {
    final adminRole = _userRoleTypes.value
        .where((r) => r.name == 'admin')
        .firstOrNull;
    return adminRole != null &&
        _currentUser.value?.userRoleType == adminRole.id;
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
      // Cold start with a persisted session: load association, role types and
      // menu permissions so the dashboard menu isn't gated to nothing.
      _loadUserData();
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
          .getFirstListItem(
            'invitation_token="$invitationToken"',
            expand: 'association',
          );

      final invitationData = UserInvitationsRecord.fromJson(
        invitation.toJson(),
      );

      // Create user account
      await _pb
          .collection(Collections.users)
          .create(
            body: {
              'email': email,
              'emailVisibility': true,
              'password': password,
              'passwordConfirm': password,
              'name': name,
              'user_role_type': invitationData.userRoleType,
              'association': invitationData.association,
              'association_role_types': invitationData.associationRoleTypes,
            },
          );

      // Update invitation status
      await _pb
          .collection(Collections.userInvitations)
          .update(invitationData.id, body: {'invitation_status': 'Aktiverad'});

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

  /// Whether [featureToken] is switched on for the current association. A token
  /// listed in the association's `disabled_features` is off for everyone.
  bool isFeatureEnabled(String featureToken) {
    final disabled = _association.value?.disabledFeatures ?? const [];
    return !disabled.contains(featureToken);
  }

  /// Persists the association's full `disabled_features` denylist, then updates
  /// the local association so menus react immediately.
  Future<bool> updateDisabledFeatures(List<String> disabledFeatures) async {
    final association = _association.value;
    if (association == null) return false;
    try {
      final record = await _pb
          .collection(Collections.associations)
          .update(
            association.id,
            body: {'disabled_features': disabledFeatures},
          );
      _association.value = AssociationsRecord.fromJson(record.toJson());
      return true;
    } catch (e) {
      debugPrint('AuthStore: Error updating disabled features: $e');
      return false;
    }
  }

  /// Persists a single role's allowed operations for [menuName] back to the
  /// association's `permissions` field, then refreshes the local matrix.
  Future<bool> updateRolePermission(
    String menuName,
    RolePermission updated,
  ) async {
    final association = _association.value;
    if (association == null) return false;

    final newMenus = _menuPermissions.value.map((menu) {
      if (menu.name != menuName) return menu;
      return DashboardMenuPermission(
        name: menu.name,
        permissions: menu.permissions
            .map(
              (p) =>
                  (p.roleTypeId == updated.roleTypeId &&
                      p.roleCategory == updated.roleCategory)
                  ? updated
                  : p,
            )
            .toList(),
      );
    }).toList();

    return _persistMenuPermissions(association.id, newMenus);
  }

  /// Assigns [newPermissions] to [menuName], replacing any existing entry for
  /// the same role + category (mirrors the web's replaceRolePermission). Use for
  /// adding roles — both user and association role types.
  Future<bool> addRolePermissions(
    String menuName,
    List<RolePermission> newPermissions,
  ) async {
    final association = _association.value;
    if (association == null || newPermissions.isEmpty) return false;

    final newMenus = _menuPermissions.value.map((menu) {
      if (menu.name != menuName) return menu;
      final retained = menu.permissions
          .where(
            (existing) => !newPermissions.any(
              (np) =>
                  np.roleTypeId == existing.roleTypeId &&
                  np.roleCategory == existing.roleCategory,
            ),
          )
          .toList();
      return DashboardMenuPermission(
        name: menu.name,
        permissions: [...retained, ...newPermissions],
      );
    }).toList();

    return _persistMenuPermissions(association.id, newMenus);
  }

  /// Removes a single role's entry for [menuName].
  Future<bool> removeRolePermission(
    String menuName,
    RolePermission permission,
  ) async {
    final association = _association.value;
    if (association == null) return false;

    final newMenus = _menuPermissions.value.map((menu) {
      if (menu.name != menuName) return menu;
      return DashboardMenuPermission(
        name: menu.name,
        permissions: menu.permissions
            .where(
              (p) =>
                  !(p.roleTypeId == permission.roleTypeId &&
                      p.roleCategory == permission.roleCategory),
            )
            .toList(),
      );
    }).toList();

    return _persistMenuPermissions(association.id, newMenus);
  }

  Future<bool> _persistMenuPermissions(
    String associationId,
    DashboardMenuPermissions newMenus,
  ) async {
    try {
      await _pb
          .collection(Collections.associations)
          .update(
            associationId,
            body: {'permissions': newMenus.map((m) => m.toJson()).toList()},
          );
      _menuPermissions.value = newMenus;
      return true;
    } catch (e) {
      debugPrint('AuthStore: Error saving role permissions: $e');
      return false;
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
        _residence.value = ResidencesRecord.fromJson(
          records.items.first.toJson(),
        );
      }
    } catch (e) {
      debugPrint('AuthStore: Error loading residence: $e');
    }
  }

  // Permission checking
  bool hasPermission(String menuName, CrudOperation operation) {
    final user = _currentUser.value;
    if (user == null) return false;

    // Admins have full access everywhere, matching the web admin layout which
    // shows every menu to admins unconditionally.
    if (_isAdmin.value) return true;

    final permissions = <({RoleCategory roleCategory, String roleTypeId})>[
      (roleCategory: RoleCategory.user, roleTypeId: user.userRoleType),
      ...user.associationRoleTypes.map(
        (roleId) =>
            (roleCategory: RoleCategory.association, roleTypeId: roleId),
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
      final record = await _pb
          .collection(Collections.users)
          .update(_currentUser.value!.id, body: {'name': name});
      // Persist the fresh record back into the auth store so the change
      // survives an app restart (the onChange listener updates _currentUser).
      _pb.authStore.save(_pb.authStore.token, record);
      return true;
    } catch (e) {
      debugPrint('AuthStore: Error updating name: $e');
      return false;
    }
  }

  Future<bool> updateUserEmail(String email) async {
    if (_currentUser.value == null) return false;
    try {
      final record = await _pb
          .collection(Collections.users)
          .update(_currentUser.value!.id, body: {'email': email});
      _pb.authStore.save(_pb.authStore.token, record);
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
      await _pb
          .collection(Collections.users)
          .update(
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
        await _pb
            .collection(Collections.users)
            .update(_currentUser.value!.id, body: {'avatar': ''});
      } else if (image is File) {
        final fileBytes = await image.readAsBytes();
        final multipartFile = http.MultipartFile.fromBytes(
          'avatar',
          fileBytes,
          filename: image.path.split('/').last,
        );
        await _pb
            .collection(Collections.users)
            .update(_currentUser.value!.id, body: {}, files: [multipartFile]);
      } else {
        return false;
      }

      final updated = await _pb
          .collection(Collections.users)
          .getOne(_currentUser.value!.id);
      _pb.authStore.save(_pb.authStore.token, updated);
      return true;
    } catch (e) {
      debugPrint('AuthStore: Error updating image: $e');
      return false;
    }
  }
}
