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
        horizontal: icon != null ? 9 : 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
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
              fontSize: 12.5,
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

  /// Colour means something: green (tall) = done / yours / fine, amber
  /// (bärnsten) = needs someone, red only for real danger, grey otherwise.
  factory _StatusColors.of(BuildContext context, StatusTone tone) {
    final colors = Theme.of(context).colorScheme;
    return switch (tone) {
      StatusTone.neutral || StatusTone.info => _StatusColors(
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
      StatusTone.success => _StatusColors(
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      StatusTone.warning => _StatusColors(
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      StatusTone.danger => _StatusColors(
        colors.errorContainer,
        colors.onErrorContainer,
      ),
    };
  }
}
