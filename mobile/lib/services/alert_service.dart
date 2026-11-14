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

class AlertService {
  AlertEvaluation evaluate({
    required NutritionValues currentTotals,
    required NutritionValues incoming,
    required NutritionGoals goals,
    AlertContext context = const AlertContext(),
  }) {
    final watch = Stopwatch()..start();
    final projected = currentTotals + incoming;
    final alerts = <HealthAlert>[];
    final now = DateTime.now();

    bool warns(double value, double limit) {
      if (limit <= 0 || value.isNaN) return false;
      return context.hasDiabetes ? value > limit : value > limit * _farPastRatio;
    }

    void add(String key, double value, double limit, ({String en, String ar}) text) {
      final partial = projected.isMissing(key == mealCarbsKey ? 'carbohydrate_g' : key);
      alerts.add(HealthAlert(
        id: 'alert-${now.microsecondsSinceEpoch}-$key',
        nutrientKey: key,
        severity: value > limit * _farPastRatio ? 'critical' : 'warning',
        currentValue: value,
        thresholdValue: limit,
        message: '${text.en} To protect your health, try a smaller portion.'
            '${partial ? ' Some foods have no value for this, so the total may be higher.' : ''} Estimate.',
        messageAr: '${text.ar} حفاظًا على صحتك، جرّب كمية أصغر.'
            '${partial ? ' بعض الأطعمة بلا قيمة لهذا، فقد يكون المجموع أعلى.' : ''} تقدير.',
        createdAt: now.toUtc(),
        evaluationMs: 0,
      ));
    }

    String n(double v) => v.toStringAsFixed(0);

    if (isHarmfulLimit('sugar_g', goals, context) && warns(projected.sugar, goals.sugar)) {
      add('sugar_g', projected.sugar, goals.sugar, (
        en: "Over your sugar limit. This meal brings today's sugar to ${n(projected.sugar)} of ${n(goals.sugar)} g.",
        ar: 'تجاوزت حدّ السكر. الوجبة ترفع حد السكر اليومي إلى ${n(projected.sugar)} من ${n(goals.sugar)} غ.',
      ));
    }

    if (isHarmfulLimit('calories_kcal', goals, context) && warns(projected.calories, goals.calories)) {
      add('calories_kcal', projected.calories, goals.calories, (
        en: "Over your calorie goal. This meal brings today's calories to ${n(projected.calories)} of ${n(goals.calories)} kcal.",
        ar: 'تجاوزت هدف السعرات. الوجبة ترفع سعرات اليوم إلى ${n(projected.calories)} من ${n(goals.calories)} سعرة.',
      ));
    }

    if (context.hasDiabetes) {
      final mealLimit = context.mealCarbLimitG;
      if (mealLimit != null && !goals.trackingOnly && warns(incoming.carbohydrates, mealLimit)) {
        add(mealCarbsKey, incoming.carbohydrates, mealLimit, (
          en: 'Over your carbs for one meal. This meal has ${n(incoming.carbohydrates)} g of carbs; your number is ${n(mealLimit)} g.',
          ar: 'تجاوزت كربوهيدرات الوجبة الواحدة. في هذه الوجبة ${n(incoming.carbohydrates)} غ كربوهيدرات، وحدّك ${n(mealLimit)} غ.',
        ));
      }
      final dayLimit = context.dayCarbLimitG ?? goals.carbohydrates;
      if (isHarmfulLimit('carbohydrate_g', goals, context) && warns(projected.carbohydrates, dayLimit)) {
        add('carbohydrate_g', projected.carbohydrates, dayLimit, (
          en: "Over your daily carb limit. This meal brings today's carbs to ${n(projected.carbohydrates)} of ${n(dayLimit)} g.",
          ar: 'تجاوزت حدّ الكربوهيدرات اليومي. الوجبة ترفع كربوهيدرات اليوم إلى ${n(projected.carbohydrates)} من ${n(dayLimit)} غ.',
        ));
      }
    }

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
