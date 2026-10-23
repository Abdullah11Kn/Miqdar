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
    if (goals.trackingOnly) {
      watch.stop();
      return AlertEvaluation(const [], watch.elapsedMilliseconds);
    }

    final projected = currentTotals + incoming;
    final alerts = <HealthAlert>[];

    void addIfExceeded(
      String key,
      String labelEn,
      String labelAr,
      String unitEn,
      String unitAr,
      double value,
      double threshold,
    ) {
      final type = goals.typeFor(key);
      if (type == GoalType.trackOnly || type == GoalType.minimum) return;
      if (threshold <= 0 || value <= threshold) return;

      final incompleteSuffixEn = projected.isMissing(key)
          ? ' (Known subtotal — 1 or more items have unreported $labelEn).'
          : '';
      final incompleteSuffixAr = projected.isMissing(key)
          ? ' (مجموع جزئي معروف — بعض العناصر غير مكتملة البيانات).'
          : '';

      final ratio = value / threshold;
      alerts.add(HealthAlert(
        id: 'alert-${DateTime.now().microsecondsSinceEpoch}-$key',
        nutrientKey: key,
        severity: ratio >= 1.25 ? 'critical' : 'warning',
        currentValue: value,
        thresholdValue: threshold,
        message:
            'Recorded ${labelEn.toLowerCase()} would reach ${value.toStringAsFixed(0)} $unitEn, above your configured ${threshold.toStringAsFixed(0)} $unitEn daily limit. Review the meal or adjust your target.$incompleteSuffixEn',
        messageAr:
            'إجمالي $labelAr المسجل سيصل إلى ${value.toStringAsFixed(0)} $unitAr، وهو أعلى من الحد اليومي المحدد (${threshold.toStringAsFixed(0)} $unitAr). يمكنك مراجعة الوجبة أو تعديل الهدف.$incompleteSuffixAr',
        createdAt: DateTime.now().toUtc(),
        evaluationMs: 0,
      ));
    }

    addIfExceeded('calories_kcal', 'Calories', 'السعرات الحرارية', 'kcal', 'سعرة', projected.calories, goals.calories);
    addIfExceeded('sugar_g', 'Sugar', 'السكريات', 'g', 'غ', projected.sugar, goals.sugar);
    addIfExceeded('sodium_mg', 'Sodium', 'الصوديوم', 'mg', 'ملغ', projected.sodium, goals.sodium);
    addIfExceeded('potassium_mg', 'Potassium', 'البوتاسيوم', 'mg', 'ملغ', projected.potassium, goals.potassium);
    addIfExceeded('carbohydrate_g', 'Carbohydrates', 'الكربوهيدرات', 'g', 'غ', projected.carbohydrates, goals.carbohydrates);

    watch.stop();
    final elapsed = watch.elapsedMilliseconds;
    return AlertEvaluation(
      alerts
          .map((item) => HealthAlert(
                id: item.id,
                nutrientKey: item.nutrientKey,
                severity: item.severity,
                currentValue: item.currentValue,
                thresholdValue: item.thresholdValue,
                message: item.message,
                messageAr: item.messageAr,
                createdAt: item.createdAt,
                evaluationMs: elapsed,
              ))
          .toList(),
      elapsed,
    );
  }
}
