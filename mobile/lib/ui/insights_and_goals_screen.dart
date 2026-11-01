import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../l10n/strings.dart';
import '../models/nutrition.dart';
import '../theme.dart';
import 'widgets/charts_and_gauges.dart';

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
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () => _showExportSheet(context, periodDays),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(s.tr('Export CSV', 'تصدير CSV')),
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

        // Top KPI Cards (TREND-02 denominator explicitly shown)
        Row(
          children: [
            Expanded(
              child: _InsightMetricTile(
                label: s.tr('Daily Average Energy', 'متوسط الطاقة اليومي'),
                value: '${dailyAvg.calories.toStringAsFixed(0)} ${s.unitKcal}',
                detail:
                    s.tr(
                  'Over ${byDate.length} ${byDate.length == 1 ? 'day' : 'days'}',
                  'خلال ${byDate.length} يوم',
                ),
                accent: MiqdarColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InsightMetricTile(
                label: s.tr('Daily Protein Avg', 'متوسط البروتين اليومي'),
                value: '${dailyAvg.protein.toStringAsFixed(1)} ${s.unitG}',
                detail:
                    '${s.tr("Target", "الهدف")}: ${goals.protein.toStringAsFixed(0)} ${s.unitG}/${s.tr("day", "يوم")}',
                accent: MiqdarColors.proteinAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Daily Calorie Trend Curve vs Daily Target (TREND-01)
        Text(
          s.tr('Daily Calorie Intake vs Target', 'السعرات اليومية مقارنة بالهدف اليومي'),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        const SizedBox(height: 10),
        WeeklyTrendChart(
          dailyPoints: dailyPoints,
          target: goals.calories,
        ),
        const SizedBox(height: 22),

        // Macronutrient Energy Distribution Donut Chart
        Text(
          s.tr('Macronutrient Energy Balance', 'توزيع طاقة العناصر الغذائية الكبرى'),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        const SizedBox(height: 10),
        MacroDonutChart(values: periodTotals),
        const SizedBox(height: 22),

        // Daily Average per Nutrient (Tap any bar to open S34 Nutrient Drill-Down)
        Text(
          s.tr('Daily Nutrient Averages', 'المتوسط اليومي للعناصر'),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
        ),
        const SizedBox(height: 10),
        _NutrientTrendBar(
          nutrientKey: 'calories_kcal',
          label: s.calories,
          value: dailyAvg.calories,
          target: goals.calories,
          unit: s.unitKcal,
          color: MiqdarColors.caloriesAccent,
          onTap: () => _showNutrientDrillDown(
            context,
            'calories_kcal',
            s.calories,
            s.unitKcal,
            dailyAvg.calories,
            goals.calories,
            periodMeals,
            (m) => m.nutrients.calories,
          ),
        ),
        _NutrientTrendBar(
          nutrientKey: 'protein_g',
          label: s.protein,
          value: dailyAvg.protein,
          target: goals.protein,
          unit: s.unitG,
          color: MiqdarColors.proteinAccent,
          onTap: () => _showNutrientDrillDown(
            context,
            'protein_g',
            s.protein,
            s.unitG,
            dailyAvg.protein,
            goals.protein,
            periodMeals,
            (m) => m.nutrients.protein,
          ),
        ),
        _NutrientTrendBar(
          nutrientKey: 'carbohydrate_g',
          label: s.carbs,
          value: dailyAvg.carbohydrates,
          target: goals.carbohydrates,
          unit: s.unitG,
          color: MiqdarColors.carbsAccent,
          onTap: () => _showNutrientDrillDown(
            context,
            'carbohydrate_g',
            s.carbs,
            s.unitG,
            dailyAvg.carbohydrates,
            goals.carbohydrates,
            periodMeals,
            (m) => m.nutrients.carbohydrates,
          ),
        ),
        _NutrientTrendBar(
          nutrientKey: 'fat_g',
          label: s.fat,
          value: dailyAvg.fat,
          target: goals.fat,
          unit: s.unitG,
          color: MiqdarColors.fatAccent,
          onTap: () => _showNutrientDrillDown(
            context,
            'fat_g',
            s.fat,
            s.unitG,
            dailyAvg.fat,
            goals.fat,
            periodMeals,
            (m) => m.nutrients.fat,
          ),
        ),
        _NutrientTrendBar(
          nutrientKey: 'sugar_g',
          label: s.sugar,
          value: dailyAvg.sugar,
          target: goals.sugar,
          unit: s.unitG,
          color: MiqdarColors.sugarAccent,
          onTap: () => _showNutrientDrillDown(
            context,
            'sugar_g',
            s.sugar,
            s.unitG,
            dailyAvg.sugar,
            goals.sugar,
            periodMeals,
            (m) => m.nutrients.sugar,
          ),
        ),
        _NutrientTrendBar(
          nutrientKey: 'sodium_mg',
          label: s.sodium,
          value: dailyAvg.sodium,
          target: goals.sodium,
          unit: s.unitMg,
          color: MiqdarColors.sodiumAccent,
          onTap: () => _showNutrientDrillDown(
            context,
            'sodium_mg',
            s.sodium,
            s.unitMg,
            dailyAvg.sodium,
            goals.sodium,
            periodMeals,
            (m) => m.nutrients.sodium,
          ),
        ),
        _NutrientTrendBar(
          nutrientKey: 'potassium_mg',
          label: s.potassium,
          value: dailyAvg.potassium,
          target: goals.potassium,
          unit: s.unitMg,
          color: MiqdarColors.potassiumAccent,
          onTap: () => _showNutrientDrillDown(
            context,
            'potassium_mg',
            s.potassium,
            s.unitMg,
            dailyAvg.potassium,
            goals.potassium,
            periodMeals,
            (m) => m.nutrients.potassium,
          ),
        ),
        _NutrientTrendBar(
          nutrientKey: 'fiber_g',
          label: s.fiber,
          value: dailyAvg.fiber,
          target: goals.fiber,
          unit: s.unitG,
          color: MiqdarColors.fiberAccent,
          onTap: () => _showNutrientDrillDown(
            context,
            'fiber_g',
            s.fiber,
            s.unitG,
            dailyAvg.fiber,
            goals.fiber,
            periodMeals,
            (m) => m.nutrients.fiber,
          ),
        ),
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
    String key,
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
                '$label • ${s.tr("Nutrient Detail", "تفاصيل العنصر الغذائي")}',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                '${s.tr("Daily Average", "المتوسط اليومي")}: ${dailyAvg.toStringAsFixed(1)} $unit • ${s.tr("Configured Target", "الهدف المحدد")}: ${target.toStringAsFixed(0)} $unit',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Text(
                s.tr('Top Contributing Meals in Period', 'أعلى الوجبات مساهمة في هذه الفترة'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              const SizedBox(height: 8),
              ...topContributors.map(
                (m) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    m.displayName(s.isAr),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${DateFormat('d MMM').format(m.eatenAt.toLocal())} • ${m.weightG.toStringAsFixed(0)} ${s.unitG}',
                  ),
                  trailing: Text(
                    '${selector(m).toStringAsFixed(1)} $unit',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
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

  void _showExportSheet(BuildContext context, int days) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final csv = controller.exportMealsCsv(days: days);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.tr('Export Portable Nutrition Data', 'تصدير البيانات الغذائية'),
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                s.tr(
                  'CSV includes Unicode Arabic names, portion provenance, verification status, and formula-injection sanitization.',
                  'يشمل ملف CSV الأسماء العربية ومصدر الوزن وحالة التوثيق مع حماية كاملة ضد حقن المعادلات.',
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              Container(
                height: 150,
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    csv,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
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
                      content: Text(
                        s.tr(
                          'CSV data copied to clipboard!',
                          'تم نسخ بيانات CSV إلى الحافظة بنجاح!',
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded),
                label: Text(s.tr('Copy CSV to Clipboard', 'نسخ CSV إلى الحافظة')),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? MiqdarColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
        boxShadow: MiqdarColors.ambientShadow(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? MiqdarColors.darkMuted : MiqdarColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(detail, style: const TextStyle(fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _NutrientTrendBar extends StatelessWidget {
  const _NutrientTrendBar({
    required this.nutrientKey,
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
    required this.color,
    required this.onTap,
  });

  final String nutrientKey;
  final String label;
  final double value;
  final double target;
  final String unit;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ratio = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        padding: const EdgeInsets.all(16),
        onTap: onTap,
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
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${value.toStringAsFixed(value >= 100 ? 0 : 1)} / ${target.toStringAsFixed(0)} $unit',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, size: 18, color: MiqdarColors.muted),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 9,
                backgroundColor: color.withValues(alpha: 0.14),
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${s.tr("Of daily target", "من الهدف اليومي")}: ${(ratio * 100).round()}%',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// Goals & Nutrient Targets Configuration Screen (S35, GOAL-01–GOAL-05).
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  NutritionGoals? draft;

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    draft ??= controller.goals;

    return Scaffold(
      appBar: AppBar(title: Text(s.tr('Goals & Nutrient Targets', 'الأهداف والحدود الغذائية'))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                SurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.tr(
                          'User-controlled targets & notice rules',
                          'أهداف وحدود مخصصة بإدارة المستخدم',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.tr(
                          'Configure targets, maximum limits, or minimums using keyboard input, steppers, or sliders. Enable "Track without goals" to disable all threshold notices.',
                          'اضبط الأهداف أو الحدود القصوى أو الدنيا عبر الإدخال الرقمي أو الأزرار أو شريط التمرير. يمكنك تفعيل "التتبع فقط" لإيقاف جميع التنبيهات.',
                        ),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          s.tr('Track without goals (Disable threshold notices)', 'التتبع بدون أهداف (إيقاف التنبيهات)'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        value: draft!.trackingOnly,
                        onChanged: (v) => setState(() => draft = draft!.copyWith(trackingOnly: v)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (!draft!.trackingOnly) ...[
                  _GoalNumericEditorCard(
                    label: s.calories,
                    value: draft!.calories,
                    min: 800,
                    max: 4500,
                    step: 50,
                    unit: s.unitKcal,
                    goalTypeLabel: GoalType.target.label(s.isAr),
                    onChanged: (v) => setState(() => draft = draft!.copyWith(calories: v)),
                  ),
                  _GoalNumericEditorCard(
                    label: s.protein,
                    value: draft!.protein,
                    min: 20,
                    max: 300,
                    step: 5,
                    unit: s.unitG,
                    goalTypeLabel: GoalType.minimum.label(s.isAr),
                    onChanged: (v) => setState(() => draft = draft!.copyWith(protein: v)),
                  ),
                  _GoalNumericEditorCard(
                    label: s.carbs,
                    value: draft!.carbohydrates,
                    min: 30,
                    max: 500,
                    step: 10,
                    unit: s.unitG,
                    goalTypeLabel: GoalType.target.label(s.isAr),
                    onChanged: (v) => setState(() => draft = draft!.copyWith(carbohydrates: v)),
                  ),
                  _GoalNumericEditorCard(
                    label: s.fat,
                    value: draft!.fat,
                    min: 20,
                    max: 200,
                    step: 5,
                    unit: s.unitG,
                    goalTypeLabel: GoalType.target.label(s.isAr),
                    onChanged: (v) => setState(() => draft = draft!.copyWith(fat: v)),
                  ),
                  _GoalNumericEditorCard(
                    label: s.sugar,
                    value: draft!.sugar,
                    min: 5,
                    max: 150,
                    step: 5,
                    unit: s.unitG,
                    goalTypeLabel: GoalType.maximum.label(s.isAr),
                    onChanged: (v) => setState(() => draft = draft!.copyWith(sugar: v)),
                  ),
                  _GoalNumericEditorCard(
                    label: s.sodium,
                    value: draft!.sodium,
                    min: 400,
                    max: 5000,
                    step: 100,
                    unit: s.unitMg,
                    goalTypeLabel: GoalType.maximum.label(s.isAr),
                    onChanged: (v) => setState(() => draft = draft!.copyWith(sodium: v)),
                  ),
                  _GoalNumericEditorCard(
                    label: s.potassium,
                    value: draft!.potassium,
                    min: 1000,
                    max: 6000,
                    step: 100,
                    unit: s.unitMg,
                    goalTypeLabel: GoalType.target.label(s.isAr),
                    onChanged: (v) => setState(() => draft = draft!.copyWith(potassium: v)),
                  ),
                  _GoalNumericEditorCard(
                    label: s.fiber,
                    value: draft!.fiber,
                    min: 10,
                    max: 70,
                    step: 2,
                    unit: s.unitG,
                    goalTypeLabel: GoalType.minimum.label(s.isAr),
                    onChanged: (v) => setState(() => draft = draft!.copyWith(fiber: v)),
                  ),
                ],

                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () async {
                    await controller.updateGoals(draft!);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: Text(s.tr('Save Targets & Thresholds', 'حفظ الأهداف والحدود')),
                ),
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
    required this.goalTypeLabel,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final String unit;
  final String goalTypeLabel;
  final ValueChanged<double> onChanged;

  @override
  State<_GoalNumericEditorCard> createState() => _GoalNumericEditorCardState();
}

class _GoalNumericEditorCardState extends State<_GoalNumericEditorCard> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.value.toStringAsFixed(0),
  );

  @override
  void didUpdateWidget(covariant _GoalNumericEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.value - widget.value).abs() >= 1) {
      _ctrl.text = widget.value.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _update(double v) {
    final clamped = v.clamp(widget.min, widget.max).toDouble();
    _ctrl.text = clamped.toStringAsFixed(0);
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                        Text(
                          widget.goalTypeLabel,
                          style: const TextStyle(fontSize: 11.5, color: MiqdarColors.primary),
                        ),
                      ],
                    ),
                  ),
                  IconButton.outlined(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _update(widget.value - widget.step),
                    icon: const Icon(Icons.remove_rounded, size: 16),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 96,
                    child: TextField(
                      controller: _ctrl,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: MiqdarColors.primary,
                      ),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        suffixText: widget.unit,
                      ),
                      onSubmitted: (raw) {
                        final parsed = double.tryParse(normalizeDigits(raw).trim());
                        if (parsed != null) _update(parsed);
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.outlined(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _update(widget.value + widget.step),
                    icon: const Icon(Icons.add_rounded, size: 16),
                  ),
                ],
              ),
              Slider(
                value: widget.value.clamp(widget.min, widget.max).toDouble(),
                min: widget.min,
                max: widget.max,
                divisions: ((widget.max - widget.min) / widget.step).round().clamp(1, 200),
                onChanged: _update,
              ),
            ],
          ),
        ),
      );
}

/// Inbox & Nutrient Notices Screen (S37, S38, PRD-07).
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.tr('Nutrient Notices & Inbox', 'صندوق التنبيهات الغذائية'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    s.tr(
                      'Calm, neutral comparisons with your configured targets (S37, PRD-07).',
                      'مقارنات إرشادية هادئة ومحايدة مع الأهداف الغذائية المحددة (S37, PRD-07).',
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            if (controller.unreadAlertsCount > 0)
              TextButton.icon(
                onPressed: controller.markAllAlertsRead,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: Text(s.tr('Mark read', 'تحديد كمقروء')),
              ),
            IconButton.filledTonal(
              tooltip: s.tr('Configure limits', 'تعديل الحدود'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GoalsScreen()),
              ),
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),

        SurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded, color: MiqdarColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${s.tr("Last notice evaluation", "آخر تقييم للتنبيهات")}: ${controller.alertEvaluationMs} ms',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: MiqdarColors.softGreen,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text(
                  'SLO ≤ 4,000 ms',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: MiqdarColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (controller.alerts.isEmpty)
          SurfaceCard(
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: MiqdarColors.primary, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.tr('No active nutrient notices', 'لا توجد تنبيهات غذائية نشطة'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      Text(
                        s.tr(
                          'Recorded intake is within your configured thresholds based on available data.',
                          'الاستهلاك المسجل ضمن الحدود المحددة بناءً على البيانات المتاحة.',
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
