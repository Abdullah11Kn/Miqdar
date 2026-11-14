import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miqdar_mobile/app_controller.dart';
import 'package:miqdar_mobile/data/local_database.dart';
import 'package:miqdar_mobile/models/body_profile.dart';
import 'package:miqdar_mobile/models/diabetes.dart';
import 'package:miqdar_mobile/models/nutrition.dart';
import 'package:miqdar_mobile/services/alert_service.dart';
import 'package:miqdar_mobile/services/api_service.dart';
import 'package:miqdar_mobile/services/gemini_service.dart';

BodyProfile _profile({BodySex sex = BodySex.female, int birthYear = 1990, bool pregnant = false}) => BodyProfile(
      sex: sex,
      birthYear: birthYear,
      heightCm: 165,
      weightKg: 70,
      activity: ActivityLevel.light,
      goal: WeightGoal.maintain,
      pregnantOrBreastfeeding: pregnant,
    );

const _type2 = DiabetesSettings(hasDiabetes: true, type: DiabetesType.type2);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('carb portions', () {
    test('are 15 g each, to the nearest half', () {
      expect(carbPortions(45), 3);
      expect(carbPortions(52), 3.5);
      expect(carbPortions(7), 0.5);
      expect(formatPortions(3), '3');
      expect(formatPortions(3.5), '3.5');
    });
  });

  group('when a starting number is offered', () {
    test('45 g a meal for women, 60 g for men, 15 g a snack', () {
      expect(suggestedCarbs(_profile()).meal, 45);
      expect(suggestedCarbs(_profile(sex: BodySex.male)).meal, 60);
      expect(suggestedCarbs(_profile()).snack, 15);
      expect(suggestedCarbs(null).meal, 45);
    });

    test('never for type 1, insulin, pregnancy, under 18, kidney disease or fasting', () {
      final now = DateTime(2026, 11, 7);
      expect(carbAdviceBlock(_type2, profile: _profile(), now: now), isNull);
      expect(carbAdviceBlock(_type2.copyWith(type: DiabetesType.type1), now: now), CarbAdviceBlock.type1);
      expect(carbAdviceBlock(_type2.copyWith(usesInsulin: true), now: now), CarbAdviceBlock.insulin);
      expect(carbAdviceBlock(_type2, profile: _profile(pregnant: true), now: now), CarbAdviceBlock.pregnancy);
      expect(carbAdviceBlock(_type2, profile: _profile(birthYear: 2010), now: now), CarbAdviceBlock.underAge);
      expect(carbAdviceBlock(_type2, kidneyDisease: true, now: now), CarbAdviceBlock.kidney);
      expect(carbAdviceBlock(_type2, fasting: true, now: now), CarbAdviceBlock.fasting);
    });

    test('settings survive being stored', () {
      final value = _type2.copyWith(mealCarbsG: 50, snackCarbsG: 20, source: CarbPlanSource.doctor);
      final back = DiabetesSettings.fromJson(value.toJson());
      expect(back.hasDiabetes, isTrue);
      expect(back.type, DiabetesType.type2);
      expect(back.carbTargetFor('Lunch'), 50);
      expect(back.carbTargetFor('Snack'), 20);
    });
  });

  group('the free-sugar limit (WHO)', () {
    test('is 10% of daily calories, or 5% with diabetes, at 4 kcal a gram', () {
      expect(freeSugarLimitG(2000), 50);
      expect(freeSugarLimitG(2000, diabetes: true), 25);
      expect(freeSugarLimitG(1800, diabetes: true), 23); // 22.5 rounds to 23
    });

    test('the calculated goal sets the sugar limit from the calories', () {
      final suggestion = suggestGoals(_profile(), LocalDatabase.defaultGoals, DateTime(2026, 11, 14));
      expect(suggestion.goals!.sugar, freeSugarLimitG(suggestion.goals!.calories));
    });

    test('the choice survives being stored', () {
      const settings = DiabetesSettings(hasDiabetes: true, sugarSource: SugarLimitSource.own, ownSugarLimitG: 20);
      final back = DiabetesSettings.fromJson(settings.toJson());
      expect(back.sugarSource, SugarLimitSource.own);
      expect(back.ownSugarLimitG, 20);
    });
  });

  group('the diabetes setting', () {
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
      controller.bodyProfile = _profile();
    });

    test('a sweet meal warns before Save, and the warning lands in the bell once saved', () async {
      await controller.updateDiabetes(_type2);
      final sweet = controller.createCustomFood(
        nameEn: 'Kunafa',
        basisGrams: 100,
        calories: 400,
        carbs: 50,
        sugar: 30,
      );
      await controller.prepareCatalogDraft(food: sweet, weightG: 200);
      expect(controller.projectedAlerts.map((a) => a.nutrientKey), contains('sugar_g'));
      // 60 g of sugar in 200 g against a 50 g limit: about 165 g keeps the day within it.
      expect(controller.projectedAlerts.first.message, contains('about 165 g keeps you within it'));

      final before = controller.alerts.length;
      await controller.saveLastRecognition(mealType: 'Lunch');
      expect(controller.alerts.length, greaterThan(before));
      expect(controller.alerts.first.nutrientKey, 'sugar_g');
      expect(controller.alerts.first.read, isFalse);
    });

    test('the same meal does not warn without diabetes, when it is less than 40% past', () async {
      final sweet = controller.createCustomFood(nameEn: 'Dates', basisGrams: 100, calories: 280, sugar: 63);
      await controller.prepareCatalogDraft(food: sweet, weightG: 100);
      // 63 g against a 50 g limit is 26% past.
      expect(controller.goals.sugar, 50);
      expect(controller.projectedAlerts.where((a) => a.nutrientKey == 'sugar_g'), isEmpty);
    });

    test("the sugar limit is the general one until a choice is made, then Miqdar's or the user's own", () async {
      await controller.updateGoals(controller.goals.copyWith(calories: 2000, sugar: 50));
      await controller.updateDiabetes(_type2);
      expect(controller.sugarLimitG, 50);
      expect(controller.limitGoals.sugar, 50);

      await controller.useRecommendedSugarLimit();
      expect(controller.sugarLimitG, 25);
      expect(controller.limitGoals.sugar, 25);

      await controller.setOwnSugarLimit(30);
      expect(controller.sugarLimitG, 30);

      await controller.updateDiabetes(controller.diabetes.copyWith(hasDiabetes: false));
      expect(controller.sugarLimitG, 50);
    });

    test("people told to ask their care team can still take Miqdar's carb number", () async {
      await controller.updateDiabetes(const DiabetesSettings(hasDiabetes: true, type: DiabetesType.type1));
      expect(controller.carbBlock, CarbAdviceBlock.type1);
      expect(controller.suggestedCarbPlan, isNull);

      await controller.useSuggestedCarbsAnyway();
      expect(controller.carbTargetFor('Lunch'), 45);
      expect(controller.diabetes.source, CarbPlanSource.chosenAnyway);
    });

    test('is off by default, and nothing is offered', () {
      expect(controller.diabetes.carbsFirst, isFalse);
      expect(controller.suggestedCarbPlan, isNull);
      expect(controller.carbTargetFor('Lunch'), isNull);
    });

    test('Use This sets the starting numbers, and Wait for My Doctor leaves none', () async {
      await controller.updateDiabetes(_type2);
      expect(controller.suggestedCarbPlan!.meal, 45);
      await controller.useSuggestedCarbs();
      expect(controller.carbTargetFor('Dinner'), 45);
      expect(controller.carbTargetFor('Snack'), 15);

      await controller.waitForDoctor();
      expect(controller.carbTargetFor('Dinner'), isNull);
      expect(controller.diabetes.source, CarbPlanSource.waiting);
    });

    test('a doctor number can be typed in even when none is offered', () async {
      await controller.updateDiabetes(_type2.copyWith(usesInsulin: true));
      expect(controller.suggestedCarbPlan, isNull);
      expect(controller.carbBlock, CarbAdviceBlock.insulin);
      await controller.setDoctorCarbs(meal: 40, snack: 10);
      expect(controller.carbTargetFor('Lunch'), 40);
      expect(controller.carbTargetFor('Snack'), 10);
    });

    test('a kidney diet in Food Preferences stops the suggestion from applying', () async {
      await controller.updateDiabetes(_type2);
      await controller.useSuggestedCarbs();
      controller.healthProfile = controller.healthProfile.copyWith(conditions: ['kidney_disease']);
      expect(controller.suggestedCarbPlan, isNull);
      expect(controller.carbTargetFor('Lunch'), isNull);
    });

    test('is kept on the phone and restored', () async {
      await controller.updateDiabetes(_type2.copyWith(mealCarbsG: 50, source: CarbPlanSource.doctor));
      final raw = await controller.localDatabase.getSetting('diabetes');
      expect(raw, contains('"has_diabetes":true'));
      await controller.restorePreferences();
      expect(controller.diabetes.carbTargetFor('Lunch'), 50);
    });

    test('Delete All My Data removes it', () async {
      await controller.updateDiabetes(_type2);
      await controller.deleteAllData();
      expect(controller.diabetes.hasDiabetes, isFalse);
    });
  });

  test('average carbs by meal time counts only days that had that meal', () {
    MealEntry m(String type, DateTime at, double carbs, {bool unknown = false}) => MealEntry(
          id: '$type$at', foodId: 'f', nameEn: 'x', nameAr: '', eatenAt: at, mealType: type, weightG: 100, confidence: 1,
          nutrients: NutritionValues(calories: 100, protein: 0, carbohydrates: carbs, fat: 0, sugar: 0, fiber: 0, sodium: 0, potassium: 0,
              missingKeys: unknown ? const {'carbohydrate_g'} : const {}),
        );
    DateTime day(DateTime t) => DateTime(t.year, t.month, t.day);
    final result = averageCarbsByMealType([
      m('Lunch', DateTime(2026, 11, 1, 13), 60),
      m('Lunch', DateTime(2026, 11, 1, 14), 20),
      m('Lunch', DateTime(2026, 11, 2, 13), 40),
      m('Dinner', DateTime(2026, 11, 2, 20), 90),
      m('Dinner', DateTime(2026, 11, 3, 20), 0, unknown: true),
    ], day);
    expect(result['Lunch'], 60);
    expect(result['Dinner'], 90);
    expect(result.containsKey('Breakfast'), isFalse);
  });

  test('carbs total includes leftovers already taken off', () {
    final meal = MealEntry(
      id: 'm', foodId: 'f', nameEn: 'Rice', nameAr: '', eatenAt: DateTime.now(), mealType: 'Lunch',
      weightG: 200, confidence: 0.9,
      nutrients: const NutritionValues(calories: 300, protein: 5, carbohydrates: 60, fat: 2, sugar: 1, fiber: 1, sodium: 1, potassium: 1),
    ).copyWith(leftover: MealLeftover(grams: 100, weighedAt: DateTime.now()));
    expect(carbPortions(meal.nutrients.carbohydrates), 2);
  });
}
