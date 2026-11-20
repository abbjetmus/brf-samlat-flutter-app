import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/models/pocketbase_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_features.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/gradient_scaffold.dart';
import '../../../shared/widgets/help_tip.dart';
import '../../../shared/widgets/search_field.dart';

/// Swedish labels for the permission/menu tokens stored on the association.
///
/// `users` and `user_role_types` are deliberately absent: they never appear in
/// the matrix, because PocketBase's `associations` updateRule requires the admin
/// user role. User and permission management therefore cannot be delegated to
/// another role, and a card for them would promise something that cannot be
/// saved.
const _menuLabels = <String, String>{
  'posts': 'Inlägg',
  'chat': 'Meddelanden',
  'issues': 'Felanmälan & ärenden',
  'residence_issues': 'Felanmälan & ärenden (bostäder)',
  'calendar_events': 'Kalender',
  'places': 'Lokaler',
  'place_bookings': 'Lokalbokningar',
  'gadgets': 'Prylar',
  'gadget_bookings': 'Prylbokningar',
  'residences': 'Bostäder',
  'parking_lots': 'Parkeringar',
  'folders_and_files': 'Dokument',
  'board': 'Styrelsen',
  'board_meetings': 'Styrelsemöten',
  'annual_wheel': 'Årshjul',
  'maintenance_plan': 'Underhållsplan',
  'residence_applications': 'Ansökningar (andrahand, överlåtelse m.m.)',
  'invoices': 'Fakturor',
  'invoice_builder': 'Fakturabyggaren',
  'forms': 'Enkäter',
  'form_builder': 'Formulärbyggaren',
};

/// Användarrollen "user" har alla i föreningen.
const _allMembersLabel = 'Alla medlemmar';

class PermissionsPage extends CompositionWidget {
  static const String path = '/permissions';

  const PermissionsPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);
    final searchQuery = ref('');
    final savingFeatures = ref(false);

    onMounted(() {
      // Ensure the matrix and role names are available even on a cold start
      // with a persisted session.
      if (authStore.menuPermissions.value.isEmpty) {
        authStore.loadAssociation();
      }
      if (authStore.userRoleTypes.value.isEmpty) {
        authStore.loadUserRoleTypes();
      }
      if (authStore.associationRoleTypes.value.isEmpty) {
        authStore.loadAssociationRoleTypes();
      }
    });

    // Rättigheterna sparas per roll och kategori (användarroll eller
    // föreningsroll), men här visas bara "roller": Alla medlemmar
    // (användarrollen "user"), styrelsens roller och övriga roller.
    String userRoleLabel(UserRoleTypesRecord role) {
      if (role.name == 'user') return _allMembersLabel;
      return role.displayName.isNotEmpty ? role.displayName : role.name;
    }

    String assocRoleLabel(AssociationRoleTypesRecord role) =>
        role.displayName.isNotEmpty ? role.displayName : role.name;

    String roleName(RolePermission p) {
      if (p.roleCategory == RoleCategory.user.value) {
        final match = authStore.userRoleTypes.value
            .where((r) => r.id == p.roleTypeId)
            .firstOrNull;
        return match == null ? 'Okänd roll' : userRoleLabel(match);
      }
      final match = authStore.associationRoleTypes.value
          .where((r) => r.id == p.roleTypeId)
          .firstOrNull;
      return match == null ? 'Okänd roll' : assocRoleLabel(match);
    }

    // Ordning i listan: admin, alla medlemmar, styrelsen, övriga roller.
    // associationRoleTypes är redan sorterad (AuthStore._sortRoleTypes).
    int roleRank(RolePermission p) {
      if (p.roleCategory == RoleCategory.user.value) {
        final match = authStore.userRoleTypes.value
            .where((r) => r.id == p.roleTypeId)
            .firstOrNull;
        return match?.name == 'admin' ? 0 : 1;
      }
      final roles = authStore.associationRoleTypes.value;
      final index = roles.indexWhere((r) => r.id == p.roleTypeId);
      if (index == -1) return 5000;
      return (roles[index].isBoardRole ? 10 : 1000) + index;
    }

    List<RolePermission> sortedPermissions(DashboardMenuPermission menu) =>
        [...menu.permissions]
          ..sort((a, b) => roleRank(a).compareTo(roleRank(b)));

    // The admin user role always has full access (see AuthStore.hasPermission,
    // which short-circuits to true for admins). Its matrix entries are therefore
    // not editable — we show "Full åtkomst" instead of toggleable operations.
    bool isAdminRole(RolePermission p) {
      if (p.roleCategory != RoleCategory.user.value) return false;
      final match = authStore.userRoleTypes.value
          .where((r) => r.id == p.roleTypeId)
          .firstOrNull;
      return match?.name == 'admin';
    }

    return (context) {
      final theme = Theme.of(context);
      final menus = authStore.menuPermissions.value;
      final canEdit = authStore.hasPermission(
        'user_role_types',
        CrudOperation.update,
      );

      void showResult(bool ok, String okMsg, String errMsg) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? okMsg : errMsg),
            backgroundColor: ok
                ? AppTheme.primaryColor
                : theme.colorScheme.error,
          ),
        );
      }

      Future<void> editPermission(
        DashboardMenuPermission menu,
        RolePermission p,
      ) async {
        final menuLabel = _menuLabels[menu.name] ?? menu.name;
        final selected = {...p.allowedOperations};
        await showAppBottomSheet<void>(
          context: context,
          builder: (sheetContext) {
            bool saving = false;
            return StatefulBuilder(
              builder: (sheetContext, setSheetState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roleName(p),
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      menuLabel,
                      style: Theme.of(sheetContext).textTheme.bodySmall
                          ?.copyWith(color: Theme.of(sheetContext).hintColor),
                    ),
                    const SizedBox(height: 8),
                    for (final op in CrudOperation.values)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(op.displayName),
                        value: selected.contains(op.value),
                        onChanged: saving
                            ? null
                            : (v) => setSheetState(() {
                                if (v) {
                                  selected.add(op.value);
                                } else {
                                  selected.remove(op.value);
                                }
                              }),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                setSheetState(() => saving = true);
                                final ok = await authStore.updateRolePermission(
                                  menu.name,
                                  RolePermission(
                                    roleCategory: p.roleCategory,
                                    roleTypeId: p.roleTypeId,
                                    allowedOperations: selected.toList(),
                                  ),
                                );
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                                showResult(
                                  ok,
                                  'Rättigheter uppdaterade',
                                  'Kunde inte uppdatera rättigheter',
                                );
                              },
                        child: saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Spara'),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final confirmed = await showConfirmDialog(
                                  sheetContext,
                                  title: 'Ta bort rättighet',
                                  message:
                                      'Ta bort ${roleName(p)} från $menuLabel?',
                                  okLabel: 'Ta bort',
                                  okColor: Theme.of(
                                    sheetContext,
                                  ).colorScheme.error,
                                );
                                if (!confirmed) return;
                                setSheetState(() => saving = true);
                                final ok = await authStore.removeRolePermission(
                                  menu.name,
                                  p,
                                );
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                                showResult(
                                  ok,
                                  'Rättigheten borttagen',
                                  'Kunde inte ta bort rättigheten',
                                );
                              },
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Theme.of(sheetContext).colorScheme.error,
                        ),
                        label: Text(
                          'Ta bort roll',
                          style: TextStyle(
                            color: Theme.of(sheetContext).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      }

      Future<void> addPermission(DashboardMenuPermission menu) async {
        final menuLabel = _menuLabels[menu.name] ?? menu.name;
        final assignedUserIds = menu.permissions
            .where((p) => p.roleCategory == RoleCategory.user.value)
            .map((p) => p.roleTypeId)
            .toSet();
        final assignedAssocIds = menu.permissions
            .where((p) => p.roleCategory == RoleCategory.association.value)
            .map((p) => p.roleTypeId)
            .toSet();
        // Admin is excluded — it always has full access and isn't editable.
        final userRoles = authStore.userRoleTypes.value
            .where((r) => r.name != 'admin' && !assignedUserIds.contains(r.id))
            .toList();
        final assocRoles = authStore.associationRoleTypes.value
            .where((r) => !assignedAssocIds.contains(r.id))
            .toList();
        final boardRoles = assocRoles.where((r) => r.isBoardRole).toList();
        final otherRoles = assocRoles.where((r) => !r.isBoardRole).toList();
        final memberIds = userRoles
            .where((r) => r.name == 'user')
            .map((r) => r.id)
            .toSet();
        final boardIds = boardRoles.map((r) => r.id).toSet();

        if (userRoles.isEmpty && assocRoles.isEmpty) {
          showResult(
            true,
            'Alla roller har redan rättigheter för $menuLabel.',
            '',
          );
          return;
        }

        final selectedUserIds = <String>{};
        final selectedAssocIds = <String>{};
        final selectedOps = <String>{};

        // Snabbval: är alla redan valda tas de bort, annars läggs de till.
        bool allIn(Set<String> selected, Set<String> ids) =>
            ids.isNotEmpty && selected.containsAll(ids);
        void toggleAll(Set<String> selected, Set<String> ids) {
          if (allIn(selected, ids)) {
            selected.removeAll(ids);
          } else {
            selected.addAll(ids);
          }
        }

        await showAppBottomSheet<void>(
          context: context,
          builder: (sheetContext) {
            bool saving = false;
            bool error = false;
            final labelStyle = Theme.of(
              sheetContext,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold);
            Widget roleTile({
              required String label,
              required bool selected,
              required ValueChanged<bool>? onChanged,
            }) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(label),
              value: selected,
              onChanged: onChanged == null ? null : (v) => onChanged(v == true),
            );
            return StatefulBuilder(
              builder: (sheetContext, setSheetState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lägg till rättighet',
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      menuLabel,
                      style: Theme.of(sheetContext).textTheme.bodySmall
                          ?.copyWith(color: Theme.of(sheetContext).hintColor),
                    ),
                    const SizedBox(height: 8),
                    if (memberIds.isNotEmpty || boardIds.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (memberIds.isNotEmpty)
                            FilterChip(
                              label: const Text(_allMembersLabel),
                              selected: allIn(selectedUserIds, memberIds),
                              onSelected: saving
                                  ? null
                                  : (_) => setSheetState(() {
                                      error = false;
                                      toggleAll(selectedUserIds, memberIds);
                                    }),
                            ),
                          if (boardIds.isNotEmpty)
                            FilterChip(
                              label: const Text('Hela styrelsen'),
                              selected: allIn(selectedAssocIds, boardIds),
                              onSelected: saving
                                  ? null
                                  : (_) => setSheetState(() {
                                      error = false;
                                      toggleAll(selectedAssocIds, boardIds);
                                    }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    for (final r in userRoles)
                      roleTile(
                        label: userRoleLabel(r),
                        selected: selectedUserIds.contains(r.id),
                        onChanged: saving
                            ? null
                            : (v) => setSheetState(() {
                                error = false;
                                if (v) {
                                  selectedUserIds.add(r.id);
                                } else {
                                  selectedUserIds.remove(r.id);
                                }
                              }),
                      ),
                    for (final group in [
                      ('Styrelse', boardRoles),
                      ('Övriga roller', otherRoles),
                    ])
                      if (group.$2.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(group.$1, style: labelStyle),
                        ),
                        for (final r in group.$2)
                          roleTile(
                            label: assocRoleLabel(r),
                            selected: selectedAssocIds.contains(r.id),
                            onChanged: saving
                                ? null
                                : (v) => setSheetState(() {
                                    error = false;
                                    if (v) {
                                      selectedAssocIds.add(r.id);
                                    } else {
                                      selectedAssocIds.remove(r.id);
                                    }
                                  }),
                          ),
                      ],
                    const Divider(height: 24),
                    Text('Rättigheter', style: labelStyle),
                    for (final op in CrudOperation.values)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(op.displayName),
                        value: selectedOps.contains(op.value),
                        onChanged: saving
                            ? null
                            : (v) => setSheetState(() {
                                if (v) {
                                  selectedOps.add(op.value);
                                } else {
                                  selectedOps.remove(op.value);
                                }
                              }),
                      ),
                    if (error)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Välj minst en roll.',
                          style: TextStyle(
                            color: Theme.of(sheetContext).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (selectedUserIds.isEmpty &&
                                    selectedAssocIds.isEmpty) {
                                  setSheetState(() => error = true);
                                  return;
                                }
                                setSheetState(() => saving = true);
                                final ops = selectedOps.toList();
                                final newPerms = <RolePermission>[
                                  for (final id in selectedUserIds)
                                    RolePermission(
                                      roleCategory: RoleCategory.user.value,
                                      roleTypeId: id,
                                      allowedOperations: ops,
                                    ),
                                  for (final id in selectedAssocIds)
                                    RolePermission(
                                      roleCategory:
                                          RoleCategory.association.value,
                                      roleTypeId: id,
                                      allowedOperations: ops,
                                    ),
                                ];
                                final ok = await authStore.addRolePermissions(
                                  menu.name,
                                  newPerms,
                                );
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                                showResult(
                                  ok,
                                  'Rättigheter tillagda',
                                  'Kunde inte lägga till rättigheter',
                                );
                              },
                        child: saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Tilldela'),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      }

      // ---- Funktioner tab: feature on/off toggles for the association ----
      Widget featuresTab() {
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            Text(
              'Slå av funktioner som föreningen inte använder. '
              'Avstängda döljs för alla.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 8),
            for (final f in toggleableFeatures)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(f.label),
                value: authStore.isFeatureEnabled(f.token),
                onChanged: (!canEdit || savingFeatures.value)
                    ? null
                    : (enabled) async {
                        savingFeatures.value = true;
                        final disabled = {
                          ...?authStore.association.value?.disabledFeatures,
                        };
                        if (enabled) {
                          disabled.remove(f.token);
                        } else {
                          disabled.add(f.token);
                        }
                        final ok = await authStore.updateDisabledFeatures(
                          disabled.toList(),
                        );
                        savingFeatures.value = false;
                        showResult(
                          ok,
                          'Funktioner uppdaterade',
                          'Kunde inte uppdatera funktioner',
                        );
                      },
              ),
          ],
        );
      }

      // ---- Rättigheter tab: per-role permission matrix ----
      Widget permissionsTab() {
        if (menus.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Inga behörigheter att visa ännu.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ),
          );
        }

        // Show menus in a stable, human-friendly order (known tokens first).
        final ordered = [...menus]
          ..sort((a, b) {
            final ia = _menuLabels.keys.toList().indexOf(a.name);
            final ib = _menuLabels.keys.toList().indexOf(b.name);
            return (ia == -1 ? 999 : ia).compareTo(ib == -1 ? 999 : ib);
          });

        // Filter by the menu label/token or any role name within it.
        final query = searchQuery.value.trim().toLowerCase();
        final filtered = query.isEmpty
            ? ordered
            : ordered.where((menu) {
                final label = (_menuLabels[menu.name] ?? menu.name)
                    .toLowerCase();
                if (label.contains(query) ||
                    menu.name.toLowerCase().contains(query)) {
                  return true;
                }
                return menu.permissions.any(
                  (p) => roleName(p).toLowerCase().contains(query),
                );
              }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SearchField(
                hintText: 'Sök behörighet eller roll...',
                onChanged: (v) => searchQuery.value = v,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  if (canEdit)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                      child: Text(
                        'Tryck på en roll för att ändra.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Inga behörigheter matchar "$query".',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ),
                  for (final menu in filtered)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _menuLabels[menu.name] ?? menu.name,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (canEdit)
                                  TextButton.icon(
                                    onPressed: () => addPermission(menu),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Lägg till'),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (menu.permissions.isEmpty)
                              Text(
                                'Ingen roll har åtkomst.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.hintColor,
                                ),
                              )
                            else
                              for (final p in sortedPermissions(menu)) ...[
                                Builder(
                                  builder: (context) {
                                    final isAdmin = isAdminRole(p);
                                    final tappable = canEdit && !isAdmin;
                                    return InkWell(
                                      onTap: tappable
                                          ? () => editPermission(menu, p)
                                          : null,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                roleName(p),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: isAdmin
                                                    ? const [
                                                        _OpChip(
                                                          label: 'Full åtkomst',
                                                          enabled: true,
                                                        ),
                                                      ]
                                                    : [
                                                        for (final op
                                                            in CrudOperation
                                                                .values)
                                                          _OpChip(
                                                            label:
                                                                op.displayName,
                                                            enabled: p
                                                                .allowedOperations
                                                                .contains(
                                                                  op.value,
                                                                ),
                                                          ),
                                                      ],
                                              ),
                                            ),
                                            if (canEdit)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 4,
                                                ),
                                                child: Icon(
                                                  isAdmin
                                                      ? Icons.lock_outline
                                                      : Icons.edit_outlined,
                                                  size: 18,
                                                  color: theme.hintColor,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                              ],
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        );
      }

      return DefaultTabController(
        length: 2,
        child: GradientScaffold(
          title: 'Rättigheter',
          body: Column(
            children: [
              const HelpTip(
                id: 'permissions',
                text:
                    'Under Funktioner slår du av delar av appen som föreningen '
                    'inte använder. Under Rättigheter väljer du vilka roller som '
                    'får läsa, skapa, uppdatera och radera i varje funktion: '
                    'alla medlemmar, hela styrelsen eller enskilda roller. '
                    'Administratörer har alltid full åtkomst.',
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Funktioner'),
                  Tab(text: 'Rättigheter'),
                ],
              ),
              Expanded(
                child: TabBarView(children: [featuresTab(), permissionsTab()]),
              ),
            ],
          ),
        ),
      );
    };
  }
}

class _OpChip extends StatelessWidget {
  final String label;
  final bool enabled;

  const _OpChip({required this.label, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = enabled ? theme.colorScheme.primary : theme.disabledColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: enabled
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(enabled ? Icons.check : Icons.remove, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: enabled ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
