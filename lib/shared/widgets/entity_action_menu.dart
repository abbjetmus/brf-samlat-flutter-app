import 'package:flutter/material.dart';

/// A single entry in an [EntityActionMenu] — typically "Uppdatera" or "Radera".
class EntityAction {
  const EntityAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;

  /// Renders the entry in red (used for "Radera").
  final bool destructive;

  /// "Uppdatera" entry. Add it wherever editing the entity is supported.
  factory EntityAction.update(
    VoidCallback onSelected, {
    String label = 'Uppdatera',
  }) => EntityAction(
    icon: Icons.edit_outlined,
    label: label,
    onSelected: onSelected,
  );

  /// "Radera" entry, styled in red.
  factory EntityAction.delete(
    VoidCallback onSelected, {
    String label = 'Radera',
  }) => EntityAction(
    icon: Icons.delete_outline,
    label: label,
    onSelected: onSelected,
    destructive: true,
  );
}

/// Overflow (`more_vert`) menu that replaces standalone action icons such as a
/// lone delete button. Pass only the actions the current screen supports — e.g.
/// `[EntityAction.delete(...)]`, or both update + delete — and the menu shows
/// exactly those. Renders nothing when [actions] is empty.
///
/// Use [EntityActionMenu.header] inside a gradient header so the trigger matches
/// the circular translucent [HeaderIconButton]; the default constructor renders
/// a plain `more_vert` button for list rows and bottom sheets.
class EntityActionMenu extends StatelessWidget {
  const EntityActionMenu({
    super.key,
    required this.actions,
    this.tooltip = 'Fler val',
  }) : headerStyle = false;

  const EntityActionMenu.header({
    super.key,
    required this.actions,
    this.tooltip = 'Fler val',
  }) : headerStyle = true;

  final List<EntityAction> actions;

  /// When true the trigger matches the circular white [HeaderIconButton].
  final bool headerStyle;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<EntityAction>(
      tooltip: tooltip,
      position: PopupMenuPosition.under,
      onSelected: (action) => action.onSelected(),
      itemBuilder: (context) => [
        for (final action in actions)
          PopupMenuItem<EntityAction>(
            value: action,
            child: Row(
              children: [
                Icon(
                  action.icon,
                  size: 20,
                  color: action.destructive ? Colors.red : null,
                ),
                const SizedBox(width: 12),
                Text(
                  action.label,
                  style: action.destructive
                      ? const TextStyle(color: Colors.red)
                      : null,
                ),
              ],
            ),
          ),
      ],
      icon: headerStyle ? null : const Icon(Icons.more_vert),
      child: headerStyle ? const _HeaderTrigger() : null,
    );
  }
}

/// The round `more_vert` in the page header, matching [HeaderIconButton].
class _HeaderTrigger extends StatelessWidget {
  const _HeaderTrigger();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: CircleBorder(side: BorderSide(color: colors.outline)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(Icons.more_vert, color: colors.onSurface, size: 22),
      ),
    );
  }
}
