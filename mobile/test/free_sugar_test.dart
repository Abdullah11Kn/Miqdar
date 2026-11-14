import 'package:flutter_test/flutter_test.dart';
import 'package:miqdar_mobile/models/nutrition.dart';
import 'package:miqdar_mobile/services/alert_service.dart';

Map<String, dynamic> _row({double sugar = 20, double? freeSugar}) => {
      'calories_kcal': 100.0,
      'protein_g': 1.0,
      'carbohydrate_g': 25.0,
      'fat_g': 0.0,
      'sugar_g': sugar,
      'fiber_g': 2.0,
      'sodium_mg': 1.0,
      'potassium_mg': 100.0,
      if (freeSugar != null) 'free_sugar_g': freeSugar,
    };

const _goals = NutritionGoals(calories: 2000, sugar: 50, sodium: 2300, potassium: 3500, carbohydrates: 250, protein: 100);

void main() {
  test('free sugar is read when given', () {
    final values = NutritionValues.fromJson(_row(sugar: 20, freeSugar: 12));
    expect(values.freeSugar, 12);
    expect(values.sugarForLimit, 12);
    expect(values.countsTotalSugar, isFalse);
  });

  test('a meal saved before free sugar existed counts its total sugar, and says so', () {
    final values = NutritionValues.fromJson(_row(sugar: 20));
    expect(values.freeSugar, isNull);
    expect(values.sugarForLimit, 20);
    expect(values.countsTotalSugar, isTrue);
    expect(values.isMissing('sugar_g'), isFalse);
  });

  test('a day adds free sugar, using total sugar for meals that have none', () {
    final day = NutritionValues.fromJson(_row(sugar: 20, freeSugar: 5)) + NutritionValues.fromJson(_row(sugar: 30));
    expect(day.sugar, 50);
    expect(day.sugarForLimit, 35);
    expect(day.countsTotalSugar, isTrue);
  });

  test('scaling a portion scales free sugar', () {
    expect(NutritionValues.fromJson(_row(freeSugar: 10)).scaledBy(2).freeSugar, 20);
  });

  test('free sugar is stored with the meal', () {
    expect(NutritionValues.fromJson(_row(freeSugar: 7)).toDatabase()['free_sugar_g'], 7);
    expect(NutritionValues.fromJson(_row()).toDatabase().containsKey('free_sugar_g'), isFalse);
  });

  test('fruit with lots of natural sugar does not set off the sugar warning', () {
    final dates = NutritionValues.fromJson(_row(sugar: 63, freeSugar: 0)).scaledBy(1.5);
    final alerts = AlertService()
        .evaluate(
          currentTotals: NutritionValues.zero(),
          incoming: dates,
          goals: _goals,
          context: const AlertContext(hasDiabetes: true),
        )
        .alerts;
    expect(alerts.where((a) => a.nutrientKey == 'sugar_g'), isEmpty);
  });

  test('a sweet drink does, and the warning names free sugar', () {
    final soda = NutritionValues.fromJson(_row(sugar: 11, freeSugar: 11)).scaledBy(5);
    final alert = AlertService()
        .evaluate(
          currentTotals: NutritionValues.zero(),
          incoming: soda,
          goals: _goals,
          context: const AlertContext(hasDiabetes: true),
        )
        .alerts
        .single;
    expect(alert.message, contains("today's free sugar to 55 of 50 g"));
    expect(alert.messageAr, contains('الوجبة ترفع حد السكر اليومي إلى 55 من 50 غ'));
  });
}
