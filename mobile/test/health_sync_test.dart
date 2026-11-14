import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miqdar_mobile/app_controller.dart';
import 'package:miqdar_mobile/data/local_database.dart';
import 'package:miqdar_mobile/models/body_profile.dart';
import 'package:miqdar_mobile/models/diabetes.dart';
import 'package:miqdar_mobile/models/glucose.dart';
import 'package:miqdar_mobile/models/nutrition.dart';
import 'package:miqdar_mobile/models/water.dart';
import 'package:miqdar_mobile/services/alert_service.dart';
import 'package:miqdar_mobile/services/api_service.dart';
import 'package:miqdar_mobile/services/gemini_service.dart';
import 'package:miqdar_mobile/services/health_sync.dart';

class FakeHealth implements HealthSync {
  bool allow = true;
  final meals = <String, MealEntry>{};
  final water = <String, WaterEntry>{};
  final weightsWritten = <BodyWeightEntry>[];
  List<BodyWeightEntry> weightsInHealth = [];
  List<GlucoseReading> glucoseInHealth = [];

  @override
  Future<bool> requestPermission() async => allow;
  @override
  Future<void> writeMeal(MealEntry meal) async => meals[meal.id] = meal;
  @override
  Future<void> deleteMeal(MealEntry meal) async => meals.remove(meal.id);
  @override
  Future<void> writeWater(WaterEntry entry) async => water[entry.id] = entry;
  @override
  Future<void> deleteWater(WaterEntry entry) async => water.remove(entry.id);
  @override
  Future<void> writeWeight(BodyWeightEntry entry) async => weightsWritten.add(entry);
  @override
  Future<List<BodyWeightEntry>> readWeights(DateTime since) async => weightsInHealth;
  @override
  Future<List<GlucoseReading>> readGlucose(DateTime since) async => glucoseInHealth;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MiqdarController controller;
  late FakeHealth health;

  setUp(() async {
    final client = MockClient((_) async => http.Response('{}', 200));
    final database = LocalDatabase();
    await database.initialize();
    health = FakeHealth();
    controller = MiqdarController(
      localDatabase: database,
      apiService: ApiService(
        baseUrl: 'http://scale.test',
        client: client,
        gemini: GeminiNutritionService(apiKey: 'k', models: const ['m'], client: client),
      ),
      alertService: AlertService(),
      healthSync: health,
    );
    controller.signIn(email: '');
  });

  Future<MealEntry> logMeal() async {
    final food = controller.createCustomFood(nameEn: 'Kabsa', basisGrams: 100, calories: 180, carbs: 20);
    await controller.prepareCatalogDraft(food: food, weightG: 300);
    return (await controller.saveLastRecognition(mealType: 'Lunch'))!;
  }

  test('nothing goes to Health until sync is switched on', () async {
    await logMeal();
    await controller.addWater(250);
    expect(health.meals, isEmpty);
    expect(health.water, isEmpty);
    expect(controller.healthSyncOn, isFalse);
  });

  test('switching on asks permission; refused leaves it off', () async {
    health.allow = false;
    expect(await controller.setHealthSync(true), isFalse);
    expect(controller.healthSyncOn, isFalse);
  });

  test('when on, meals, water and weight are written, and deleting a meal removes it', () async {
    expect(await controller.setHealthSync(true), isTrue);
    final meal = await logMeal();
    await pumpEventQueue();
    expect(health.meals[meal.id]!.nutrients.calories, closeTo(540, 0.01));

    final drink = await controller.addWater(330);
    await pumpEventQueue();
    expect(health.water[drink.id]!.ml, 330);

    await controller.saveWeightEntry(id: 'w1', measuredOn: DateTime.now(), weightKg: 78.5);
    await pumpEventQueue();
    expect(health.weightsWritten.single.weightKg, 78.5);

    await controller.deleteMeal(meal.id);
    await pumpEventQueue();
    expect(health.meals, isEmpty);
  });

  test('an edited meal is replaced in Health', () async {
    await controller.setHealthSync(true);
    final meal = await logMeal();
    await controller.setMealPieceCount(meal.copyWith(pieceCount: 2), 4);
    await pumpEventQueue();
    expect(health.meals[meal.id]!.weightG, closeTo(600, 0.01));
  });

  test('weights from Health join the weight log once, without duplicates', () async {
    final day = DateTime.now().subtract(const Duration(days: 2));
    health.weightsInHealth = [BodyWeightEntry(id: 'h1', measuredOn: day, weightKg: 79.1)];
    await controller.setHealthSync(true);
    await controller.syncFromHealth();
    await controller.syncFromHealth();
    expect(controller.weightEntries.where((w) => w.weightKg == 79.1).length, 1);
  });

  test('switching off stops writing', () async {
    await controller.setHealthSync(true);
    await controller.setHealthSync(false);
    await logMeal();
    await pumpEventQueue();
    expect(health.meals, isEmpty);
  });

  group('blood sugar from Health', () {
    setUp(() async {
      await controller.updateDiabetes(const DiabetesSettings(hasDiabetes: true, type: DiabetesType.type2));
    });

    test('appears beside the meal it belongs to, marked as from Apple Health, once', () async {
      final meal = await logMeal();
      health.glucoseInHealth = [
        GlucoseReading(
          id: 'health-glucose-1',
          mgdl: 171,
          at: meal.eatenAt.add(const Duration(hours: 2)).isAfter(DateTime.now())
              ? DateTime.now()
              : meal.eatenAt.add(const Duration(hours: 2)),
          tag: GlucoseTag.other,
          fromHealth: true,
        ),
      ];
      await controller.setHealthSync(true);
      await controller.syncFromHealth();
      final readings = controller.readingsForMeal(meal);
      expect(readings.single.mgdl, 171);
      expect(readings.single.fromHealth, isTrue);
    });

    test('a reading already typed by hand is not added again', () async {
      final at = DateTime.now().subtract(const Duration(minutes: 30));
      await controller.addGlucose(140, tag: GlucoseTag.other, at: at);
      health.glucoseInHealth = [
        GlucoseReading(id: 'health-glucose-2', mgdl: 140, at: at.add(const Duration(minutes: 2)), tag: GlucoseTag.other, fromHealth: true),
      ];
      await controller.setHealthSync(true);
      expect(controller.glucoseReadings.length, 1);
    });

    test('not read without diabetes mode', () async {
      await controller.updateDiabetes(const DiabetesSettings());
      health.glucoseInHealth = [
        GlucoseReading(id: 'health-glucose-3', mgdl: 120, at: DateTime.now(), tag: GlucoseTag.other, fromHealth: true),
      ];
      await controller.setHealthSync(true);
      expect(controller.glucoseReadings, isEmpty);
    });
  });
}
