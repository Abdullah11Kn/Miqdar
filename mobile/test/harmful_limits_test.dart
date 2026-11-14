import 'package:flutter_test/flutter_test.dart';
import 'package:miqdar_mobile/models/body_profile.dart';
import 'package:miqdar_mobile/models/nutrition.dart';
import 'package:miqdar_mobile/services/alert_service.dart';

NutritionValues food({
  double calories = 0,
  double carbs = 0,
  double sugar = 0,
  double protein = 0,
  double sodium = 0,
  double potassium = 0,
}) =>
    NutritionValues(
      calories: calories,
      protein: protein,
      carbohydrates: carbs,
      fat: 0,
      sugar: sugar,
      fiber: 0,
      sodium: sodium,
      potassium: potassium,
    );

const goals = NutritionGoals(
  calories: 2000,
  sugar: 50,
  sodium: 2300,
  potassium: 3500,
  carbohydrates: 250,
  protein: 100,
);

const diabetic = AlertContext(hasDiabetes: true, mealCarbLimitG: 60, dayCarbLimitG: 200);

Set<String> keysFor(NutritionValues today, NutritionValues meal, {AlertContext context = const AlertContext()}) =>
    AlertService()
        .evaluate(currentTotals: today, incoming: meal, goals: goals, context: context)
        .alerts
        .map((a) => a.nutrientKey)
        .toSet();

void main() {
  group('people with diabetes are warned as soon as a limit is passed', () {
    test('sugar just past the limit', () {
      expect(keysFor(food(sugar: 40), food(sugar: 12), context: diabetic), contains('sugar_g'));
    });

    test('a meal over its own carb number, even on a light day', () {
      expect(keysFor(food(), food(carbs: 70), context: diabetic), contains(mealCarbsKey));
    });

    test('a meal within its carb number gives no meal carb warning', () {
      expect(keysFor(food(), food(carbs: 55), context: diabetic), isNot(contains(mealCarbsKey)));
    });

    test('the day passing its carb limit', () {
      expect(keysFor(food(carbs: 180), food(carbs: 30), context: diabetic), contains('carbohydrate_g'));
    });

    test('no meal carb warning without a carb number', () {
      const noPlan = AlertContext(hasDiabetes: true);
      expect(keysFor(food(), food(carbs: 120), context: noPlan), isNot(contains(mealCarbsKey)));
    });
  });

  group('people without diabetes are warned only far past a limit', () {
    test('30% past the sugar limit: no warning', () {
      expect(keysFor(food(sugar: 50), food(sugar: 15)), isEmpty);
    });

    test('more than 40% past the sugar limit: warning', () {
      expect(keysFor(food(sugar: 50), food(sugar: 21)), contains('sugar_g'));
    });

    test('carbs never warn without diabetes', () {
      expect(keysFor(food(carbs: 300), food(carbs: 200)), isNot(contains('carbohydrate_g')));
    });

    test('calories far past the goal warn', () {
      expect(keysFor(food(calories: 2000), food(calories: 900)), contains('calories_kcal'));
    });
  });

  test('calories never warn when the goal is to gain weight', () {
    const gaining = AlertContext(weightGoal: WeightGoal.gain);
    expect(keysFor(food(calories: 2000), food(calories: 1500), context: gaining), isEmpty);
  });

  test('protein, sodium and potassium never warn', () {
    final keys = keysFor(food(), food(protein: 400, sodium: 9000, potassium: 9000), context: diabetic);
    expect(keys, isEmpty);
  });

  test('tracking-only mode never warns', () {
    final result = AlertService().evaluate(
      currentTotals: food(sugar: 100),
      incoming: food(sugar: 100, calories: 5000),
      goals: goals.copyWith(trackingOnly: true),
      context: diabetic,
    );
    expect(result.alerts, isEmpty);
  });

  test('the warning reads as agreed, in both languages, and says it is an estimate', () {
    final alert = AlertService()
        .evaluate(currentTotals: food(sugar: 40), incoming: food(sugar: 22), goals: goals, context: diabetic)
        .alerts
        .single;
    expect(alert.message, contains('62 of 50 g'));
    expect(alert.message, contains('Estimate'));
    expect(alert.messageAr, contains('62 من 50 غ'));
    expect(alert.messageAr, contains('تقدير'));
  });

  group('red bars on Home', () {
    test('sugar past its limit is red for everyone, at any amount', () {
      expect(passesHarmfulLimit('sugar_g', 51, 50, goals: goals), isTrue);
    });

    test('protein past its goal is never red', () {
      expect(passesHarmfulLimit('protein_g', 300, 100, goals: goals), isFalse);
    });

    test('carbs are red only with diabetes', () {
      expect(passesHarmfulLimit('carbohydrate_g', 300, 250, goals: goals), isFalse);
      expect(passesHarmfulLimit('carbohydrate_g', 300, 250, goals: goals, context: diabetic), isTrue);
    });

    test('calories are not red when gaining weight', () {
      const gaining = AlertContext(weightGoal: WeightGoal.gain);
      expect(passesHarmfulLimit('calories_kcal', 2500, 2000, goals: goals, context: gaining), isFalse);
      expect(passesHarmfulLimit('calories_kcal', 2500, 2000, goals: goals), isTrue);
    });

    test('nothing is red in tracking-only mode', () {
      expect(passesHarmfulLimit('sugar_g', 90, 50, goals: goals.copyWith(trackingOnly: true)), isFalse);
    });
  });

  group('the smaller portion', () {
    HealthAlert warn(NutritionValues today, NutritionValues meal, double? grams, {AlertContext context = diabetic}) =>
        AlertService()
            .evaluate(currentTotals: today, incoming: meal, goals: goals, context: context, incomingWeightG: grams)
            .alerts
            .first;

    test('says how many grams keep the day within the limit', () {
      // 40 g so far, limit 50 g: 10 g of room. This 200 g meal has 22 g of sugar, 0.11 g a gram: 90 g fits.
      final alert = warn(food(sugar: 40), food(sugar: 22), 200);
      expect(alert.message, contains('about 90 g keeps you within it'));
      expect(alert.messageAr, contains('نحو 90 غ تبقيك ضمن الحد'));
    });

    test('uses the tightest limit when several are passed', () {
      // Sugar allows 90 g (as above); the meal carb number of 60 g allows 60 / (120 / 200) = 100 g.
      final alerts = AlertService()
          .evaluate(
            currentTotals: food(sugar: 40),
            incoming: food(sugar: 22, carbs: 120),
            goals: goals,
            context: diabetic,
            incomingWeightG: 200,
          )
          .alerts;
      expect(alerts.length, 2);
      for (final a in alerts) {
        expect(a.message, contains('about 90 g keeps you within your limits'));
      }
    });

    test('offers no grams when the weight is only an estimate', () {
      final alert = warn(food(sugar: 40), food(sugar: 22), null);
      expect(alert.message, isNot(contains(' g keeps you')));
      expect(alert.message, contains('try a smaller portion'));
    });

    test('offers no grams when the day is already past the limit', () {
      final alert = warn(food(sugar: 60), food(sugar: 10), 100);
      expect(alert.message, isNot(contains(' g keeps you')));
    });
  });
}
