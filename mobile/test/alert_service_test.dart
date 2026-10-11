import 'package:flutter_test/flutter_test.dart';
import 'package:miqdar_mobile/models/nutrition.dart';
import 'package:miqdar_mobile/services/alert_service.dart';

void main() {
  test('health alert is evaluated within four seconds', () {
    final result = AlertService().evaluate(
      currentTotals: NutritionValues.zero(),
      incoming: const NutritionValues(
        calories: 277,
        protein: 1.81,
        carbohydrates: 74.97,
        fat: .15,
        sugar: 66.47,
        fiber: 6.7,
        sodium: 1,
        potassium: 696,
      ),
      goals: const NutritionGoals(
        calories: 2200,
        sugar: 5,
        sodium: 2300,
        potassium: 3500,
        carbohydrates: 275,
        protein: 120,
      ),
    );

    expect(result.alerts.any((alert) => alert.nutrientKey == 'sugar_g'), isTrue);
    expect(result.elapsedMs, lessThanOrEqualTo(4000));
  });
}
