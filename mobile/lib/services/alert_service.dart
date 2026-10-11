import '../models/nutrition.dart';

class AlertEvaluation {
  const AlertEvaluation(this.alerts, this.elapsedMs);
  final List<HealthAlert> alerts;
  final int elapsedMs;
}

class AlertService {
  AlertEvaluation evaluate({
    required NutritionValues currentTotals,
    required NutritionValues incoming,
    required NutritionGoals goals,
  }) {
    final watch = Stopwatch()..start();
    final projected = currentTotals + incoming;
    final alerts = <HealthAlert>[];

    void addIfExceeded(String key, String label, double value, double threshold) {
      if (value <= threshold) return;
      final ratio = threshold == 0 ? 99 : value / threshold;
      alerts.add(HealthAlert(
        id: 'alert-${DateTime.now().microsecondsSinceEpoch}-$key',
        nutrientKey: key,
        severity: ratio >= 1.25 ? 'critical' : 'warning',
        currentValue: value,
        thresholdValue: threshold,
        message: '$label would reach ${value.toStringAsFixed(0)}, above your ${threshold.toStringAsFixed(0)} daily limit.',
        createdAt: DateTime.now().toUtc(),
        evaluationMs: 0,
      ));
    }

    addIfExceeded('calories_kcal', 'Calories', projected.calories, goals.calories);
    addIfExceeded('sugar_g', 'Sugar', projected.sugar, goals.sugar);
    addIfExceeded('sodium_mg', 'Sodium', projected.sodium, goals.sodium);
    addIfExceeded('potassium_mg', 'Potassium', projected.potassium, goals.potassium);
    addIfExceeded('carbohydrate_g', 'Carbohydrates', projected.carbohydrates, goals.carbohydrates);
    watch.stop();
    final elapsed = watch.elapsedMilliseconds;
    return AlertEvaluation(
      alerts.map((item) => HealthAlert(
        id: item.id,
        nutrientKey: item.nutrientKey,
        severity: item.severity,
        currentValue: item.currentValue,
        thresholdValue: item.thresholdValue,
        message: item.message,
        createdAt: item.createdAt,
        evaluationMs: elapsed,
      )).toList(),
      elapsed,
    );
  }
}
