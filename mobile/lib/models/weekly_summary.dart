import '../services/alert_service.dart';
import 'body_profile.dart';
import 'nutrition.dart';
import 'water.dart';

/// One page about the last 7 diary days, to share with a dietitian or family. Plain numbers only.
class WeeklySummary {
  const WeeklySummary({
    required this.from,
    required this.to,
    required this.loggedDays,
    required this.average,
    required this.daysOverSugar,
    required this.daysOverCalories,
    required this.daysOverCarbs,
    required this.averageWaterMl,
    required this.waterGoalMl,
    required this.topFoods,
    this.weightStart,
    this.weightEnd,
  });

  final DateTime from;
  final DateTime to;
  final int loggedDays;

  /// Daily average over logged days.
  final NutritionValues average;
  final int daysOverSugar;
  final int daysOverCalories;

  /// Diabetes mode only; null otherwise.
  final int? daysOverCarbs;

  /// Average over the days any water was logged; null when none was.
  final double? averageWaterMl;
  final double waterGoalMl;
  final List<({String name, int count})> topFoods;
  final BodyWeightEntry? weightStart;
  final BodyWeightEntry? weightEnd;

  double get averageCalories => average.calories;
  bool get isEmpty => loggedDays == 0;
}

WeeklySummary buildWeeklySummary({
  required List<MealEntry> meals,
  required List<WaterEntry> water,
  required List<BodyWeightEntry> weights,
  required NutritionGoals limits,
  required AlertContext context,
  required double waterGoalMl,
  required DateTime today,
  required DateTime Function(DateTime) dayOf,
}) {
  final to = DateTime(today.year, today.month, today.day);
  final from = DateTime(to.year, to.month, to.day - 6);
  bool inWeek(DateTime d) => !d.isBefore(from) && !d.isAfter(to);

  final byDay = <DateTime, NutritionValues>{};
  final counts = <String, int>{};
  for (final meal in meals) {
    final d = dayOf(meal.eatenAt);
    if (!inWeek(d)) continue;
    byDay[d] = (byDay[d] ?? NutritionValues.zero()) + meal.nutrients;
    counts[meal.nameEn] = (counts[meal.nameEn] ?? 0) + 1;
  }
  final days = byDay.values.toList();
  final total = days.fold(NutritionValues.zero(), (sum, v) => sum + v);
  final average = days.isEmpty ? NutritionValues.zero() : total.scaledBy(1 / days.length);

  int over(String key, double Function(NutritionValues) read, double limit) =>
      days.where((v) => passesHarmfulLimit(key, read(v), limit, goals: limits, context: context)).length;

  final waterByDay = <DateTime, double>{};
  for (final w in water) {
    final d = dayOf(w.at);
    if (inWeek(d)) waterByDay[d] = (waterByDay[d] ?? 0) + w.ml;
  }

  final top = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final inWeekWeights = weights.where((w) => inWeek(DateTime(w.measuredOn.year, w.measuredOn.month, w.measuredOn.day))).toList()
    ..sort((a, b) => a.measuredOn.compareTo(b.measuredOn));

  return WeeklySummary(
    from: from,
    to: to,
    loggedDays: days.length,
    average: average,
    daysOverSugar: over('sugar_g', (v) => v.sugarForLimit, limits.sugar),
    daysOverCalories: over('calories_kcal', (v) => v.calories, limits.calories),
    daysOverCarbs: context.hasDiabetes
        ? over('carbohydrate_g', (v) => v.carbohydrates, context.dayCarbLimitG ?? limits.carbohydrates)
        : null,
    averageWaterMl: waterByDay.isEmpty ? null : waterByDay.values.reduce((a, b) => a + b) / waterByDay.length,
    waterGoalMl: waterGoalMl,
    topFoods: [for (final e in top.take(5)) (name: e.key, count: e.value)],
    weightStart: inWeekWeights.firstOrNull,
    weightEnd: inWeekWeights.length > 1 ? inWeekWeights.last : null,
  );
}
