import 'body_profile.dart';
import 'diabetes.dart';
import 'nutrition.dart';

/// A day in the report. [totals] is null when nothing was logged, so it is never read as zero.
class ReportDay {
  const ReportDay({required this.day, required this.meals, this.totals});

  final DateTime day;
  final int meals;
  final NutritionValues? totals;

  bool get logged => totals != null;
}

/// How many logged days were within, over and under one goal. Sugar and salt are limits, so they
/// have no "under".
class GoalDays {
  const GoalDays({
    required this.key,
    required this.goal,
    required this.within,
    required this.over,
    required this.under,
    required this.isLimit,
  });

  final String key;
  final double goal;
  final int within;
  final int over;
  final int under;
  final bool isLimit;
}

enum ReportPatternKind { highestCarbMeal, daysOverSugar, daysOverSalt, weekendCalories, loggedDays }

/// One factual line, worked out from the numbers by a fixed rule, so it can be checked against the
/// daily tables.
class ReportPattern {
  const ReportPattern(this.kind, {this.mealType, this.count = 0, this.ofDays = 0, this.percent = 0});

  final ReportPatternKind kind;
  final String? mealType;
  final int count;
  final int ofDays;

  /// For weekend calories: how much higher (positive) or lower than weekdays, in percent.
  final int percent;
}

class DoctorReport {
  const DoctorReport({
    required this.from,
    required this.to,
    required this.name,
    required this.days,
    required this.dailyAverage,
    required this.carbsByMeal,
    required this.goalDays,
    required this.patterns,
    required this.weightStart,
    required this.weightEnd,
    required this.weighedMeals,
    required this.estimatedMeals,
    required this.enteredMeals,
    required this.leftoverMeals,
    required this.carbsFirst,
  });

  final DateTime from;
  final DateTime to;
  final String name;
  final List<ReportDay> days;
  final NutritionValues dailyAverage;
  final Map<String, double> carbsByMeal;

  /// Empty when the user tracks without goals.
  final List<GoalDays> goalDays;
  final List<ReportPattern> patterns;
  final BodyWeightEntry? weightStart;
  final BodyWeightEntry? weightEnd;
  final int weighedMeals;
  final int estimatedMeals;
  final int enteredMeals;
  final int leftoverMeals;

  /// Diabetes mode: the carbs section comes first.
  final bool carbsFirst;

  int get loggedDays => days.where((d) => d.logged).length;
  int get mealCount => weighedMeals + estimatedMeals + enteredMeals;
  bool get isEmpty => loggedDays == 0;
}

/// Builds the report for the [periodDays] diary days ending on [today]. Everything comes from the
/// user's own numbers; nothing is sent anywhere.
DoctorReport buildDoctorReport({
  required List<MealEntry> meals,
  required NutritionGoals goals,
  required List<BodyWeightEntry> weights,
  required DateTime today,
  required int periodDays,
  required DateTime Function(DateTime) dayOf,
  String name = '',
  bool carbsFirst = false,
}) {
  final to = DateTime(today.year, today.month, today.day);
  final from = DateTime(to.year, to.month, to.day - (periodDays - 1));
  final inPeriod = meals.where((m) {
    final d = dayOf(m.eatenAt);
    return !d.isBefore(from) && !d.isAfter(to);
  }).toList();

  final byDay = <DateTime, List<MealEntry>>{};
  for (final meal in inPeriod) {
    byDay.putIfAbsent(dayOf(meal.eatenAt), () => []).add(meal);
  }
  final days = [
    for (var i = 0; i < periodDays; i++)
      () {
        final day = DateTime(from.year, from.month, from.day + i);
        final list = byDay[day];
        return ReportDay(
          day: day,
          meals: list?.length ?? 0,
          totals: list?.fold<NutritionValues>(NutritionValues.zero(), (a, m) => a + m.nutrients),
        );
      }(),
  ];
  final logged = days.where((d) => d.logged).toList();
  final average = logged.isEmpty
      ? NutritionValues.zero()
      : logged.fold<NutritionValues>(NutritionValues.zero(), (a, d) => a + d.totals!).scaledBy(1 / logged.length);

  GoalDays goalDaysFor(String key, double goal, double Function(NutritionValues) read, {bool isLimit = false}) {
    var within = 0, over = 0, under = 0;
    for (final day in logged) {
      final value = read(day.totals!);
      if (isLimit) {
        value > goal ? over++ : within++;
      } else if (value > goal * 1.1) {
        over++;
      } else if (value < goal * 0.9) {
        under++;
      } else {
        within++;
      }
    }
    return GoalDays(key: key, goal: goal, within: within, over: over, under: under, isLimit: isLimit);
  }

  final goalDays = goals.trackingOnly || logged.isEmpty
      ? <GoalDays>[]
      : [
          goalDaysFor('calories', goals.calories, (v) => v.calories),
          goalDaysFor('carbohydrates', goals.carbohydrates, (v) => v.carbohydrates),
          goalDaysFor('sugar', goals.sugar, (v) => v.sugar, isLimit: true),
          goalDaysFor('sodium', goals.sodium, (v) => v.sodium, isLimit: true),
        ];

  final patterns = <ReportPattern>[
    if (logged.isNotEmpty) ReportPattern(ReportPatternKind.loggedDays, count: logged.length, ofDays: periodDays),
  ];

  // The meal that had the most carbs, on days with more than one meal type.
  final topMeal = <String, int>{};
  var comparedDays = 0;
  for (final entry in byDay.entries) {
    final carbsByType = <String, double>{};
    for (final meal in entry.value) {
      if (meal.nutrients.isMissing('carbohydrate_g')) continue;
      carbsByType[meal.mealType] = (carbsByType[meal.mealType] ?? 0) + meal.nutrients.carbohydrates;
    }
    if (carbsByType.length < 2) continue;
    comparedDays++;
    final top = carbsByType.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    topMeal[top] = (topMeal[top] ?? 0) + 1;
  }
  if (comparedDays >= 3) {
    final top = topMeal.entries.reduce((a, b) => b.value > a.value ? b : a);
    if (top.value * 2 > comparedDays) {
      patterns.add(ReportPattern(ReportPatternKind.highestCarbMeal,
          mealType: top.key, count: top.value, ofDays: comparedDays));
    }
  }
  if (!goals.trackingOnly) {
    final sugarDays = goalDays.where((g) => g.key == 'sugar').firstOrNull?.over ?? 0;
    final saltDays = goalDays.where((g) => g.key == 'sodium').firstOrNull?.over ?? 0;
    if (sugarDays > 0) {
      patterns.add(ReportPattern(ReportPatternKind.daysOverSugar, count: sugarDays, ofDays: logged.length));
    }
    if (saltDays > 0) {
      patterns.add(ReportPattern(ReportPatternKind.daysOverSalt, count: saltDays, ofDays: logged.length));
    }
  }
  // Friday and Saturday are the weekend in Saudi Arabia and the Gulf.
  bool weekend(DateTime d) => d.weekday == DateTime.friday || d.weekday == DateTime.saturday;
  final weekendDays = logged.where((d) => weekend(d.day)).toList();
  final weekDays = logged.where((d) => !weekend(d.day)).toList();
  if (weekendDays.length >= 2 && weekDays.length >= 3) {
    double avg(List<ReportDay> list) => list.fold(0.0, (a, d) => a + d.totals!.calories) / list.length;
    final weekdayAvg = avg(weekDays);
    if (weekdayAvg > 0) {
      final percent = ((avg(weekendDays) - weekdayAvg) / weekdayAvg * 100).round();
      if (percent.abs() >= 15) {
        patterns.add(ReportPattern(ReportPatternKind.weekendCalories, percent: percent));
      }
    }
  }

  final weightsInPeriod = weights.where((w) {
    final d = DateTime(w.measuredOn.year, w.measuredOn.month, w.measuredOn.day);
    return !d.isBefore(from) && !d.isAfter(to);
  }).toList()
    ..sort((a, b) => a.measuredOn.compareTo(b.measuredOn));

  return DoctorReport(
    from: from,
    to: to,
    name: name,
    days: days,
    dailyAverage: average,
    carbsByMeal: averageCarbsByMealType(inPeriod, dayOf),
    goalDays: goalDays,
    patterns: patterns,
    weightStart: weightsInPeriod.firstOrNull,
    weightEnd: weightsInPeriod.length > 1 ? weightsInPeriod.last : null,
    weighedMeals: inPeriod.where((m) => m.portionSource == PortionSource.scale).length,
    estimatedMeals: inPeriod.where((m) => m.portionSource == PortionSource.estimated).length,
    enteredMeals: inPeriod
        .where((m) => m.portionSource != PortionSource.scale && m.portionSource != PortionSource.estimated)
        .length,
    leftoverMeals: inPeriod.where((m) => m.leftover != null).length,
    carbsFirst: carbsFirst,
  );
}
