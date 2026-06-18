import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

/// A circular, translucent icon button used inside [AppGradientHeader].
///
/// Matches the action buttons on the dashboard's hero header. Supports an
/// optional numeric badge (e.g. unseen notifications).
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
    final button = Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.16),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryDarken1, width: 1.5),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// The shared gradient header shown at the top of every page. Mirrors the
/// dashboard hero: brand gradient, rounded bottom corners, white text and a
/// back button whenever the route can be popped.
class AppGradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Overrides automatic back-button detection. When null the header shows a
  /// back button if [Navigator] can pop the current route.
  final bool? showBack;

  const AppGradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final canPop = showBack ?? Navigator.of(context).canPop();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, topInset + 12, 12, 18),
      decoration: const BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (canPop) ...[
            HeaderIconButton(
              icon: Icons.arrow_back,
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  Navigator.of(context).maybePop();
                }
              },
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          if (actions.isNotEmpty)
            for (final action in actions) ...[
              const SizedBox(width: 6),
              action,
            ]
          // Mirror the back button's width so the title stays centred on screen.
          else if (canPop)
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// Drop-in replacement for `Scaffold` + `AppBar` that renders the shared
/// [AppGradientHeader] above the page body.
///
/// Usage — replace:
///   Scaffold(appBar: AppBar(title: const Text('Nyheter')), body: ...)
/// with:
///   GradientScaffold(title: 'Nyheter', body: ...)
///
/// Header action icons should use [HeaderIconButton] so they read as white on
/// the gradient.
class GradientScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool? showBack;
  final bool resizeToAvoidBottomInset;

  const GradientScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.showBack,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: Column(
        children: [
          AppGradientHeader(
            title: title,
            subtitle: subtitle,
            actions: actions,
            showBack: showBack,
          ),
          // Bottom SafeArea so page content (lists, last cards, etc.) never sits
          // under the Android system nav bar. Top is handled by the header.
          Expanded(
            child: SafeArea(
              top: false,
              left: false,
              right: false,
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}
