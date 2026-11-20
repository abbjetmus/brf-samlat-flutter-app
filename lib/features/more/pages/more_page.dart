import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_keys.dart';
import '../../../core/router/app_shell.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/permissions_utils.dart';
import '../../../core/utils/text_utils.dart';
import '../../../shared/widgets/app_menu_drawer.dart';
import '../../settings/pages/settings_page.dart';

/// "Mer" — everything that isn't a tab, grouped like the web portal's sidebar,
/// with search. Replaces the old side menu.
class MorePage extends CompositionWidget {
  static const String path = '/more';

  const MorePage({super.key});

  /// Already reachable from a tab (Anslag, Ärenden, Boka → Lokaler/Prylar).
  static const _inTabs = {'/posts', '/issues', '/places', '/gadgets'};

  @override
  Widget Function(BuildContext) setup() {
    final authStore = inject(authStoreKey);
    final theme = useTheme();
    final topInset = useContextRef<double>(
      (context) => MediaQuery.paddingOf(context).top,
    );
    final (searchController, query, _) = useTextEditingController();

    final sections = computed(() {
      authStore.association.value;
      authStore.menuPermissions.value;
      // Hidden tabs (feature off) still need a way in: keep their items here.
      final tabVisible = {
        for (final t in appTabs) t.path: t.visible(authStore),
      };
      final bookVisible = tabVisible['/book'] ?? false;
      bool inVisibleTab(String path) =>
          _inTabs.contains(path) &&
          ((path == '/places' || path == '/gadgets')
              ? bookVisible
              : tabVisible[path] ?? false);
      return [
        for (final section in visibleAppMenuSections(
          isFeatureEnabled: authStore.isFeatureEnabled,
          canRead: (p) => authStore.hasPermission(p, CrudOperation.read),
        ))
          AppMenuSection(
            section.heading,
            section.items.where((i) => !inVisibleTab(i.path)).toList(),
          ),
      ].where((s) => s.items.isNotEmpty).toList();
    });

    final shownSections = computed(() {
      final q = query.value.trim().toLowerCase();
      if (q.isEmpty) return sections.value;
      return [
        for (final s in sections.value)
          AppMenuSection(
            s.heading,
            s.items.where((i) => i.searchText.contains(q)).toList(),
          ),
      ].where((s) => s.items.isNotEmpty).toList();
    });

    return (context) {
      final textTheme = theme.value.textTheme;
      final colors = theme.value.colorScheme;
      final user = authStore.currentUser.value;
      final residence = authStore.residence.value;
      final searching = query.value.trim().isNotEmpty;

      Widget card(List<Widget> rows) => Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: BorderSide(color: colors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final (i, row) in rows.indexed) ...[
              if (i > 0) Divider(height: 1, indent: 52, color: colors.outline),
              row,
            ],
          ],
        ),
      );

      Widget row(String label, IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 22, color: colors.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );

      return Scaffold(
        body: ListView(
          padding: EdgeInsets.fromLTRB(20, topInset.value + 20, 20, 32),
          children: [
            Text('Mer', style: textTheme.headlineLarge),
            const SizedBox(height: 20),

            // Konto
            card([
              InkWell(
                onTap: () => context.push(SettingsPage.path),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: colors.primaryContainer,
                        child: Text(
                          TextUtils.initials(user?.name ?? ''),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? '',
                              style: textTheme.titleSmall?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              [
                                if (residence != null &&
                                    residence.streetAddress.isNotEmpty)
                                  residence.streetAddress,
                                'Konto och inställningar',
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Sök, t.ex. parkering eller stämma',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searching
                    ? IconButton(
                        tooltip: 'Rensa',
                        icon: const Icon(Icons.close),
                        onPressed: () => query.value = '',
                      )
                    : null,
              ),
            ),

            if (searching && shownSections.value.isEmpty)
              Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'Inget i appen matchar "${query.value.trim()}".',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),

            for (final section in shownSections.value) ...[
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  section.heading.toUpperCase(),
                  style: textTheme.labelSmall,
                ),
              ),
              card([
                for (final item in section.items)
                  row(
                    item.label.replaceAll('-\n', '').replaceAll('\n', ' '),
                    item.icon,
                    () => openAppPath(context, item.path),
                  ),
              ]),
            ],

            if (!searching) ...[
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('KONTO', style: textTheme.labelSmall),
              ),
              card([
                row(
                  'Inställningar',
                  Icons.tune,
                  () => context.push(SettingsPage.path),
                ),
              ]),
            ],
          ],
        ),
      );
    };
  }
}
