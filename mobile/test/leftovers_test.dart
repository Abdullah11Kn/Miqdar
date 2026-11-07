import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miqdar_mobile/app_controller.dart';
import 'package:miqdar_mobile/data/local_database.dart';
import 'package:miqdar_mobile/models/nutrition.dart';
import 'package:miqdar_mobile/services/alert_service.dart';
import 'package:miqdar_mobile/services/api_service.dart';
import 'package:miqdar_mobile/services/gemini_service.dart';

NutritionValues _values(double kcal, {double carbs = 0}) => NutritionValues(
    calories: kcal, protein: 10, carbohydrates: carbs, fat: 5, sugar: 2, fiber: 1, sodium: 100, potassium: 50);

MealEntry _single({double weight = 200, double kcal = 400, DateTime? when}) => MealEntry(
      id: 'single',
      foodId: 'gemini-rice',
      nameEn: 'Rice',
      nameAr: 'رز',
      eatenAt: when ?? DateTime.now(),
      mealType: 'Lunch',
      weightG: weight,
      confidence: 0.9,
      nutrients: _values(kcal, carbs: 80),
    );

MealEntry _plate() => MealEntry(
      id: 'plate',
      foodId: 'plate',
      nameEn: 'Rice + Chicken',
      nameAr: '',
      eatenAt: DateTime.now(),
      mealType: 'Lunch',
      weightG: 300,
      confidence: 0.9,
      nutrients: _values(600, carbs: 100),
      items: [
        MealItemEntry(id: 'a', foodId: 'rice', nameEn: 'Rice', nameAr: '', weightG: 200, nutrients: _values(300, carbs: 90)),
        MealItemEntry(id: 'b', foodId: 'chicken', nameEn: 'Chicken', nameAr: '', weightG: 100, nutrients: _values(300, carbs: 10)),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('what was eaten', () {
    test('a single food loses the share that was left', () {
      final meal = _single().copyWith(leftover: MealLeftover(grams: 50, weighedAt: DateTime.now()));
      expect(meal.nutrients.calories, 300);
      expect(meal.nutrients.carbohydrates, 60);
      expect(meal.eatenWeightG, 150);
      expect(meal.servedNutrients.calories, 400);
    });

    test('a chosen plate food loses only its own values', () {
      final meal = _plate().copyWith(leftover: MealLeftover(grams: 100, itemIndex: 0, weighedAt: DateTime.now()));
      expect(meal.nutrients.calories, 450);
      expect(meal.nutrients.carbohydrates, 55);
      expect(meal.eatenWeightG, 200);
    });

    test('Mixed takes the leftovers off the whole plate by its share', () {
      final meal = _plate().copyWith(leftover: MealLeftover(grams: 150, weighedAt: DateTime.now()));
      expect(meal.nutrients.calories, 300);
      expect(meal.nutrients.carbohydrates, 50);
      expect(eatenShareOfItem(meal, 0), 0.5);
      expect(eatenShareOfItem(meal, 1), 0.5);
    });

    test('each plate food shows what was eaten of it', () {
      final meal = _plate().copyWith(leftover: MealLeftover(grams: 50, itemIndex: 0, weighedAt: DateTime.now()));
      expect(eatenShareOfItem(meal, 0), 0.75);
      expect(eatenShareOfItem(meal, 1), 1);
    });

    test('unknown values stay unknown', () {
      final meal = _single()
          .copyWith(nutrients: const NutritionValues(
              calories: 400, protein: 10, carbohydrates: 80, fat: 5, sugar: 2, fiber: 0, sodium: 100, potassium: 50,
              missingKeys: {'fiber_g'}))
          .copyWith(leftover: MealLeftover(grams: 100, weighedAt: DateTime.now()));
      expect(meal.nutrients.isMissing('fiber_g'), isTrue);
    });

    test('more than was served, or nothing, is refused', () {
      expect(leftoverProblem(_single(), 201), LeftoverProblem.tooHeavy);
      expect(leftoverProblem(_single(), 0), LeftoverProblem.empty);
      expect(leftoverProblem(_plate(), 101, itemIndex: 1), LeftoverProblem.tooHeavy);
      expect(leftoverProblem(_plate(), 50, itemIndex: 2), LeftoverProblem.noSuchFood);
      expect(leftoverProblem(_plate(), 300), isNull);
    });
  });

  group('weighing what is left', () {
    late MiqdarController controller;

    setUp(() async {
      final client = MockClient((_) async => http.Response('{}', 200));
      final database = LocalDatabase();
      await database.initialize();
      controller = MiqdarController(
        localDatabase: database,
        apiService: ApiService(
          baseUrl: 'http://scale.test',
          client: client,
          gemini: GeminiNutritionService(apiKey: 'k', models: const ['m'], client: client),
        ),
        alertService: AlertService(),
      );
      controller.signIn(email: '');
    });

    test('totals use what was eaten, and removing leftovers restores what was served', () async {
      final meal = _single();
      await controller.localDatabase.insertMealEntry(meal);
      controller.meals = [meal];
      expect(await controller.saveLeftover(meal, 50), isNull);
      expect(controller.todayTotals.calories, 300);
      expect(controller.meals.single.leftover!.grams, 50);

      await controller.removeLeftover(controller.meals.single);
      expect(controller.todayTotals.calories, 400);
      expect(controller.meals.single.leftover, isNull);
    });

    test('weighing again replaces the first weight', () async {
      final meal = _single();
      controller.meals = [meal];
      await controller.saveLeftover(meal, 50);
      await controller.saveLeftover(controller.meals.single, 100);
      expect(controller.todayTotals.calories, 200);
    });

    test('a refused weight changes nothing', () async {
      final meal = _single();
      controller.meals = [meal];
      expect(await controller.saveLeftover(meal, 500), LeftoverProblem.tooHeavy);
      expect(controller.meals.single.leftover, isNull);
    });

    test('only meals of the current day can be weighed', () {
      expect(controller.canWeighLeftovers(_single()), isTrue);
      expect(controller.canWeighLeftovers(_single(when: DateTime.now().subtract(const Duration(days: 1)))), isFalse);
    });

    test('food not eaten adds up grams and calories', () {
      final now = DateTime.now();
      final total = MiqdarController.notEaten([
        _single().copyWith(leftover: MealLeftover(grams: 50, weighedAt: now)),
        _plate().copyWith(leftover: MealLeftover(grams: 100, itemIndex: 1, weighedAt: now)),
        _single(),
      ]);
      expect(total.grams, 150);
      expect(total.values.calories, 400);
    });
  });
}
