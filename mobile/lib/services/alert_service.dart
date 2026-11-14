import '../models/body_profile.dart';
import '../models/nutrition.dart';

/// The alert key for one meal's carbohydrates passing its carb number (diabetes mode).
const mealCarbsKey = 'meal_carbohydrate_g';

/// Without diabetes, a warning appears only this far past a limit (Abdullah, 2026-11-14).
const _farPastRatio = 1.4;

/// What the alert check needs to know about the person, beyond their goals.
class AlertContext {
  const AlertContext({
    this.hasDiabetes = false,
    this.weightGoal,
    this.mealCarbLimitG,
    this.dayCarbLimitG,
  });

  final bool hasDiabetes;
  final WeightGoal? weightGoal;

  /// The carb number for the meal being reviewed, or null without a plan.
  final double? mealCarbLimitG;

  /// The daily carb limit in diabetes mode; the carbohydrate goal is used when null.
  final double? dayCarbLimitG;
}

class AlertEvaluation {
  const AlertEvaluation(this.alerts, this.elapsedMs);
  final List<HealthAlert> alerts;
  final int elapsedMs;
}

/// True when [key] is a limit that is harmful to pass for this person, and [value] passes [target].
/// Drives the red bars: free sugar and calories for everyone (not calories when gaining weight),
/// carbohydrates only in diabetes mode. Protein, fiber, fat, sodium and potassium are never red.
bool passesHarmfulLimit(
  String key,
  double value,
  double target, {
  required NutritionGoals goals,
  AlertContext context = const AlertContext(),
}) {
  if (!isHarmfulLimit(key, goals, context)) return false;
  return target > 0 && !value.isNaN && value > target;
}

/// True when [key] is a limit that is harmful to pass for this person (see [passesHarmfulLimit]).
bool isHarmfulLimit(String key, NutritionGoals goals, AlertContext context) {
  if (goals.trackingOnly) return false;
  final type = goals.typeFor(key);
  if (type == GoalType.trackOnly || type == GoalType.minimum) return false;
  return switch (key) {
    'sugar_g' => true,
    'calories_kcal' => context.weightGoal != WeightGoal.gain,
    'carbohydrate_g' => context.hasDiabetes,
    _ => false,
  };
}

bool _partial(NutritionValues values, String key) =>
    values.isMissing(key == mealCarbsKey ? 'carbohydrate_g' : key);

class AlertService {
  AlertEvaluation evaluate({
    required NutritionValues currentTotals,
    required NutritionValues incoming,
    required NutritionGoals goals,
    AlertContext context = const AlertContext(),

    /// The meal's weight, for the smaller-portion suggestion; null when it is only an estimate.
    double? incomingWeightG,
  }) {
    final watch = Stopwatch()..start();
    final projected = currentTotals + incoming;
    final now = DateTime.now();
    final pending = <({String key, double value, double limit, String en, String ar, double room, double inMeal})>[];

    bool warns(double value, double limit) {
      if (limit <= 0 || value.isNaN) return false;
      return context.hasDiabetes ? value > limit : value > limit * _farPastRatio;
    }

    String n(double v) => v.toStringAsFixed(0);

    if (isHarmfulLimit('sugar_g', goals, context) && warns(projected.sugar, goals.sugar)) {
      pending.add((
        key: 'sugar_g',
        value: projected.sugar,
        limit: goals.sugar,
        en: "Over your sugar limit. This meal brings today's sugar to ${n(projected.sugar)} of ${n(goals.sugar)} g.",
        ar: 'تجاوزت حدّ السكر. الوجبة ترفع حد السكر اليومي إلى ${n(projected.sugar)} من ${n(goals.sugar)} غ.',
        room: goals.sugar - currentTotals.sugar,
        inMeal: incoming.sugar,
      ));
    }

    if (isHarmfulLimit('calories_kcal', goals, context) && warns(projected.calories, goals.calories)) {
      pending.add((
        key: 'calories_kcal',
        value: projected.calories,
        limit: goals.calories,
        en: "Over your calorie goal. This meal brings today's calories to ${n(projected.calories)} of ${n(goals.calories)} kcal.",
        ar: 'تجاوزت هدف السعرات. الوجبة ترفع سعرات اليوم إلى ${n(projected.calories)} من ${n(goals.calories)} سعرة.',
        room: goals.calories - currentTotals.calories,
        inMeal: incoming.calories,
      ));
    }

    if (context.hasDiabetes) {
      final mealLimit = context.mealCarbLimitG;
      if (mealLimit != null && !goals.trackingOnly && warns(incoming.carbohydrates, mealLimit)) {
        pending.add((
          key: mealCarbsKey,
          value: incoming.carbohydrates,
          limit: mealLimit,
          en: 'Over your carbs for one meal. This meal has ${n(incoming.carbohydrates)} g of carbs; your number is ${n(mealLimit)} g.',
          ar: 'تجاوزت كربوهيدرات الوجبة الواحدة. في هذه الوجبة ${n(incoming.carbohydrates)} غ كربوهيدرات، وحدّك ${n(mealLimit)} غ.',
          room: mealLimit,
          inMeal: incoming.carbohydrates,
        ));
      }
      final dayLimit = context.dayCarbLimitG ?? goals.carbohydrates;
      if (isHarmfulLimit('carbohydrate_g', goals, context) && warns(projected.carbohydrates, dayLimit)) {
        pending.add((
          key: 'carbohydrate_g',
          value: projected.carbohydrates,
          limit: dayLimit,
          en: "Over your daily carb limit. This meal brings today's carbs to ${n(projected.carbohydrates)} of ${n(dayLimit)} g.",
          ar: 'تجاوزت حدّ الكربوهيدرات اليومي. الوجبة ترفع كربوهيدرات اليوم إلى ${n(projected.carbohydrates)} من ${n(dayLimit)} غ.',
          room: dayLimit - currentTotals.carbohydrates,
          inMeal: incoming.carbohydrates,
        ));
      }
    }

    // The grams of this meal that keep the user within every limit passed, rounded down to 5 g.
    // None when the weight is only an estimate, or when the day is already past a limit.
    int? portion;
    final grams = incomingWeightG;
    if (grams != null && grams > 0 && pending.isNotEmpty) {
      var fits = grams;
      for (final w in pending) {
        if (w.room <= 0 || w.inMeal <= 0) {
          fits = 0;
          break;
        }
        fits = fits < w.room / (w.inMeal / grams) ? fits : w.room / (w.inMeal / grams);
      }
      final rounded = (fits / 5).floor() * 5;
      if (rounded >= 5) portion = rounded;
    }
    final several = pending.length > 1;

    final alerts = <HealthAlert>[
      for (final w in pending)
        HealthAlert(
          id: 'alert-${now.microsecondsSinceEpoch}-${w.key}',
          nutrientKey: w.key,
          severity: w.value > w.limit * _farPastRatio ? 'critical' : 'warning',
          currentValue: w.value,
          thresholdValue: w.limit,
          message: '${w.en} To protect your health, try a smaller portion'
              '${portion == null ? '.' : ': about $portion g keeps you within ${several ? 'your limits' : 'it'}.'}'
              '${_partial(projected, w.key) ? ' Some foods have no value for this, so the total may be higher.' : ''}'
              ' Estimate.',
          messageAr: '${w.ar} حفاظًا على صحتك، جرّب كمية أصغر'
              '${portion == null ? '.' : ': نحو $portion غ تبقيك ضمن ${several ? 'حدودك' : 'الحد'}.'}'
              '${_partial(projected, w.key) ? ' بعض الأطعمة بلا قيمة لهذا، فقد يكون المجموع أعلى.' : ''}'
              ' تقدير.',
          createdAt: now.toUtc(),
          evaluationMs: 0,
        ),
    ];

    watch.stop();
    final elapsed = watch.elapsedMilliseconds;
    return AlertEvaluation(
      [
        for (final a in alerts)
          HealthAlert(
            id: a.id,
            nutrientKey: a.nutrientKey,
            severity: a.severity,
            currentValue: a.currentValue,
            thresholdValue: a.thresholdValue,
            message: a.message,
            messageAr: a.messageAr,
            createdAt: a.createdAt,
            evaluationMs: elapsed,
          ),
      ],
      elapsed,
    );
  }
}
