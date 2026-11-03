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
    final c = context.mq;

    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? c.border),
        boxShadow: c.cardShadow,
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

/// A list or chart with nothing in it: says what will appear and how.
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({super.key, required this.icon, required this.title, this.text, this.action});

  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.mq;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Icon(icon, size: 40, color: c.inkMuted),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: MiqdarType.titleCard.copyWith(color: c.ink),
            ),
            if (text != null) ...[
              const SizedBox(height: 8),
              Text(text!, textAlign: TextAlign.center, style: MiqdarType.body.copyWith(color: c.inkMuted)),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class NutrientDot extends StatelessWidget {
  const NutrientDot({super.key, required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

enum PillTone { neutral, accent, danger, info }

/// A small label for amounts and states. Never tappable.
class MiqdarPill extends StatelessWidget {
  const MiqdarPill({super.key, required this.text, this.tone = PillTone.neutral, this.icon});

  final String text;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.mq;
    final (bg, fg) = switch (tone) {
      PillTone.neutral => (c.surfaceSunken, c.ink),
      PillTone.accent => (c.accentSoft, c.accentInk),
      PillTone.danger => (c.dangerSoft, c.danger),
      PillTone.info => (c.infoSoft, c.info),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: MiqdarType.label.copyWith(color: fg)),
          ),
        ],
      ),
    );
  }
}

/// One switch for mutually exclusive views: Add Meal mode, Insights period, language.
class MiqdarSegmented<T> extends StatelessWidget {
  const MiqdarSegmented({super.key, required this.options, required this.value, required this.onChanged});

  final List<({T value, String label, IconData? icon})> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.mq;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          for (final (index, option) in options.indexed) ...[
            if (index > 0) const SizedBox(width: 4),
            Expanded(
              child: Semantics(
                button: true,
                selected: option.value == value,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(option.value),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: option.value == value ? c.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: option.value == value && !c.isDark
                          ? const [BoxShadow(color: Color(0x1F1B2921), blurRadius: 3, offset: Offset(0, 1))]
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (option.icon != null) ...[
                            Icon(
                              option.icon,
                              size: 20,
                              color: option.value == value ? c.primary : c.inkMuted,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            option.label.replaceAll(' ', '\u00A0'),
                            maxLines: 1,
                            softWrap: false,
                            style: MiqdarType.bodyStrong.copyWith(
                              color: option.value == value ? c.ink : c.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A round 40 px button with one icon and an optional unread count.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.tooltip, this.onPressed, this.count = 0});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.mq;
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          fixedSize: const Size(40, 40),
          minimumSize: const Size(40, 40),
          padding: EdgeInsets.zero,
          backgroundColor: c.surface,
          foregroundColor: c.ink,
          side: BorderSide(color: c.borderStrong, width: 1.5),
        ),
        icon: Icon(icon, size: 22),
      ),
    );
  }
}

/// The square − and + buttons beside a number.
class StepSquareButton extends StatelessWidget {
  const StepSquareButton({super.key, this.icon, this.label, required this.onTap, this.tooltip})
      : assert(icon != null || label != null);

  final IconData? icon;
  final String? label;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.mq;
    final button = Material(
      color: c.surfaceSunken,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 10),
          alignment: Alignment.center,
          child: label != null
              ? Text(label!, textDirection: ui.TextDirection.ltr, style: MiqdarType.label.copyWith(color: c.ink))
              : Icon(icon, size: 20, color: c.ink),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

enum ScaleVisualState { connected, disconnected, fault, simulated }

extension ScaleVisualStateOf on ScaleDeviceState {
  ScaleVisualState get visualState {
    if (!online) return ScaleVisualState.disconnected;
    if (sensorError != null) return ScaleVisualState.fault;
    if (simulated) return ScaleVisualState.simulated;
    return ScaleVisualState.connected;
  }
}

/// The scale's state as a dot and words, wherever a weight is shown.
class ScaleStatusLabel extends StatelessWidget {
  const ScaleStatusLabel({super.key, required this.state, this.shortConnected = false});

  final ScaleVisualState state;

  /// "Connected" rather than "Scale connected", on the Scale screen itself.
  final bool shortConnected;

  @override
  Widget build(BuildContext context) {
    final c = context.mq;
    final s = S.of(context);
    final (dot, textColor, label) = switch (state) {
      ScaleVisualState.connected => (
          c.primary,
          c.ink,
          shortConnected ? s.tr('Connected', 'متصل') : s.tr('Scale connected', 'الميزان متصل'),
        ),
      ScaleVisualState.disconnected => (
          c.inkMuted,
          c.ink,
          shortConnected ? s.tr('Not connected', 'غير متصل') : s.tr('Scale not connected', 'الميزان غير متصل'),
        ),
      ScaleVisualState.fault => (
          c.danger,
          c.danger,
          s.tr('Weight sensor not responding', 'حساس الوزن لا يستجيب'),
        ),
      ScaleVisualState.simulated => (
          c.accent,
          c.accentInk,
          s.tr('Simulated scale, not real food', 'ميزان محاكاة، ليس طعاماً حقيقياً'),
        ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NutrientDot(color: dot, size: 9),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MiqdarType.bodyStrong.copyWith(fontSize: 14, color: textColor),
          ),
        ),
      ],
    );
  }
}

/// One nutrient amount on a neutral tile; the dot carries the nutrient's color.
class NutrientTile extends StatelessWidget {
  const NutrientTile({
    super.key,
    required this.label,
    required this.color,
    this.value,
    this.unit,
    this.goal,
  });

  final String label;
  final Color color;

  /// Null shows Unknown: never 0 for a nutrient nobody knows.
  final String? value;
  final String? unit;
  final String? goal;

  @override
  Widget build(BuildContext context) {
    final c = context.mq;
    final s = S.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NutrientDot(color: color),
                const SizedBox(width: 6),
                Text(label, style: MiqdarType.label.copyWith(color: c.inkMuted)),
              ],
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: value == null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(MiqdarIcons.help, size: 18, color: c.accentInk),
                      const SizedBox(width: 4),
                      Text(
                        s.tr('Unknown', 'غير متوفر'),
                        style: MiqdarType.bodyStrong.copyWith(height: 26 / 15, color: c.accentInk),
                      ),
                    ],
                  )
                : Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: value,
                          style: const TextStyle(fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w700),
                        ),
                        if (unit != null)
                          TextSpan(
                            text: ' $unit',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                      ],
                      style: TextStyle(color: c.ink, fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ),
          ),
          if (goal != null)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(goal!, style: MiqdarType.caption.copyWith(color: c.inkMuted)),
            ),
        ],
      ),
    );
  }
}

/// The Home calorie ring. It fills clockwise in English and counter-clockwise in Arabic.
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
    final c = context.mq;
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
            progressColor: isOver ? c.accent : c.nCalories,
            trackColor: c.surfaceSunken,
            tickColor: c.borderStrong.withValues(alpha: 0.55),
            clockwise: !s.isAr,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      MiqdarIcons.localFireDepartment,
                      fill: 1,
                      size: 20,
                      color: isOver ? c.accentInk : c.primary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      consumed.toStringAsFixed(0),
                      textDirection: ui.TextDirection.ltr,
                      style: MiqdarType.numberXl.copyWith(fontSize: 40, height: 44 / 40, color: c.ink),
                    ),
                    Text(
                      trackingOnly || target <= 0
                          ? s.unitKcal
                          : '/ ${target.toStringAsFixed(0)} ${s.unitKcal}',
                      style: MiqdarType.label.copyWith(fontWeight: FontWeight.w500, color: c.inkMuted),
                    ),
                    if (!trackingOnly && target > 0) ...[
                      const SizedBox(height: 6),
                      MiqdarPill(
                        tone: isOver ? PillTone.accent : PillTone.neutral,
                        text: isOver
                            ? '+${diff.toStringAsFixed(0)} ${s.tr("above", "فوق الهدف")}'
                            : '${diff.toStringAsFixed(0)} ${s.tr("left", "متبقٍ")}',
                      ),
                    ],
                  ],
                ),
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
    required this.progressColor,
    required this.trackColor,
    required this.tickColor,
    required this.clockwise,
  });

  final double progress;
  final Color progressColor;
  final Color trackColor;
  final Color tickColor;
  final bool clockwise;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 14.0;
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 24; i++) {
      final angle = (math.pi * 2 * i) / 24;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final outer = radius - strokeWidth / 2 - 5;
      canvas.drawLine(center + direction * outer, center + direction * (outer - (i % 6 == 0 ? 7 : 4)), tickPaint);
    }

    if (progress <= 0.001) return;
    final sweep = math.pi * 2 * progress.clamp(0.0, 1.0) * (clockwise ? 1 : -1);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialCaloriePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.tickColor != tickColor ||
      oldDelegate.clockwise != clockwise;
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
    final c = context.mq;
    final proteinKcal = widget.values.protein * 4;
    final carbsKcal = widget.values.carbohydrates * 4;
    final fatKcal = widget.values.fat * 9;
    final macroTotalKcal = proteinKcal + carbsKcal + fatKcal;
    double pct(double v) => macroTotalKcal <= 0 ? 0.0 : v / macroTotalKcal;

    final segments = [
      (s.protein, pct(proteinKcal), widget.values.protein, proteinKcal, c.nProtein),
      (s.carbs, pct(carbsKcal), widget.values.carbohydrates, carbsKcal, c.nCarbs),
      (s.fat, pct(fatKcal), widget.values.fat, fatKcal, c.nFat),
    ];

    final active = selectedIndex != null ? segments[selectedIndex!] : null;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 124,
                height: 124,
                child: CustomPaint(
                  painter: _MacroDonutPainter(
                    segments: segments.map((e) => (e.$2, e.$5)).toList(),
                    selectedIndex: selectedIndex,
                    trackColor: c.surfaceSunken,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          active != null
                              ? '${(active.$2 * 100).round()}%'
                              : widget.values.calories.toStringAsFixed(0),
                          style: MiqdarType.titleSection.copyWith(color: c.ink),
                        ),
                        Text(
                          active != null ? active.$1 : s.unitKcal,
                          style: MiqdarType.caption.copyWith(color: c.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: List.generate(segments.length, (i) {
                    final seg = segments[i];
                    final isSelected = selectedIndex == i;
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => selectedIndex = isSelected ? null : i),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? c.surfaceSunken : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            NutrientDot(color: seg.$5),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(seg.$1, style: MiqdarType.label.copyWith(color: c.ink)),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Text(
                                      '${seg.$3.toStringAsFixed(1)} ${s.unitG} • ${seg.$4.toStringAsFixed(0)} ${s.unitKcal}',
                                      style: MiqdarType.caption.copyWith(color: c.inkMuted),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(seg.$2 * 100).round()}%',
                              style: MiqdarType.bodyStrong.copyWith(color: c.ink),
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
            style: MiqdarType.caption.copyWith(color: c.inkMuted),
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
    required this.trackColor,
  });

  final List<(double, Color)> segments;
  final int? selectedIndex;
  final Color trackColor;

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
          ..color = trackColor
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
          ..strokeCap = StrokeCap.butt,
      );
      start += math.pi * 2 * seg.$1;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroDonutPainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.trackColor != trackColor;
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
    final c = context.mq;
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
                children: [
                  MiqdarPill(text: s.date(selected.$1, 'EEE, d MMM')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${selected.$3} ${s.tr("meal(s)", "وجبات")}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MiqdarType.caption.copyWith(color: c.inkMuted),
                    ),
                  ),
                  Text(
                    '${selected.$2.toStringAsFixed(0)} / ${widget.target.toStringAsFixed(0)} ${s.unitKcal}',
                    style: MiqdarType.label.copyWith(color: c.ink),
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
                child: Directionality(
                  textDirection: ui.TextDirection.ltr,
                  child: CustomPaint(
                    painter: _WeeklyTrendPainter(
                      points: points,
                      target: widget.target,
                      selectedIndex: selectedIndex ?? (points.isEmpty ? null : points.length - 1),
                      tokens: c,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              NutrientDot(color: c.nCalories),
              const SizedBox(width: 6),
              Text(s.tr('Daily intake', 'الاستهلاك اليومي'), style: MiqdarType.caption.copyWith(color: c.inkMuted)),
              const SizedBox(width: 16),
              Container(width: 14, height: 2.5, color: c.accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${s.tr("Goal", "الهدف")}: ${widget.target.toStringAsFixed(0)} ${s.unitKcal}',
                  style: MiqdarType.caption.copyWith(color: c.inkMuted),
                ),
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
    required this.tokens,
  });

  final List<(DateTime, double, int)> points;
  final double target;
  final int? selectedIndex;
  final MiqdarTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(40, 10, size.width - 52, size.height - 38);
    final gridPaint = Paint()
      ..color = tokens.border
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
          style: TextStyle(fontSize: 11, color: tokens.inkMuted),
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
        ..color = tokens.accent
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
              fontSize: 11,
              fontWeight: selectedIndex == i ? FontWeight.w700 : FontWeight.w500,
              color: selectedIndex == i ? tokens.ink : tokens.inkMuted,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, chart.bottom + 8));
      }
    }

    // Smooth line
    final linePath = Path()..moveTo(coords.first.dx, coords.first.dy);
    for (var i = 0; i < coords.length - 1; i++) {
      final p0 = coords[i];
      final p1 = coords[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..color = tokens.nCalories
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < coords.length; i++) {
      final isSel = selectedIndex == i;
      canvas.drawCircle(coords[i], isSel ? 7 : 4, Paint()..color = tokens.nCalories);
      canvas.drawCircle(coords[i], isSel ? 3 : 1.8, Paint()..color = tokens.surface);
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyTrendPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.target != target ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.tokens != tokens;
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
    final c = context.mq;
    final items = [
      ('calories_kcal', s.calories, values.calories, s.unitKcal, c.nCalories),
      ('protein_g', s.protein, values.protein, s.unitG, c.nProtein),
      ('carbohydrate_g', s.carbs, values.carbohydrates, s.unitG, c.nCarbs),
      ('fat_g', s.fat, values.fat, s.unitG, c.nFat),
      ('sugar_g', s.sugar, values.sugar, s.unitG, c.nSugar),
      ('sodium_mg', s.sodium, values.sodium, s.unitMg, c.nSodium),
      ('potassium_mg', s.potassium, values.potassium, s.unitMg, c.nPotassium),
      ('fiber_g', s.fiber, values.fiber, s.unitG, c.nFiber),
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
            mainAxisExtent: 76,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return NutrientTile(
              label: item.$2,
              color: item.$5,
              value: values.isMissing(item.$1)
                  ? null
                  : item.$3.toStringAsFixed(item.$3 >= 100 || item.$1 == 'calories_kcal' ? 0 : 1),
              unit: item.$4,
            );
          },
        );
      },
    );
  }
}

/// Where a meal's values and its weight came from.
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
    final c = context.mq;
    final isVerified = verificationStatus == 'verified_official_record';
    final isCustom = verificationStatus == 'user_entered';

    final Color bg;
    final Color fg;
    final Color iconColor;
    final IconData icon;
    final String title;

    if (isMock) {
      (bg, fg, iconColor) = (c.accentSoft, c.accentInk, c.accentInk);
      icon = MiqdarIcons.science;
      title = s.offlineDemoRecord;
    } else if (isVerified) {
      (bg, fg, iconColor) = (c.surfaceSunken, c.ink, c.primary);
      icon = MiqdarIcons.verified;
      title = s.verifiedOfficialRecord;
    } else if (verificationStatus == aiEstimateStatus) {
      (bg, fg, iconColor) = (c.accentSoft, c.accentInk, c.accentInk);
      icon = MiqdarIcons.autoAwesome;
      title = s.aiEstimateRecord;
    } else if (isCustom) {
      (bg, fg, iconColor) = (c.infoSoft, c.info, c.info);
      icon = MiqdarIcons.editNote;
      title = s.userEnteredRecord;
    } else {
      (bg, fg, iconColor) = (c.surfaceSunken, c.ink, c.ink);
      icon = MiqdarIcons.menuBook;
      title = s.referenceSeedRecord;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: iconColor, size: 20),
                  const SizedBox(width: 8),
                  Flexible(child: Text(title, style: MiqdarType.bodyStrong.copyWith(fontSize: 14, color: fg))),
                ],
              ),
              if (portionSource != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(999)),
                  child: Text(portionSource!.label(s.isAr), style: MiqdarType.label.copyWith(color: c.ink)),
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
              style: MiqdarType.caption.copyWith(color: fg),
            ),
          ],
        ],
      ),
    );
  }
}

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
    final c = context.mq;
    final isOver = alert.severity == 'critical';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOver ? c.accentSoft : c.infoSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isOver ? MiqdarIcons.notificationsActive : MiqdarIcons.notifications,
            color: isOver ? c.accentInk : c.info,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPreview
                      ? s.tr('If you save this meal', 'إذا حفظت هذه الوجبة')
                      : '${s.nutrientLabel(alert.nutrientKey)} • ${s.tr("Above your goal", "أعلى من هدفك")}',
                  style: MiqdarType.bodyStrong.copyWith(color: c.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.localizedMessage(s.isAr),
                  style: MiqdarType.body.copyWith(fontSize: 14, height: 20 / 14, color: c.ink),
                ),
                if (onAcknowledge != null && !alert.acknowledged)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: c.ink,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(40, 32),
                    ),
                    onPressed: onAcknowledge,
                    child: Text(s.tr('Got it', 'حسناً')),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
