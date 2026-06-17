import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import '../../../core/di/injection_keys.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

/// Swedish labels for the permission/menu tokens stored on the association.
const _menuLabels = <String, String>{
  'posts': 'Nyheter',
  'chat': 'Meddelanden',
  'issues': 'Felanmälan & ärenden',
  'calendar_events': 'Kalender',
  'places': 'Lokaler',
  'gadgets': 'Prylar',
  'residences': 'Bostäder',
  'parking_lots': 'Parkeringar',
  'folders_and_files': 'Dokument',
  'board_meetings': 'Styrelsen',
  'users': 'Användare',
  'user_role_types': 'Behörigheter',
  'invoices': 'Fakturor',
  'forms': 'Formulär',
};

class PermissionsPage extends CompositionWidget {
  static const String path = '/permissions';

  const PermissionsPage({super.key});

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);

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

    String roleName(RolePermission p) {
      if (p.roleCategory == RoleCategory.user.value) {
        final match = authStore.userRoleTypes.value
            .where((r) => r.id == p.roleTypeId)
            .firstOrNull;
        return match?.name ?? 'Okänd användarroll';
      }
      final match = authStore.associationRoleTypes.value
          .where((r) => r.id == p.roleTypeId)
          .firstOrNull;
      return match?.name ?? 'Okänd föreningsroll';
    }

    return (context) {
      final theme = Theme.of(context);
      final menus = authStore.menuPermissions.value;

      if (menus.isEmpty) {
        return const GradientScaffold(
          title: 'Behörigheter',
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Inga behörigheter att visa ännu.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }

      // Show menus in a stable, human-friendly order (known tokens first).
      final ordered = [...menus]..sort((a, b) {
          final ia = _menuLabels.keys.toList().indexOf(a.name);
          final ib = _menuLabels.keys.toList().indexOf(b.name);
          return (ia == -1 ? 999 : ia).compareTo(ib == -1 ? 999 : ib);
        });

      return GradientScaffold(
        title: 'Behörigheter',
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
              child: Text(
                'Översikt över vilka roller som får göra vad i föreningen.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.hintColor),
              ),
            ),
            for (final menu in ordered)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _menuLabels[menu.name] ?? menu.name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (menu.permissions.isEmpty)
                        Text(
                          'Ingen roll har åtkomst.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.hintColor),
                        )
                      else
                        for (final p in menu.permissions) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  roleName(p),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    for (final op in CrudOperation.values)
                                      _OpChip(
                                        label: op.displayName,
                                        enabled: p.allowedOperations
                                            .contains(op.value),
                                      ),
                                  ],
                                ),
                              ),
                            ],
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
    final color =
        enabled ? theme.colorScheme.primary : theme.disabledColor;
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
          Icon(
            enabled ? Icons.check : Icons.remove,
            size: 13,
            color: color,
          ),
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
