import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/strings.dart';
import '../../models/nutrition.dart';
import '../../theme.dart';
import 'miq_icons.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 20,
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
    final bg = color ?? (isDark ? MiqdarColors.darkCard : MiqdarColors.cream);
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
                          style: MiqType.display(
                            30,
                            height: 1.1,
                            color: active != null ? active.$5 : Miq.of(context).text,
                          ),
                        ),
                        Text(
                          active != null ? active.$1 : s.unitKcal,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
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
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: isDark ? MiqdarColors.darkText : MiqdarColors.ink,
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
                                fontWeight: FontWeight.w600,
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
              'Share of calories from each, using 4, 4 and 9 kcal per gram.',
              'حصة السعرات من كل عنصر، بمعدل 4 و4 و9 سعرات لكل غرام.',
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
                          color: MiqdarColors.saffron.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          s.date(selected.$1, 'EEE, d MMM'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Miq.of(context).accent,
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
                    '${selected.$2.toStringAsFixed(0)} ${s.unitKcal}',
                    style: MiqType.display(24, color: Miq.of(context).text),
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
                  final idx = (relX / chartWidth * points.length).floor();
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
                decoration: BoxDecoration(
                  color: MiqdarColors.saffron,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(s.tr('Daily intake', 'الاستهلاك اليومي'), style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 16),
              Container(
                width: 14,
                height: 2,
                color: Miq.of(context).text,
              ),
              const SizedBox(width: 6),
              Text(
                '${s.tr("Goal", "الهدف")}: ${widget.target.toStringAsFixed(0)} ${s.unitKcal}',
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
    final ink = isDark ? MiqdarColors.darkText : MiqdarColors.ink;
    final mutedColor = isDark ? MiqdarColors.darkMuted : MiqdarColors.muted;
    final chart = Rect.fromLTWH(40, 10, size.width - 52, size.height - 38);

    var maxY = math.max(target * 1.25, 500.0);
    for (final p in points) {
      maxY = math.max(maxY, p.$2 * 1.15);
    }

    final gridPaint = Paint()
      ..color = isDark ? MiqdarColors.darkBorder : MiqdarColors.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = chart.top + chart.height * i / 2;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: '${((maxY * (2 - i)) / 2).round()}',
          style: TextStyle(fontFamily: 'Plex', fontSize: 9.5, color: mutedColor),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    if (points.isEmpty) return;

    final slot = chart.width / points.length;
    final barWidth = math.min(26.0, math.max(2.0, slot * 0.62));
    final step = points.length > 14 ? (points.length ~/ 7) : 1;
    for (var i = 0; i < points.length; i++) {
      final x = chart.left + slot * (i + 0.5);
      final height = math.max(2.0, (points[i].$2 / maxY).clamp(0.0, 1.0) * chart.height);
      final selected = selectedIndex == i;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x - barWidth / 2, chart.bottom - height, barWidth, height),
          topLeft: Radius.circular(math.min(6, barWidth / 2)),
          topRight: Radius.circular(math.min(6, barWidth / 2)),
        ),
        Paint()..color = selected ? MiqdarColors.saffron : MiqdarColors.saffron.withValues(alpha: 0.36),
      );
      if (i % step == 0 || i == points.length - 1) {
        final tp = TextPainter(
          text: TextSpan(
            text: DateFormat('d/M').format(points[i].$1),
            style: TextStyle(
              fontFamily: 'Plex',
              fontSize: 9.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? ink : mutedColor,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, chart.bottom + 8));
      }
    }

    // The goal, on top of the bars
    if (target > 0) {
      final y = chart.bottom - (target / maxY).clamp(0.0, 1.0) * chart.height;
      canvas.drawLine(
        Offset(chart.left, y),
        Offset(chart.right, y),
        Paint()
          ..color = ink
          ..strokeWidth = 1.3,
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
    final items = [
      (
        'calories_kcal',
        s.calories,
        values.calories,
        s.unitKcal,
        MiqIcons.fire,
        MiqdarColors.caloriesAccent,
        goals?.calories,
      ),
      (
        'protein_g',
        s.protein,
        values.protein,
        s.unitG,
        MiqIcons.barbell,
        MiqdarColors.proteinAccent,
        goals?.protein,
      ),
      (
        'carbohydrate_g',
        s.carbs,
        values.carbohydrates,
        s.unitG,
        MiqIcons.grains,
        MiqdarColors.carbsAccent,
        goals?.carbohydrates,
      ),
      (
        'fat_g',
        s.fat,
        values.fat,
        s.unitG,
        MiqIcons.drop,
        MiqdarColors.fatAccent,
        goals?.fat,
      ),
      (
        'sugar_g',
        s.sugar,
        values.sugar,
        s.unitG,
        MiqIcons.iceCream,
        MiqdarColors.sugarAccent,
        goals?.sugar,
      ),
      (
        'sodium_mg',
        s.sodium,
        values.sodium,
        s.unitMg,
        MiqIcons.flask,
        MiqdarColors.sodiumAccent,
        goals?.sodium,
      ),
      (
        'potassium_mg',
        s.potassium,
        values.potassium,
        s.unitMg,
        MiqIcons.lightning,
        MiqdarColors.potassiumAccent,
        goals?.potassium,
      ),
      (
        'fiber_g',
        s.fiber,
        values.fiber,
        s.unitG,
        MiqIcons.leaf,
        MiqdarColors.fiberAccent,
        goals?.fiber,
      ),
    ];

    final miq = Miq.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 560 ? 4 : 2;
        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisExtent: 78,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            final isMissing = values.isMissing(item.$1);
            final valText = isMissing
                ? s.tr('Unknown', 'غير متوفر')
                : '${item.$3.toStringAsFixed(item.$3 >= 100 || item.$1 == 'calories_kcal' ? 0 : 1)} ${item.$4}';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: miq.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: miq.hairline),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: item.$6, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: miq.muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      valText,
                      maxLines: 1,
                      style: MiqType.display(
                        25,
                        height: 1.2,
                        color: isMissing ? MiqdarColors.warning : miq.text,
                      ),
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
      bg = MiqdarColors.warningBg;
      fg = MiqdarColors.warning;
      icon = MiqIcons.flask;
      title = s.offlineDemoRecord;
    } else if (isVerified) {
      bg = MiqdarColors.accentWash;
      fg = MiqdarColors.primary;
      icon = MiqIcons.sealCheck;
      title = s.verifiedOfficialRecord;
    } else if (verificationStatus == aiEstimateStatus) {
      bg = MiqdarColors.warningBg;
      fg = MiqdarColors.warning;
      icon = MiqIcons.sparkle;
      title = s.aiEstimateRecord;
    } else if (isCustom) {
      bg = MiqdarColors.infoBg;
      fg = MiqdarColors.info;
      icon = MiqIcons.notePencil;
      title = s.userEnteredRecord;
    } else {
      bg = MiqdarColors.warningBg;
      fg = MiqdarColors.warning;
      icon = MiqIcons.clipboardText;
      title = s.referenceSeedRecord;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? fg.withValues(alpha: 0.14) : bg,
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
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: fg,
                  ),
                ),
              ),
              if (portionSource != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    portionSource!.label(s.isAr),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
                'Calculated for the exact weight of this portion.',
                'محسوب حسب الوزن الفعلي لهذه الحصة.',
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
                color: widget.isStable ? MiqdarColors.accentGlow : MiqdarColors.warning,
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
              Icon(MiqIcons.bell, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPreview
                      ? s.tr('If you save this meal', 'إذا حفظت هذه الوجبة')
                      : '${s.nutrientLabel(alert.nutrientKey)} • ${s.tr("Above your goal", "أعلى من هدفك")}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            alert.localizedMessage(s.isAr),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? MiqdarColors.darkText : MiqdarColors.ink,
              height: 1.4,
            ),
          ),
          if (onAcknowledge != null && !alert.acknowledged) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: onAcknowledge,
                icon: const Icon(MiqIcons.check, size: 16),
                label: Text(s.tr('Got it', 'حسناً')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
