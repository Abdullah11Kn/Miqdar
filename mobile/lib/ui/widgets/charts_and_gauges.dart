import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/strings.dart';
import '../../models/nutrition.dart';
import '../../theme.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 22,
    this.color,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = color ?? (isDark ? MiqdarColors.darkCard : Colors.white);
    final border = borderColor ?? (isDark ? MiqdarColors.darkBorder : MiqdarColors.border);

    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border),
        boxShadow: MiqdarColors.ambientShadow(isDark),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 22,
    this.blur = 14,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.65),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Smooth animated circular calorie gauge with centered target readout (Section 3 & DES-09).
class RadialCalorieMeter extends StatelessWidget {
  const RadialCalorieMeter({
    super.key,
    required this.consumed,
    required this.target,
    this.size = 152,
    this.trackingOnly = false,
  });

  final double consumed;
  final double target;
  final double size;
  final bool trackingOnly;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ratio = (target > 0 && !trackingOnly) ? (consumed / target) : 0.0;
    final clampedRatio = ratio.isNaN || ratio.isInfinite ? 0.0 : ratio.clamp(0.0, 1.0);
    final isOver = !trackingOnly && target > 0 && consumed > target;
    final diff = (target - consumed).abs();

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: clampedRatio),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, animatedRatio, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RadialCaloriePainter(
            progress: animatedRatio,
            isOver: isOver,
            isDark: isDark,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 18,
                    color: isOver ? MiqdarColors.warning : MiqdarColors.emeraldBright,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    consumed.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: size * 0.21,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      color: isDark ? Colors.white : MiqdarColors.dark,
                    ),
                  ),
                  Text(
                    trackingOnly || target <= 0
                        ? s.unitKcal
                        : '/ ${target.toStringAsFixed(0)} ${s.unitKcal}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? MiqdarColors.darkMuted : MiqdarColors.muted,
                    ),
                  ),
                  if (!trackingOnly && target > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOver
                            ? MiqdarColors.warning.withValues(alpha: 0.16)
                            : MiqdarColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        isOver
                            ? '+${diff.toStringAsFixed(0)} ${s.tr("above", "إضافية")}'
                            : '${diff.toStringAsFixed(0)} ${s.tr("left", "متبقية")}',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: isOver ? MiqdarColors.warning : MiqdarColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadialCaloriePainter extends CustomPainter {
  const _RadialCaloriePainter({
    required this.progress,
    required this.isOver,
    required this.isDark,
  });

  final double progress;
  final bool isOver;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const startAngle = -math.pi * 0.5;
    const fullSweep = math.pi * 2;

    // Subtle track
    final trackPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : MiqdarColors.primary.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, fullSweep, false, trackPaint);

    // Subtle tick marks
    final tickPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.12)
          : MiqdarColors.primary.withValues(alpha: 0.16)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 24; i++) {
      final angle = (math.pi * 2 * i) / 24;
      final inner = center + Offset(math.cos(angle), math.sin(angle)) * (radius - 11);
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * (radius - 8);
      canvas.drawLine(inner, outer, tickPaint);
    }

    if (progress <= 0.001) return;

    final sweep = fullSweep * progress.clamp(0.0, 1.0);
    final colors = isOver
        ? [const Color(0xFF10B981), const Color(0xFFF59E0B), const Color(0xFFD97706)]
        : [const Color(0xFF047857), const Color(0xFF10B981), const Color(0xFF34D399)];

    final arcPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: fullSweep,
        colors: colors,
        transform: const GradientRotation(startAngle),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweep, false, arcPaint);

    // Glowing tip dot
    final endAngle = startAngle + sweep;
    final tipOffset = center + Offset(math.cos(endAngle), math.sin(endAngle)) * radius;
    canvas.drawCircle(
      tipOffset,
      6.5,
      Paint()..color = isOver ? MiqdarColors.warning : MiqdarColors.mintGlow,
    );
    canvas.drawCircle(
      tipOffset,
      3.0,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialCaloriePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isOver != isOver ||
      oldDelegate.isDark != isDark;
}

/// Interactive Macronutrient Donut Chart breaking down Protein, Carbs, and Fat energy percentages.
class MacroDonutChart extends StatefulWidget {
  const MacroDonutChart({super.key, required this.values});
  final NutritionValues values;

  @override
  State<MacroDonutChart> createState() => _MacroDonutChartState();
}

class _MacroDonutChartState extends State<MacroDonutChart> {
  int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final proteinKcal = widget.values.protein * 4;
    final carbsKcal = widget.values.carbohydrates * 4;
    final fatKcal = widget.values.fat * 9;
    final macroTotalKcal = proteinKcal + carbsKcal + fatKcal;
    double pct(double v) => macroTotalKcal <= 0 ? 0.0 : v / macroTotalKcal;

    final segments = [
      (
        s.protein,
        pct(proteinKcal),
        widget.values.protein,
        proteinKcal,
        MiqdarColors.proteinAccent,
      ),
      (
        s.carbs,
        pct(carbsKcal),
        widget.values.carbohydrates,
        carbsKcal,
        MiqdarColors.carbsAccent,
      ),
      (
        s.fat,
        pct(fatKcal),
        widget.values.fat,
        fatKcal,
        MiqdarColors.fatAccent,
      ),
    ];

    final active = selectedIndex != null ? segments[selectedIndex!] : null;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: CustomPaint(
                  painter: _MacroDonutPainter(
                    segments: segments.map((e) => (e.$2, e.$5)).toList(),
                    selectedIndex: selectedIndex,
                    isDark: isDark,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          active != null
                              ? '${(active.$2 * 100).round()}%'
                              : widget.values.calories.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: active != null
                                ? active.$5
                                : (isDark ? Colors.white : MiqdarColors.dark),
                          ),
                        ),
                        Text(
                          active != null ? active.$1 : s.unitKcal,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? MiqdarColors.darkMuted : MiqdarColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  children: List.generate(segments.length, (i) {
                    final seg = segments[i];
                    final isSelected = selectedIndex == i;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => selectedIndex = isSelected ? null : i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? seg.$5.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? seg.$5 : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: seg.$5,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    seg.$1,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: isDark ? Colors.white : MiqdarColors.dark,
                                    ),
                                  ),
                                  Text(
                                    '${seg.$3.toStringAsFixed(1)} ${s.unitG} • ${seg.$4.toStringAsFixed(0)} ${s.unitKcal}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${(seg.$2 * 100).round()}%',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: seg.$5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            s.tr(
              'Energy distribution uses 4/4/9 kcal/g factors. Authoritative calories come from source food records (NUT-05).',
              'يُحسب توزيع الطاقة بمعاملات 4/4/9 سعرة/غ، بينما تعتمد السعرات الرسمية على سجل الغذاء المصدري (NUT-05).',
            ),
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MacroDonutPainter extends CustomPainter {
  const _MacroDonutPainter({
    required this.segments,
    required this.selectedIndex,
    required this.isDark,
  });

  final List<(double, Color)> segments;
  final int? selectedIndex;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 12;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final total = segments.fold(0.0, (sum, item) => sum + item.$1);
    if (total <= 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = isDark ? Colors.white12 : MiqdarColors.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14,
      );
      return;
    }

    var start = -math.pi / 2;
    const gap = 0.04;
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (seg.$1 <= 0) continue;
      final sweep = math.max(0.02, (math.pi * 2 * seg.$1) - gap);
      final isSelected = selectedIndex == i;
      canvas.drawArc(
        rect,
        start + gap / 2,
        sweep,
        false,
        Paint()
          ..color = seg.$2
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 18 : 14
          ..strokeCap = StrokeCap.round,
      );
      start += math.pi * 2 * seg.$1;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroDonutPainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.isDark != isDark;
}

/// Clean canvas line/bezier chart plotting daily calorie intake against target threshold (TREND-01).
class WeeklyTrendChart extends StatefulWidget {
  const WeeklyTrendChart({
    super.key,
    required this.dailyPoints,
    required this.target,
  });

  /// Ordered list of `(DateTime date, double calories, int mealCount)`.
  final List<(DateTime, double, int)> dailyPoints;
  final double target;

  @override
  State<WeeklyTrendChart> createState() => _WeeklyTrendChartState();
}

class _WeeklyTrendChartState extends State<WeeklyTrendChart> {
  int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final points = widget.dailyPoints;
    final selected = (selectedIndex != null && selectedIndex! < points.length)
        ? points[selectedIndex!]
        : (points.isNotEmpty ? points.last : null);

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selected != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: MiqdarColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          DateFormat('EEE, d MMM').format(selected.$1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: MiqdarColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${selected.$3} ${s.tr("meal(s)", "وجبات")}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  Text(
                    '${selected.$2.toStringAsFixed(0)} / ${widget.target.toStringAsFixed(0)} ${s.unitKcal}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: isDark ? Colors.white : MiqdarColors.dark,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            height: 200,
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                onTapDown: (details) {
                  if (points.isEmpty) return;
                  final chartLeft = 40.0;
                  final chartWidth = constraints.maxWidth - 52.0;
                  final relX = (details.localPosition.dx - chartLeft).clamp(0.0, chartWidth);
                  final idx = points.length <= 1
                      ? 0
                      : ((relX / chartWidth) * (points.length - 1)).round();
                  setState(() => selectedIndex = idx.clamp(0, points.length - 1));
                },
                child: CustomPaint(
                  painter: _WeeklyTrendPainter(
                    points: points,
                    target: widget.target,
                    selectedIndex: selectedIndex ?? (points.isEmpty ? null : points.length - 1),
                    isDark: isDark,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: MiqdarColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(s.tr('Daily intake', 'الاستهلاك اليومي'), style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 16),
              Container(
                width: 14,
                height: 2.5,
                color: MiqdarColors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                '${s.tr("Target", "الهدف")}: ${widget.target.toStringAsFixed(0)} ${s.unitKcal}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyTrendPainter extends CustomPainter {
  const _WeeklyTrendPainter({
    required this.points,
    required this.target,
    required this.selectedIndex,
    required this.isDark,
  });

  final List<(DateTime, double, int)> points;
  final double target;
  final int? selectedIndex;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(40, 10, size.width - 52, size.height - 38);
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.08) : MiqdarColors.border
      ..strokeWidth = 1;

    var maxY = math.max(target * 1.25, 500.0);
    for (final p in points) {
      maxY = math.max(maxY, p.$2 * 1.15);
    }

    for (var i = 0; i <= 3; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final labelVal = ((maxY * (3 - i)) / 3).round();
      final tp = TextPainter(
        text: TextSpan(
          text: '$labelVal',
          style: TextStyle(
            fontSize: 9.5,
            color: isDark ? MiqdarColors.darkMuted : MiqdarColors.muted,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    if (points.isEmpty) return;

    // Target dashed line
    if (target > 0) {
      final targetY = chart.bottom - (target / maxY).clamp(0.0, 1.0) * chart.height;
      final targetPaint = Paint()
        ..color = MiqdarColors.warning
        ..strokeWidth = 1.6;
      for (var x = chart.left; x < chart.right; x += 10) {
        canvas.drawLine(
          Offset(x, targetY),
          Offset(math.min(x + 5, chart.right), targetY),
          targetPaint,
        );
      }
    }

    final coords = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? chart.center.dx
          : chart.left + chart.width * i / (points.length - 1);
      final y = chart.bottom - (points[i].$2 / maxY).clamp(0.0, 1.0) * chart.height;
      coords.add(Offset(x, y));

      // Draw day label along X axis (sparse if >10 points)
      final step = points.length > 14 ? (points.length ~/ 7) : 1;
      if (i % step == 0 || i == points.length - 1) {
        final label = DateFormat('d/M').format(points[i].$1);
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: selectedIndex == i ? FontWeight.w800 : FontWeight.w500,
              color: selectedIndex == i
                  ? MiqdarColors.primary
                  : (isDark ? MiqdarColors.darkMuted : MiqdarColors.muted),
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, chart.bottom + 8));
      }
    }

    // Smooth path & area fill
    final linePath = Path()..moveTo(coords.first.dx, coords.first.dy);
    for (var i = 0; i < coords.length - 1; i++) {
      final p0 = coords[i];
      final p1 = coords[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(linePath)
      ..lineTo(coords.last.dx, chart.bottom)
      ..lineTo(coords.first.dx, chart.bottom)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            MiqdarColors.emeraldBright.withValues(alpha: 0.28),
            MiqdarColors.emeraldBright.withValues(alpha: 0.01),
          ],
        ).createShader(chart),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = MiqdarColors.primary
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < coords.length; i++) {
      final isSel = selectedIndex == i;
      canvas.drawCircle(
        coords[i],
        isSel ? 6.5 : 4.0,
        Paint()..color = isSel ? MiqdarColors.mintGlow : MiqdarColors.primary,
      );
      canvas.drawCircle(
        coords[i],
        isSel ? 3.0 : 1.8,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyTrendPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.target != target ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.isDark != isDark;
}

/// 2x4 Nutrient Grid displaying Calories, Protein, Carbs, Fat, Sugar, Sodium, Potassium, and Fiber.
class NutrientGrid2x4 extends StatelessWidget {
  const NutrientGrid2x4({
    super.key,
    required this.values,
    this.goals,
  });

  final NutritionValues values;
  final NutritionGoals? goals;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      (
        'calories_kcal',
        s.calories,
        values.calories,
        s.unitKcal,
        Icons.local_fire_department_rounded,
        MiqdarColors.caloriesAccent,
        goals?.calories,
      ),
      (
        'protein_g',
        s.protein,
        values.protein,
        s.unitG,
        Icons.fitness_center_rounded,
        MiqdarColors.proteinAccent,
        goals?.protein,
      ),
      (
        'carbohydrate_g',
        s.carbs,
        values.carbohydrates,
        s.unitG,
        Icons.grain_rounded,
        MiqdarColors.carbsAccent,
        goals?.carbohydrates,
      ),
      (
        'fat_g',
        s.fat,
        values.fat,
        s.unitG,
        Icons.water_drop_rounded,
        MiqdarColors.fatAccent,
        goals?.fat,
      ),
      (
        'sugar_g',
        s.sugar,
        values.sugar,
        s.unitG,
        Icons.icecream_outlined,
        MiqdarColors.sugarAccent,
        goals?.sugar,
      ),
      (
        'sodium_mg',
        s.sodium,
        values.sodium,
        s.unitMg,
        Icons.science_outlined,
        MiqdarColors.sodiumAccent,
        goals?.sodium,
      ),
      (
        'potassium_mg',
        s.potassium,
        values.potassium,
        s.unitMg,
        Icons.bolt_rounded,
        MiqdarColors.potassiumAccent,
        goals?.potassium,
      ),
      (
        'fiber_g',
        s.fiber,
        values.fiber,
        s.unitG,
        Icons.eco_rounded,
        MiqdarColors.fiberAccent,
        goals?.fiber,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 560 ? 4 : 2;
        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: cols == 4 ? 1.55 : 1.75,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            final isMissing = values.isMissing(item.$1);
            final valText = isMissing
                ? s.tr('Unknown', 'غير متوفر')
                : '${item.$3.toStringAsFixed(item.$3 >= 100 || item.$1 == 'calories_kcal' ? 0 : 1)} ${item.$4}';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? MiqdarColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? MiqdarColors.darkBorder : MiqdarColors.border,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: item.$6.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.$5, color: item.$6, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? MiqdarColors.darkMuted : MiqdarColors.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          valText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: isMissing
                                ? MiqdarColors.warning
                                : (isDark ? Colors.white : MiqdarColors.dark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// AI Verification & Provenance Badge (AI-05, AI-07).
class AiVerificationBadge extends StatelessWidget {
  const AiVerificationBadge({
    super.key,
    required this.verificationStatus,
    this.provider,
    this.model,
    this.isMock = false,
    this.portionSource,
  });

  final String verificationStatus;
  final String? provider;
  final String? model;
  final bool isMock;
  final PortionSource? portionSource;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isVerified = verificationStatus == 'verified_official_record';
    final isCustom = verificationStatus == 'user_entered';

    final Color bg;
    final Color fg;
    final IconData icon;
    final String title;

    if (isMock) {
      bg = const Color(0xFFFFFBEB);
      fg = MiqdarColors.warning;
      icon = Icons.science_outlined;
      title = s.offlineDemoRecord;
    } else if (isVerified) {
      bg = MiqdarColors.softGreen;
      fg = MiqdarColors.primary;
      icon = Icons.verified_rounded;
      title = s.verifiedOfficialRecord;
    } else if (verificationStatus == aiEstimateStatus) {
      bg = const Color(0xFFFFFBEB);
      fg = MiqdarColors.warning;
      icon = Icons.auto_awesome_rounded;
      title = s.aiEstimateRecord;
    } else if (isCustom) {
      bg = MiqdarColors.infoBg;
      fg = MiqdarColors.info;
      icon = Icons.edit_note_rounded;
      title = s.userEnteredRecord;
    } else {
      bg = const Color(0xFFFFFBEB);
      fg = MiqdarColors.warning;
      icon = Icons.fact_check_outlined;
      title = s.referenceSeedRecord;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: fg.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: fg,
                  ),
                ),
              ),
              if (portionSource != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    portionSource!.label(s.isAr),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                ),
            ],
          ),
          if (provider != null || model != null) ...[
            const SizedBox(height: 6),
            Text(
              s.tr(
                'Analyzed by ${model ?? provider} • Scaled to your exact portion weight.',
                'تم التحليل بواسطة ${model ?? provider} • محسوب بدقة حسب وزن الحصة.',
              ),
              style: TextStyle(fontSize: 11.5, color: fg.withValues(alpha: 0.85)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pulsing camera aiming reticle for the capture viewfinder.
class AimingReticleOverlay extends StatefulWidget {
  const AimingReticleOverlay({super.key, this.isStable = true});
  final bool isStable;

  @override
  State<AimingReticleOverlay> createState() => _AimingReticleOverlayState();
}

class _AimingReticleOverlayState extends State<AimingReticleOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final scale = 0.96 + (_controller.value * 0.06);
          return Transform.scale(
            scale: scale,
            child: CustomPaint(
              size: const Size(220, 164),
              painter: _ReticleCornerPainter(
                color: widget.isStable ? MiqdarColors.mintGlow : MiqdarColors.warning,
                glowOpacity: 0.25 + _controller.value * 0.35,
              ),
            ),
          );
        },
      );
}

class _ReticleCornerPainter extends CustomPainter {
  const _ReticleCornerPainter({required this.color, required this.glowOpacity});
  final Color color;
  final double glowOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(26));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withValues(alpha: glowOpacity * 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final cornerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const len = 26.0;
    // Top-left
    canvas.drawLine(const Offset(0, len), const Offset(0, 8), cornerPaint);
    canvas.drawLine(const Offset(8, 0), const Offset(len, 0), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(size.width - len, 0), Offset(size.width - 8, 0), cornerPaint);
    canvas.drawLine(Offset(size.width, 8), Offset(size.width, len), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(0, size.height - len), Offset(0, size.height - 8), cornerPaint);
    canvas.drawLine(Offset(8, size.height), Offset(len, size.height), cornerPaint);
    // Bottom-right
    canvas.drawLine(
      Offset(size.width - len, size.height),
      Offset(size.width - 8, size.height),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width, size.height - len),
      Offset(size.width, size.height - 8),
      cornerPaint,
    );

    // Center crosshair dot
    canvas.drawCircle(
      size.center(Offset.zero),
      3.5,
      Paint()..color = color.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _ReticleCornerPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.glowOpacity != glowOpacity;
}

/// Calm, neutral nutrient notice card (PRD-07, NOTICE-06).
class NutrientNoticeCard extends StatelessWidget {
  const NutrientNoticeCard({
    super.key,
    required this.alert,
    this.onAcknowledge,
    this.isPreview = false,
  });

  final HealthAlert alert;
  final VoidCallback? onAcknowledge;
  final bool isPreview;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = alert.severity == 'critical' ? MiqdarColors.warning : MiqdarColors.info;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_none_rounded, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPreview
                      ? s.tr('Projected Nutrient Notice', 'تنبيه غذائي متوقع عند الحفظ')
                      : '${s.nutrientLabel(alert.nutrientKey)} • ${s.tr("Above Configured Limit", "أعلى من الحد المحدد")}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: accent,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${alert.evaluationMs} ms',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            alert.localizedMessage(s.isAr),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white : MiqdarColors.dark,
              height: 1.4,
            ),
          ),
          if (onAcknowledge != null && !alert.acknowledged) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: onAcknowledge,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: Text(s.tr('Acknowledge notice', 'تم الاطلاع')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
