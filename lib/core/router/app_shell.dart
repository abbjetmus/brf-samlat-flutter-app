import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_store.dart';
import '../di/injection_keys.dart';
import '../utils/permissions_utils.dart';

/// One tab in the bottom tab bar. The order here is the order of the
/// StatefulShellRoute branches in router.dart — keep them in sync.
class AppTab {
  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;

  /// Whether this user/association has the tab (feature on + read permission).
  final bool Function(AuthStore auth) visible;

  const AppTab({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
    required this.visible,
  });
}

bool _can(AuthStore auth, String feature) =>
    auth.isFeatureEnabled(feature) &&
    auth.hasPermission(feature, CrudOperation.read);

/// Hem · Anslag · Boka · Ärenden · Mer. What people do every week is one tap
/// away; everything else lives under Mer (with search). Tabs for features the
/// association has turned off, or the user can't read, are hidden.
final appTabs = <AppTab>[
  AppTab(
    label: 'Hem',
    path: '/',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    visible: (_) => true,
  ),
  AppTab(
    label: 'Anslag',
    path: '/posts',
    icon: Icons.article_outlined,
    selectedIcon: Icons.article,
    visible: (auth) => _can(auth, 'posts'),
  ),
  AppTab(
    label: 'Boka',
    path: '/book',
    icon: Icons.calendar_today_outlined,
    selectedIcon: Icons.calendar_today,
    visible: (auth) => _can(auth, 'places') || _can(auth, 'gadgets'),
  ),
  AppTab(
    label: 'Ärenden',
    path: '/issues',
    icon: Icons.build_outlined,
    selectedIcon: Icons.build,
    visible: (auth) => _can(auth, 'issues'),
  ),
  AppTab(
    label: 'Mer',
    path: '/more',
    icon: Icons.menu,
    selectedIcon: Icons.menu,
    visible: (_) => true,
  ),
];

/// Paths that are tab roots (no back button; open them with go, not push).
final Set<String> tabRootPaths = {for (final t in appTabs) t.path};

/// Opens an in-app path: tab roots switch tab, everything else is pushed on
/// top (full screen, above the tab bar), so back returns to where you were.
void openAppPath(BuildContext context, String path) {
  final clean = Uri.parse(path).path;
  if (tabRootPaths.contains(clean)) {
    context.go(path);
  } else {
    context.push(path);
  }
}

/// The scaffold around the tab roots: the page above, the tab bar below.
class AppShell extends CompositionWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget Function(BuildContext) setup() {
    final props = widget();
    final authStore = inject(authStoreKey);
    final theme = useTheme();

    // Recomputed when the user, association (feature toggles) or role
    // permissions change.
    final visibleTabs = computed(() {
      authStore.currentUser.value;
      authStore.association.value;
      authStore.menuPermissions.value;
      return [
        for (final (i, tab) in appTabs.indexed)
          if (tab.visible(authStore)) (i, tab),
      ];
    });

    return (context) {
      final shell = props.value.navigationShell;
      final tabs = visibleTabs.value;
      final selected = tabs.indexWhere((t) => t.$1 == shell.currentIndex);

      return Scaffold(
        body: shell,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.value.colorScheme.outline),
            ),
          ),
          child: NavigationBar(
            selectedIndex: selected < 0 ? 0 : selected,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (i) {
              final branch = tabs[i].$1;
              // Tapping the current tab goes back to its first page.
              shell.goBranch(
                branch,
                initialLocation: branch == shell.currentIndex,
              );
            },
            destinations: [
              for (final (_, tab) in tabs)
                NavigationDestination(
                  icon: Icon(tab.icon),
                  selectedIcon: Icon(tab.selectedIcon),
                  label: tab.label,
                ),
            ],
          ),
        ),
      );
    };
  }
}
