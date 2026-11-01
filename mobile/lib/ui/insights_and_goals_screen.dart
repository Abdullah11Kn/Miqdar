import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../app.dart';
import '../app_controller.dart';
import '../l10n/strings.dart';
import '../models/nutrition.dart';
import '../theme.dart';
import 'widgets/brand.dart';
import 'widgets/charts_and_gauges.dart';
import 'widgets/miq_icons.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  int periodDays = 7;

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: periodDays - 1));

    final periodMeals = controller.meals
        .where((m) => !m.eatenAt.toLocal().isBefore(cutoff))
        .toList();

    // Group by calendar date for accurate daily aggregation (TREND-01, TREND-02)
    final byDate = <String, List<MealEntry>>{};
    for (final meal in periodMeals) {
      final key = DateFormat('yyyy-MM-dd').format(meal.eatenAt.toLocal());
      byDate.putIfAbsent(key, () => []).add(meal);
    }

    final sortedDates = byDate.keys.toList()..sort();
    final dailyPoints = sortedDates.map((key) {
      final list = byDate[key]!;
      final dayKcal = list.fold(0.0, (sum, m) => sum + m.nutrients.calories);
      return (DateTime.parse(key), dayKcal, list.length);
    }).toList();

    final loggedDaysCount = byDate.isEmpty ? 1 : byDate.length;
    final periodTotals = periodMeals.fold(
      NutritionValues.zero(),
      (sum, meal) => sum + meal.nutrients,
    );

    final dailyAvg = periodTotals.scaledBy(1.0 / loggedDaysCount);
    final goals = controller.goals;

    final content = ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.tr('Insights', 'الإحصاءات'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: s.tr('Export', 'تصدير'),
              onPressed: () => showExportSheet(context, days: periodDays),
              icon: const Icon(MiqIcons.downloadSimple),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Period Selector (7 / 30 / 90 days)
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 7, label: Text(s.tr('7 Days', '7 أيام'))),
            ButtonSegment(value: 30, label: Text(s.tr('30 Days', '30 يوماً'))),
            ButtonSegment(value: 90, label: Text(s.tr('90 Days', '90 يوماً'))),
          ],
          selected: {periodDays},
          onSelectionChanged: (sel) => setState(() => periodDays = sel.first),
        ),
        const SizedBox(height: 16),

        if (periodMeals.isEmpty)
          SurfaceCard(
            child: Column(
              children: [
                MeasureDial(
                  size: 88,
                  progress: 0,
                  strokeWidth: 5,
                  ticks: 0,
                  child: Icon(MiqIcons.chartLineUp, size: 30, color: Miq.of(context).muted),
                ),
                const SizedBox(height: 14),
                Text(
                  s.tr('Nothing to show yet', 'لا يوجد ما يُعرض بعد'),
                  style: MiqType.display(26, color: Miq.of(context).text),
                ),
                const SizedBox(height: 4),
                Text(
                  s.tr(
                    'Save a meal and your averages appear here.',
                    'احفظ وجبة وستظهر متوسطاتك هنا.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else ...[
        // Top averages, counted over the days that have meals
        Row(
          children: [
            Expanded(
              child: _InsightMetricTile(
                label: s.tr('Calories per day', 'السعرات في اليوم'),
                value: '${dailyAvg.calories.toStringAsFixed(0)} ${s.unitKcal}',
                detail:
                    s.tr(
                  '${byDate.length} logged ${byDate.length == 1 ? 'day' : 'days'}',
                  '${byDate.length} يوم مسجل',
                ),
                accent: MiqdarColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InsightMetricTile(
                label: s.tr('Protein per day', 'البروتين في اليوم'),
                value: '${dailyAvg.protein.toStringAsFixed(1)} ${s.unitG}',
                detail: goals.trackingOnly
                    ? s.tr('Average', 'المتوسط')
                    : '${s.tr("Goal", "الهدف")}: ${goals.protein.toStringAsFixed(0)} ${s.unitG}',
                accent: MiqdarColors.proteinAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Daily Calorie Trend Curve vs Daily Target (TREND-01)
        SectionHeading(s.tr('Calories by day', 'السعرات حسب اليوم')),
        const SizedBox(height: 10),
        WeeklyTrendChart(
          dailyPoints: dailyPoints,
          target: goals.calories,
        ),
        const SizedBox(height: 22),

        // Macronutrient Energy Distribution Donut Chart
        SectionHeading(s.tr('Where your calories come from', 'مصدر سعراتك')),
        const SizedBox(height: 10),
        MacroDonutChart(values: periodTotals),
        const SizedBox(height: 22),

        // Daily average per nutrient; tap one to see which meals contributed most
        SectionHeading(s.tr('Daily averages', 'المتوسطات اليومية')),
        const SizedBox(height: 10),
        Ledger(children: [
          (s.calories, dailyAvg.calories, goals.calories, s.unitKcal, MiqdarColors.caloriesAccent, (MealEntry m) => m.nutrients.calories),
          (s.protein, dailyAvg.protein, goals.protein, s.unitG, MiqdarColors.proteinAccent, (MealEntry m) => m.nutrients.protein),
          (s.carbs, dailyAvg.carbohydrates, goals.carbohydrates, s.unitG, MiqdarColors.carbsAccent, (MealEntry m) => m.nutrients.carbohydrates),
          (s.fat, dailyAvg.fat, goals.fat, s.unitG, MiqdarColors.fatAccent, (MealEntry m) => m.nutrients.fat),
          (s.sugar, dailyAvg.sugar, goals.sugar, s.unitG, MiqdarColors.sugarAccent, (MealEntry m) => m.nutrients.sugar),
          (s.sodium, dailyAvg.sodium, goals.sodium, s.unitMg, MiqdarColors.sodiumAccent, (MealEntry m) => m.nutrients.sodium),
          (s.potassium, dailyAvg.potassium, goals.potassium, s.unitMg, MiqdarColors.potassiumAccent, (MealEntry m) => m.nutrients.potassium),
          (s.fiber, dailyAvg.fiber, goals.fiber, s.unitG, MiqdarColors.fiberAccent, (MealEntry m) => m.nutrients.fiber),
        ].map(
          (n) => _NutrientTrendBar(
            label: n.$1,
            value: n.$2,
            target: goals.trackingOnly ? 0 : n.$3,
            unit: n.$4,
            color: n.$5,
            onTap: () => _showNutrientDrillDown(context, n.$1, n.$4, n.$2, n.$3, periodMeals, n.$6),
          ),
        ).toList()),
        ],
      ],
    );

    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: Text(s.navInsights)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: content,
          ),
        ),
      ),
    );
  }

  void _showNutrientDrillDown(
    BuildContext context,
    String label,
    String unit,
    double dailyAvg,
    double target,
    List<MealEntry> meals,
    double Function(MealEntry) selector,
  ) {
    final s = S.of(context);
    final sorted = [...meals]..sort((a, b) => selector(b).compareTo(selector(a)));
    final topContributors = sorted.take(5).toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                '${s.tr("Average per day", "المتوسط اليومي")}: ${dailyAvg.toStringAsFixed(1)} $unit • ${s.tr("Goal", "الهدف")}: ${target.toStringAsFixed(0)} $unit',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              Text(
                s.tr('Meals with the most', 'الوجبات الأعلى'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
              const SizedBox(height: 8),
              ...topContributors.map(
                (m) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    m.displayName(s.isAr),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${s.date(m.eatenAt.toLocal(), 'd MMM')} • ${m.weightG.toStringAsFixed(0)} ${s.unitG}',
                  ),
                  trailing: Text(
                    '${selector(m).toStringAsFixed(1)} $unit',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: MiqdarColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets the user copy their meals as CSV, which opens in any spreadsheet.
void showExportSheet(BuildContext context, {required int days}) {
  final controller = MiqdarScope.of(context);
  final s = S.of(context);
  final csv = controller.exportMealsCsv(days: days);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.tr('Export Meals', 'تصدير الوجبات'),
            style: Theme.of(ctx).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            s.tr(
              'Copy your meals from the last $days days, then paste them into a spreadsheet or note.',
              'انسخ وجباتك من آخر $days يوماً ثم الصقها في جدول بيانات أو ملاحظة.',
            ),
            style: const TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          Container(
            height: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: SingleChildScrollView(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: SelectableText(
                  csv,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: csv));
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text(s.tr('Copied', 'تم النسخ')),
                ),
              );
            },
            icon: const Icon(MiqIcons.copy),
            label: Text(s.tr('Copy', 'نسخ')),
          ),
        ],
      ),
    ),
  );
}

class _InsightMetricTile extends StatelessWidget {
  const _InsightMetricTile({
    required this.label,
    required this.value,
    required this.detail,
    required this.accent,
  });

  final String label;
  final String value;
  final String detail;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final miq = Miq.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: miq.muted)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: MiqType.display(36, color: miq.text, height: 1.15)),
          ),
          const SizedBox(height: 2),
          Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: miq.muted)),
        ],
      ),
    );
  }
}

class _NutrientTrendBar extends StatelessWidget {
  const _NutrientTrendBar({
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
    required this.color,
    required this.onTap,
  });

  final String label;
  final double value;

  /// Zero when there is no goal to compare with.
  final double target;
  final String unit;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final percent = target > 0 ? (value / target * 100).round() : null;
    final amount = value.toStringAsFixed(value >= 100 ? 0 : 1);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  percent == null
                      ? '$amount $unit'
                      : '$amount / ${target.toStringAsFixed(0)} $unit',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 18, color: MiqdarColors.muted),
              ],
            ),
            if (percent != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (percent / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: color.withValues(alpha: 0.14),
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.tr('$percent% of your goal', '$percent% من هدفك'),
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Daily goals, grouped by what people usually change.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  NutritionGoals? draft;

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: SectionHeading(text, size: 22),
      );

  Future<void> _save(MiqdarController controller, S s) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await controller.updateGoals(draft!);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(s.tr('Goals saved', 'تم حفظ الأهداف')),
      ),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    draft ??= controller.goals;

    return Scaffold(
      appBar: AppBar(title: Text(s.tr('Daily Goals', 'الأهداف اليومية'))),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => _save(controller, s),
            child: Text(s.tr('Save Goals', 'حفظ الأهداف')),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                SurfaceCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      s.tr('Just track, no goals', 'تتبع فقط بدون أهداف'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      s.tr('Hides goals and turns off notices', 'يخفي الأهداف ويوقف التنبيهات'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: draft!.trackingOnly,
                    onChanged: (v) => setState(() => draft = draft!.copyWith(trackingOnly: v)),
                  ),
                ),
                if (!draft!.trackingOnly) ...[
                  _heading(s.tr('Eat about this much', 'تناول هذا المقدار تقريباً')),
                  Ledger(children: [
                  _GoalNumericEditorCard(
                    label: s.calories,
                    value: draft!.calories,
                    min: 800,
                    max: 4500,
                    step: 50,
                    unit: s.unitKcal,
                    onChanged: (v) => setState(() => draft = draft!.copyWith(calories: v)),
                  ),
                  _GoalNumericEditorCard(
                    label: s.carbs,
                    value: draft!.carbohydrates,
                    min: 30,
                    max: 500,
                    step: 10,
                    unit: s.unitG,
                    onChanged: (v) => setState(() => draft = draft!.copyWith(carbohydrates: v)),
                  ),
                  _GoalNumericEditorCard(
                    label: s.fat,
                    value: draft!.fat,
                    min: 20,
                    max: 200,
                    step: 5,
                    unit: s.unitG,
                    onChanged: (v) => setState(() => draft = draft!.copyWith(fat: v)),
                  ),
                  _GoalNumericEditorCard(
                    label: s.potassium,
                    value: draft!.potassium,
                    min: 1000,
                    max: 6000,
                    step: 100,
                    unit: s.unitMg,
                    onChanged: (v) => setState(() => draft = draft!.copyWith(potassium: v)),
                  ),
                  ]),
                  _heading(s.tr('At least', 'على الأقل')),
                  Ledger(children: [
                  _GoalNumericEditorCard(
                    label: s.protein,
                    value: draft!.protein,
                    min: 20,
                    max: 300,
                    step: 5,
                    unit: s.unitG,
                    onChanged: (v) => setState(() => draft = draft!.copyWith(protein: v)),
                  ),
                  _GoalNumericEditorCard(
                    label: s.fiber,
                    value: draft!.fiber,
                    min: 10,
                    max: 70,
                    step: 2,
                    unit: s.unitG,
                    onChanged: (v) => setState(() => draft = draft!.copyWith(fiber: v)),
                  ),
                  ]),
                  _heading(s.tr('No more than', 'بحد أقصى')),
                  Ledger(children: [
                  _GoalNumericEditorCard(
                    label: s.sugar,
                    value: draft!.sugar,
                    min: 5,
                    max: 150,
                    step: 5,
                    unit: s.unitG,
                    onChanged: (v) => setState(() => draft = draft!.copyWith(sugar: v)),
                  ),
                  _GoalNumericEditorCard(
                    label: s.sodium,
                    value: draft!.sodium,
                    min: 400,
                    max: 5000,
                    step: 100,
                    unit: s.unitMg,
                    onChanged: (v) => setState(() => draft = draft!.copyWith(sodium: v)),
                  ),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalNumericEditorCard extends StatefulWidget {
  const _GoalNumericEditorCard({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final String unit;
  final ValueChanged<double> onChanged;

  @override
  State<_GoalNumericEditorCard> createState() => _GoalNumericEditorCardState();
}

class _GoalNumericEditorCardState extends State<_GoalNumericEditorCard> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.value.toStringAsFixed(0),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _step(double delta) {
    final next = (widget.value + delta).clamp(widget.min, widget.max).toDouble();
    _ctrl.text = next.toStringAsFixed(0);
    widget.onChanged(next);
  }

  /// Typed values count straight away, so Save never misses one.
  void _typed(String raw) {
    final parsed = double.tryParse(normalizeDigits(raw).trim());
    if (parsed != null && parsed >= widget.min && parsed <= widget.max) {
      widget.onChanged(parsed);
    }
  }

  /// The number pad has no Done key, so tapping elsewhere finishes typing.
  void _finishTyping() {
    FocusManager.instance.primaryFocus?.unfocus();
    final parsed = double.tryParse(normalizeDigits(_ctrl.text).trim()) ?? widget.value;
    final next = parsed.clamp(widget.min, widget.max).toDouble();
    _ctrl.text = next.toStringAsFixed(0);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Builder(
          builder: (context) => Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                ),
              ),
              IconButton.outlined(
                visualDensity: VisualDensity.compact,
                tooltip: '-${widget.step.toStringAsFixed(0)}',
                onPressed: () => _step(-widget.step),
                icon: const Icon(MiqIcons.minus, size: 16),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 112,
                child: TextField(
                  controller: _ctrl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Miq.of(context).text,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    suffixText: widget.unit,
                  ),
                  onChanged: _typed,
                  onSubmitted: (_) => _finishTyping(),
                  onTapOutside: (_) {
                    if (FocusScope.of(context).hasFocus) _finishTyping();
                  },
                ),
              ),
              const SizedBox(width: 6),
              IconButton.outlined(
                visualDensity: VisualDensity.compact,
                tooltip: '+${widget.step.toStringAsFixed(0)}',
                onPressed: () => _step(widget.step),
                icon: const Icon(MiqIcons.plus, size: 16),
              ),
            ],
          ),
        ),
      );
}

/// Notices about the day's meals compared with the user's goals.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (controller.unreadAlertsCount > 0)
              TextButton.icon(
                onPressed: controller.markAllAlertsRead,
                icon: const Icon(MiqIcons.checks, size: 18),
                label: Text(s.tr('Mark all read', 'تحديد الكل كمقروء')),
              ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GoalsScreen()),
              ),
              icon: const Icon(MiqIcons.slidersHorizontal, size: 18),
              label: Text(s.tr('Goals', 'الأهداف')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (controller.alerts.isEmpty)
          SurfaceCard(
            child: Row(
              children: [
                const Icon(MiqIcons.checkCircle, color: MiqdarColors.primary, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.tr('No notices', 'لا توجد تنبيهات'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      Text(
                        s.tr(
                          'You will see a note here when a meal takes you past a goal.',
                          'سترى تنبيهاً هنا عندما تتجاوز وجبة أحد أهدافك.',
                        ),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ...controller.alerts.map(
            (alert) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NutrientNoticeCard(
                alert: alert,
                onAcknowledge: () => controller.acknowledgeAlert(alert.id),
              ),
            ),
          ),
      ],
    );
  }
}
