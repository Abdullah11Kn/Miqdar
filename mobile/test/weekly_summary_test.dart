import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miqdar_mobile/app_controller.dart';
import 'package:miqdar_mobile/data/local_database.dart';
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
    await controller.updateGoals(controller.goals.copyWith(calories: 2000, sugar: 50));
  });

  Future<void> logOn(int daysAgo, String name, {double kcal = 500, double sugar = 0}) async {
    final food = controller.createCustomFood(nameEn: name, basisGrams: 100, calories: kcal, sugar: sugar, carbs: 10);
    await controller.prepareCatalogDraft(food: food, weightG: 100);
    final at = DateTime(controller.today.year, controller.today.month, controller.today.day - daysAgo, 13);
    await controller.saveLastRecognition(mealType: 'Lunch', eatenAt: at);
  }

  test('covers the last 7 days: averages, days over each limit, water and most-eaten foods', () async {
    await logOn(0, 'Kabsa', kcal: 1200);
    await logOn(0, 'Kunafa', kcal: 900, sugar: 60); // today: 2,100 kcal, 60 g sugar
    await logOn(1, 'Kabsa', kcal: 1200);
    await logOn(3, 'Kabsa', kcal: 1000);
    await logOn(9, 'Pizza', kcal: 3000); // outside the week
    await controller.addWater(1500);
    await controller.addWater(500, at: DateTime.now().subtract(const Duration(days: 1)));

    final week = controller.weeklySummary();

    expect(week.loggedDays, 3);
    expect(week.averageCalories, closeTo((2100 + 1200 + 1000) / 3, 0.01));
    expect(week.daysOverSugar, 1);
    expect(week.daysOverCalories, 1);
    expect(week.topFoods.first, (name: 'Kabsa', count: 3));
    expect(week.topFoods.map((f) => f.name), isNot(contains('Pizza')));
    expect(week.averageWaterMl, closeTo((1500 + 500) / 2, 0.01));
    expect(week.waterGoalMl, controller.waterGoalMl);
  });

  test('an empty week is empty', () {
    expect(controller.weeklySummary().isEmpty, isTrue);
  });
}
