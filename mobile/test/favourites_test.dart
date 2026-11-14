import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miqdar_mobile/app_controller.dart';
import 'package:miqdar_mobile/data/local_database.dart';
import 'package:miqdar_mobile/models/nutrition.dart';
import 'package:miqdar_mobile/services/alert_service.dart';
import 'package:miqdar_mobile/services/api_service.dart';
import 'package:miqdar_mobile/services/gemini_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MiqdarController controller;
  var geminiCalls = 0;

  setUp(() async {
    geminiCalls = 0;
    final client = MockClient((_) async {
      geminiCalls++;
      return http.Response('{}', 200);
    });
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

  Future<MealEntry> logFood(String name, {double grams = 100, double kcal = 200}) async {
    final food = controller.createCustomFood(nameEn: name, basisGrams: 100, calories: kcal, carbs: 20);
    await controller.prepareCatalogDraft(food: food, weightG: grams);
    return (await controller.saveLastRecognition(mealType: 'Lunch'))!;
  }

  test('a starred meal is a favourite, and unstarring removes it', () async {
    final kabsa = await logFood('Kabsa');
    expect(controller.favouriteMeals, isEmpty);

    await controller.setFavourite(kabsa, true);
    expect(controller.favouriteMeals.single.nameEn, 'Kabsa');
    expect(controller.meals.firstWhere((m) => m.id == kabsa.id).favourite, isTrue);

    await controller.setFavourite(controller.favouriteMeals.single, false);
    expect(controller.favouriteMeals, isEmpty);
  });

  test('favourites leave Recent, so a food is listed once', () async {
    final kabsa = await logFood('Kabsa');
    await logFood('Laban');
    await controller.setFavourite(kabsa, true);
    expect(controller.recentFoods.map((m) => m.nameEn), ['Laban']);
  });

  test('logging a favourite again uses its saved values and asks Gemini nothing', () async {
    final kabsa = await logFood('Kabsa', grams: 250, kcal: 180);
    await controller.setFavourite(kabsa, true);

    final draft = await controller.prepareRelog(controller.favouriteMeals.single);
    expect(draft.nutrients.calories, closeTo(450, 0.01));
    expect(geminiCalls, 0);
  });

  test('the same food starred twice shows once, the newest', () async {
    final first = await logFood('Dates', grams: 30);
    final second = await logFood('Dates', grams: 50);
    await controller.setFavourite(first, true);
    await controller.setFavourite(second, true);
    expect(controller.favouriteMeals.single.weightG, 50);
  });
}
