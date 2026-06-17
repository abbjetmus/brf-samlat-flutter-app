enum CrudOperation {
  create('create', 'Skapa'),
  read('read', 'Läsa'),
  update('update', 'Uppdatera'),
  delete('delete', 'Radera');

  // `value` is the stored/internal English token; `displayName` is Swedish (UI).
  final String value;
  final String displayName;
  const CrudOperation(this.value, this.displayName);
}

enum RoleCategory {
  user('User', 'Användarroll'),
  association('Association', 'Föreningsroll');

  final String value;
  final String displayName;
  const RoleCategory(this.value, this.displayName);
}

class RolePermission {
  final String roleCategory;
  final String roleTypeId;
  final List<String> allowedOperations;

  RolePermission({
    required this.roleCategory,
    required this.roleTypeId,
    required this.allowedOperations,
  });

  factory RolePermission.fromJson(Map<String, dynamic> json) {
    return RolePermission(
      roleCategory: json['roleCategory'] as String? ?? '',
      roleTypeId: json['roleTypeId'] as String? ?? '',
      allowedOperations: (json['allowedOperations'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

class DashboardMenuPermission {
  final String name;
  final List<RolePermission> permissions;

  DashboardMenuPermission({
    required this.name,
    required this.permissions,
  });

  factory DashboardMenuPermission.fromJson(Map<String, dynamic> json) {
    return DashboardMenuPermission(
      name: json['name'] as String? ?? '',
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => RolePermission.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

typedef DashboardMenuPermissions = List<DashboardMenuPermission>;

DashboardMenuPermissions parseMenuPermissions(dynamic json) {
  if (json == null) return [];
  if (json is List) {
    return json
        .map((e) => DashboardMenuPermission.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  return [];
}

bool isOperationAllowed(
  DashboardMenuPermissions menuPermissions,
  String menuName,
  String roleTypeId,
  RoleCategory roleCategory,
  CrudOperation operation,
) {
  final menuPermission = menuPermissions
      .where((menu) => menu.name == menuName)
      .firstOrNull;
  if (menuPermission == null) return false;

  final rolePermission = menuPermission.permissions
      .where(
        (p) =>
            p.roleTypeId == roleTypeId &&
            p.roleCategory == roleCategory.value,
      )
      .firstOrNull;
  if (rolePermission == null) return false;

  return rolePermission.allowedOperations.contains(operation.value);
}

bool isOperationAllowedForPermissions(
  DashboardMenuPermissions menuPermissions,
  String menuName,
  List<({RoleCategory roleCategory, String roleTypeId})> rolePermissions,
  CrudOperation operation,
) {
  return rolePermissions.any(
    (rp) => isOperationAllowed(
      menuPermissions,
      menuName,
      rp.roleTypeId,
      rp.roleCategory,
      operation,
    ),
  );
}
