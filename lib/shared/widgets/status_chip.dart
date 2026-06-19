import 'package:flutter/material.dart';

/// Semantic tone for a [StatusChip].
enum StatusTone { neutral, info, success, warning, danger }

/// A small, self-contained status pill that stays readable in both light and
/// dark mode.
///
/// Page-level code used to hardcode pale backgrounds (e.g. `Colors.orange.shade50`)
/// on a [Chip], whose label color is inherited from the theme. In dark mode that
/// produced a pale box with near-white text — effectively invisible. [StatusChip]
/// derives both background and foreground from the current [Brightness], so the
/// contrast holds either way.
class StatusChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final StatusTone tone;

  const StatusChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = StatusTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _StatusColors.of(context, tone);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: icon != null ? 10 : 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.foreground.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: colors.foreground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: colors.foreground,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusColors {
  final Color background;
  final Color foreground;

  const _StatusColors(this.background, this.foreground);

  factory _StatusColors.of(BuildContext context, StatusTone tone) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (tone == StatusTone.neutral) {
      return _StatusColors(
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
      );
    }

    final swatch = switch (tone) {
      StatusTone.info => Colors.blue,
      StatusTone.success => Colors.green,
      StatusTone.warning => Colors.orange,
      StatusTone.danger => Colors.red,
      StatusTone.neutral => Colors.grey, // unreachable
    };

    return isDark
        ? _StatusColors(swatch.withValues(alpha: 0.22), swatch.shade200)
        : _StatusColors(swatch.shade50, swatch.shade900);
  }
}
