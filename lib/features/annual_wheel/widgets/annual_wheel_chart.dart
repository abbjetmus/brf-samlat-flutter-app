import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/models/pocketbase_models.dart';
import '../annual_wheel_store.dart';

/// Circular "årshjul": twelve month segments (January at the top, clockwise),
/// one dot per activity coloured by category, a today marker and the year in
/// the centre. Tapping a segment selects that month. Mirrors the web
/// `AnnualWheelChart`.
class AnnualWheelChart extends StatelessWidget {
  const AnnualWheelChart({
    super.key,
    required this.activities,
    required this.completedIds,
    required this.year,
    required this.selectedMonth,
    required this.onSelect,
  });

  final List<AnnualWheelActivitiesRecord> activities;
  final Set<String> completedIds;
  final int year;
  final int? selectedMonth;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = activities.where((a) => completedIds.contains(a.id)).length;

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest.shortestSide;
          return GestureDetector(
            onTapUp: (details) {
              final month = _monthAt(details.localPosition, size);
              if (month == null) return;
              onSelect(selectedMonth == month ? null : month);
            },
            child: CustomPaint(
              size: Size.square(size),
              painter: _WheelPainter(
                activities: activities,
                completedIds: completedIds,
                year: year,
                selectedMonth: selectedMonth,
                primary: theme.colorScheme.primary,
                surface: theme.colorScheme.surface,
                onSurface: theme.colorScheme.onSurface,
                error: theme.colorScheme.error,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$year',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$done/${activities.length} klara',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// The month (1–12) under [pos], or null outside the ring.
  static int? _monthAt(Offset pos, double size) {
    final c = size / 2;
    final dx = pos.dx - c;
    final dy = pos.dy - c;
    final r = math.sqrt(dx * dx + dy * dy);
    if (r < size * _innerRatio || r > c) return null;
    // Angle from 12 o'clock, clockwise, 0..2π.
    var a = math.atan2(dy, dx) + math.pi / 2;
    if (a < 0) a += 2 * math.pi;
    return (a / (2 * math.pi) * 12).floor() % 12 + 1;
  }
}

const _innerRatio = 0.18;

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.activities,
    required this.completedIds,
    required this.year,
    required this.selectedMonth,
    required this.primary,
    required this.surface,
    required this.onSurface,
    required this.error,
  });

  final List<AnnualWheelActivitiesRecord> activities;
  final Set<String> completedIds;
  final int year;
  final int? selectedMonth;
  final Color primary;
  final Color surface;
  final Color onSurface;
  final Color error;

  double _angle(double fraction) => fraction * 2 * math.pi - math.pi / 2;

  Offset _point(Offset c, double r, double a) =>
      Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final rOuter = size.shortestSide / 2;
    final rInner = size.shortestSide * _innerRatio;
    final rLabel = rOuter * 0.89;
    final rDotsMin = rOuter * 0.5;
    final rDotsMax = rOuter * 0.77;

    final now = DateTime.now();
    final isCurrentYear = year == now.year;

    final byMonth = List.generate(12, (_) => <AnnualWheelActivitiesRecord>[]);
    for (final a in [...activities]..sort((x, y) => x.day - y.day)) {
      if (a.month >= 1 && a.month <= 12) byMonth[a.month - 1].add(a);
    }

    final divider = Paint()
      ..color = surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (var i = 0; i < 12; i++) {
      final month = i + 1;
      final start = _angle(i / 12);
      final sweep = 2 * math.pi / 12;

      final path = Path()
        ..arcTo(Rect.fromCircle(center: c, radius: rOuter), start, sweep, true)
        ..arcTo(
          Rect.fromCircle(center: c, radius: rInner),
          start + sweep,
          -sweep,
          false,
        )
        ..close();

      final Color fill;
      if (selectedMonth == month) {
        fill = primary.withValues(alpha: 0.28);
      } else if (isCurrentYear && month == now.month) {
        fill = primary.withValues(alpha: 0.16);
      } else {
        fill = onSurface.withValues(alpha: month.isEven ? 0.04 : 0.07);
      }
      canvas.drawPath(path, Paint()..color = fill);
      canvas.drawPath(path, divider);

      // Month label
      final labelPos = _point(c, rLabel, _angle((i + 0.5) / 12));
      final tp = TextPainter(
        text: TextSpan(
          text: monthNames[i].substring(0, 3),
          style: TextStyle(
            fontSize: rOuter * 0.075,
            fontWeight: FontWeight.w600,
            color: isCurrentYear && month == now.month
                ? primary
                : onSurface.withValues(alpha: 0.7),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, labelPos - Offset(tp.width / 2, tp.height / 2));

      // Activity dots, spread in a small grid within the segment.
      final items = byMonth[i];
      const perRow = 3;
      final rows = (items.length / perRow).ceil();
      for (var k = 0; k < items.length; k++) {
        final row = k ~/ perRow;
        final inRow = math.min(perRow, items.length - row * perRow);
        final col = k % perRow;
        final r = rows <= 1
            ? (rDotsMin + rDotsMax) / 2
            : rDotsMax - row * (rDotsMax - rDotsMin) / (rows - 1);
        final pos = _point(c, r, _angle((i + (col + 1) / (inRow + 1)) / 12));
        final done = completedIds.contains(items[k].id);
        final color = categoryMeta(items[k].category).color;
        canvas.drawCircle(pos, rOuter * 0.045, Paint()..color = surface);
        canvas.drawCircle(
          pos,
          rOuter * 0.035,
          Paint()..color = done ? color.withValues(alpha: 0.35) : color,
        );
      }
    }

    // Today marker
    if (isCurrentYear) {
      final startOfYear = DateTime(year);
      final endOfYear = DateTime(year + 1);
      final fraction =
          now.difference(startOfYear).inSeconds /
          endOfYear.difference(startOfYear).inSeconds;
      canvas.drawLine(
        c,
        _point(c, rOuter - 4, _angle(fraction)),
        Paint()
          ..color = error
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    // Centre
    canvas.drawCircle(c, rInner - 4, Paint()..color = surface);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) =>
      old.activities != activities ||
      old.completedIds != completedIds ||
      old.year != year ||
      old.selectedMonth != selectedMonth ||
      old.primary != primary ||
      old.surface != surface;
}
