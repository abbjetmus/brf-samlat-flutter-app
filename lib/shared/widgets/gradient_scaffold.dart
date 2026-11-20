import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_shell.dart';
import '../../core/theme/app_theme.dart';

/// A round 44 px icon button for page headers (white with a hairline border).
/// Supports an optional numeric badge (e.g. unseen notifications).
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final VoidCallback onPressed;
  final String? tooltip;

  const HeaderIconButton({
    super.key,
    required this.icon,
    this.badgeCount = 0,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final button = Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: colors.surface,
          shape: CircleBorder(side: BorderSide(color: colors.outline)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, color: colors.onSurface, size: 22),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.signal,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.surface, width: 2),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );

    return Semantics(
      button: true,
      label: tooltip,
      child: tooltip != null
          ? Tooltip(message: tooltip!, child: button)
          : button,
    );
  }
}

/// The page header: back button and actions on top, then a large left-aligned
/// title. Tab roots (Hem, Anslag, Boka, Ärenden, Mer) have no back button and
/// put the actions beside the title.
///
/// (The name is historical — the header used to be a green gradient.)
class AppGradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Overrides back-button visibility. When null a back button is shown on
  /// every page except the tab roots (it pops the route, or goes to Hem when
  /// there is nothing to pop, e.g. opened from a notification).
  final bool? showBack;

  /// Custom handler for the back button — used for in-page navigation (e.g.
  /// moving up a folder hierarchy without changing the route).
  final VoidCallback? onBack;

  const AppGradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack,
    this.onBack,
  });

  static bool _isTabRoot(BuildContext context) {
    try {
      return tabRootPaths.contains(GoRouterState.of(context).uri.path);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final back = showBack ?? !_isTabRoot(context);

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: back
              ? theme.textTheme.headlineSmall
              : theme.textTheme.headlineLarge,
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );

    final actionRow = [
      for (final (i, action) in actions.indexed) ...[
        if (i > 0) const SizedBox(width: 8),
        action,
      ],
    ];

    if (!back) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20, topInset + 20, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleBlock),
            ...actionRow,
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(10, topInset + 6, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Tillbaka',
                  iconSize: 24,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                  icon: const Icon(Icons.arrow_back),
                  onPressed:
                      onBack ??
                      () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          // Deep-linked from a notification: nothing to pop.
                          context.go('/');
                        }
                      },
                ),
                const Spacer(),
                ...actionRow,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 0, 0),
            child: titleBlock,
          ),
        ],
      ),
    );
  }
}

/// Drop-in replacement for `Scaffold` + `AppBar` that renders the shared
/// [AppGradientHeader] above the page body.
///
///   GradientScaffold(title: 'Inlägg', body: ...)
///
/// Header action icons should use [HeaderIconButton].
class GradientScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool? showBack;
  final VoidCallback? onBack;
  final bool resizeToAvoidBottomInset;

  /// Kept for compatibility — the side menu was replaced by the Mer tab.
  final bool showMenu;

  const GradientScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.showBack,
    this.onBack,
    this.resizeToAvoidBottomInset = true,
    this.showMenu = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppGradientHeader(
            title: title,
            subtitle: subtitle,
            actions: actions,
            showBack: showBack,
            onBack: onBack,
          ),
          // Bottom SafeArea so page content never sits under the system nav
          // bar. Top is handled by the header.
          Expanded(
            child: SafeArea(top: false, left: false, right: false, child: body),
          ),
        ],
      ),
    );
  }
}
