import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miqdar_mobile/app_controller.dart';
import 'package:miqdar_mobile/data/local_database.dart';
import 'package:miqdar_mobile/models/body_profile.dart';
import 'package:miqdar_mobile/models/diabetes.dart';
import 'package:miqdar_mobile/services/alert_service.dart';
import 'package:miqdar_mobile/services/api_service.dart';
import 'package:miqdar_mobile/services/gemini_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
    await controller.updateGoals(controller.goals.copyWith(calories: 2000));
    // Three weeks of 2,200 kcal a day while weight falls 0.6 kg: a burn of about 2,430 kcal.
    final food = controller.createCustomFood(nameEn: 'Meal', basisGrams: 100, calories: 2200, carbs: 10);
    for (var d = 1; d <= 21; d++) {
      await controller.prepareCatalogDraft(food: food, weightG: 100);
      final day = controller.today.subtract(Duration(days: d));
      await controller.saveLastRecognition(eatenAt: DateTime(day.year, day.month, day.day, 13));
    }
    for (final (d, kg) in [(21, 80.0), (11, 79.7), (1, 79.4)]) {
      await controller.saveWeightEntry(id: 'w$d', measuredOn: controller.today.subtract(Duration(days: d)), weightKg: kg);
    }
  });

  test('offers a new goal once there is enough data', () {
    expect(controller.adaptiveGoalOffer?.suggestedKcal, 2450);
  });

  test('accepting sets the calorie goal and its sugar limit, and the offer goes', () async {
    await controller.acceptAdaptiveGoal();
    expect(controller.goals.calories, 2450);
    expect(controller.goals.sugar, 61); // 10% of 2,450 kcal at 4 kcal a gram
    expect(controller.adaptiveGoalOffer, isNull);
  });

  test('dismissing hides it for the week', () async {
    await controller.dismissAdaptiveGoal();
    expect(controller.adaptiveGoalOffer, isNull);
  });

  test("quiet in diabetes mode with a doctor's numbers", () async {
    await controller.updateDiabetes(const DiabetesSettings(hasDiabetes: true, type: DiabetesType.type2));
    await controller.setDoctorCarbs(meal: 50);
    expect(controller.adaptiveGoalOffer, isNull);
  });

  test('quiet in tracking-only mode', () async {
    await controller.updateGoals(controller.goals.copyWith(trackingOnly: true));
    expect(controller.adaptiveGoalOffer, isNull);
  });

  test('uses the goal direction from the body profile', () {
    controller.bodyProfile = const BodyProfile(
      sex: BodySex.male, birthYear: 1990, heightCm: 178, weightKg: 79.4,
      activity: ActivityLevel.light, goal: WeightGoal.lose, weeklyPaceKg: 0.5,
    );
    expect(controller.adaptiveGoalOffer?.suggestedKcal, 1900);
  });
}
