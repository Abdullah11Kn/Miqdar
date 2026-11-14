import 'body_profile.dart';
import 'nutrition.dart';

/// A calorie goal worked out from what the user really ate and how their weight moved.
/// Only ever offered: nothing changes unless the user accepts it.
class AdaptiveGoal {
  const AdaptiveGoal({
    required this.dailyBurnKcal,
    required this.suggestedKcal,
    required this.loggedDays,
    required this.weightChangeKg,
    required this.averageIntakeKcal,
  });

  /// Energy the body used a day: average intake less what went into or came out of body weight.
  final double dailyBurnKcal;
  final double suggestedKcal;
  final int loggedDays;

  /// Over the window, from the weight trend line.
  final double weightChangeKg;
  final double averageIntakeKcal;
}

/// Energy in one kilogram of body weight change, the usual figure.
const kcalPerKg = 7700.0;

/// Looks at the 21 diary days before today. Needs meals on at least 10 days spread over at least
/// 14, and at least 3 weight entries. Null when there is too little data, or when the suggestion is
/// within 100 kcal of [currentGoalKcal].
AdaptiveGoal? suggestAdaptiveGoal({
  required List<MealEntry> meals,
  required List<BodyWeightEntry> weights,
  required DateTime today,
  required DateTime Function(DateTime) dayOf,
  required WeightGoal goal,
  required double? weeklyPaceKg,
  required BodySex sex,
  required double currentGoalKcal,
}) {
  final end = DateTime(today.year, today.month, today.day);
  final start = DateTime(end.year, end.month, end.day - 21);
  final intake = <DateTime, double>{};
  for (final meal in meals) {
    final d = dayOf(meal.eatenAt);
    if (d.isBefore(start) || !d.isBefore(end)) continue; // today is not over yet
    intake[d] = (intake[d] ?? 0) + meal.nutrients.calories;
  }
  if (intake.length < 10) return null;
  final earliest = intake.keys.reduce((a, b) => a.isBefore(b) ? a : b);
  if (end.difference(earliest).inDays < 14) return null;

  final points = weights.where((w) {
    final d = DateTime(w.measuredOn.year, w.measuredOn.month, w.measuredOn.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }).toList();
  if (points.length < 3) return null;

  // Least-squares slope of weight against days, so one odd weigh-in does not swing the answer.
  final xs = [for (final w in points) w.measuredOn.difference(start).inHours / 24.0];
  final ys = [for (final w in points) w.weightKg];
  final mx = xs.reduce((a, b) => a + b) / xs.length;
  final my = ys.reduce((a, b) => a + b) / ys.length;
  var num = 0.0, den = 0.0;
  for (var i = 0; i < xs.length; i++) {
    num += (xs[i] - mx) * (ys[i] - my);
    den += (xs[i] - mx) * (xs[i] - mx);
  }
  if (den == 0) return null;
  final kgPerDay = num / den;

  final averageIntake = intake.values.reduce((a, b) => a + b) / intake.length;
  final burn = averageIntake - kgPerDay * kcalPerKg;
  final pace = (weeklyPaceKg ?? 0).clamp(0.0, BodyProfile.maxWeeklyPaceKg);
  final change = switch (goal) {
    WeightGoal.lose => -pace * kcalPerKg / 7,
    WeightGoal.gain => pace * kcalPerKg / 7,
    WeightGoal.maintain => 0.0,
  };
  final minimum = sex == BodySex.female ? 1200.0 : 1500.0;
  final suggested = (((burn + change).clamp(minimum, 4500.0)) / 50).round() * 50.0;
  if ((suggested - currentGoalKcal).abs() < 100) return null;
  final span = xs.reduce((a, b) => a > b ? a : b) - xs.reduce((a, b) => a < b ? a : b);
  return AdaptiveGoal(
    dailyBurnKcal: burn,
    suggestedKcal: suggested,
    loggedDays: intake.length,
    weightChangeKg: kgPerDay * span,
    averageIntakeKcal: averageIntake,
  );
}
