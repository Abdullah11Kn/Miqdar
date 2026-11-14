import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miqdar_mobile/app_controller.dart';
import 'package:miqdar_mobile/data/local_database.dart';
import 'package:miqdar_mobile/models/diabetes.dart';
import 'package:miqdar_mobile/models/glucose.dart';
import 'package:miqdar_mobile/models/nutrition.dart';
import 'package:miqdar_mobile/services/alert_service.dart';
import 'package:miqdar_mobile/services/api_service.dart';
import 'package:miqdar_mobile/services/gemini_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('units', () {
    test('mg/dL is stored; mmol/L is shown by dividing by 18', () {
      expect(GlucoseUnit.mmol.fromMgdl(180), closeTo(10.0, 0.01));
      expect(GlucoseUnit.mmol.toMgdl(5.5), closeTo(99, 0.01));
      expect(GlucoseUnit.mgdl.format(126), '126');
      expect(GlucoseUnit.mmol.format(126), '7.0');
    });
  });

  group('readings', () {
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

    Future<MealEntry> mealAt(DateTime at, String name) async {
      final food = controller.createCustomFood(nameEn: name, basisGrams: 100, calories: 200, carbs: 40);
      await controller.prepareCatalogDraft(food: food, weightG: 100);
      return (await controller.saveLastRecognition(mealType: 'Lunch', eatenAt: at))!;
    }

    test('a reading 2 hours after belongs to the meal before it', () async {
      final noon = DateTime.now().subtract(const Duration(hours: 3));
      final kabsa = await mealAt(noon, 'Kabsa');
      await controller.addGlucose(162, tag: GlucoseTag.afterMeal, at: noon.add(const Duration(hours: 2)));
      expect(controller.readingsForMeal(kabsa).single.mgdl, 162);
    });

    test('a reading before a meal belongs to the meal after it', () async {
      final noon = DateTime.now().subtract(const Duration(hours: 1));
      final kabsa = await mealAt(noon, 'Kabsa');
      await controller.addGlucose(98, tag: GlucoseTag.beforeMeal, at: noon.subtract(const Duration(minutes: 20)));
      expect(controller.readingsForMeal(kabsa).single.mgdl, 98);
    });

    test('a reading far from any meal belongs to none', () async {
      final kabsa = await mealAt(DateTime.now().subtract(const Duration(hours: 10)), 'Kabsa');
      await controller.addGlucose(110, tag: GlucoseTag.other, at: DateTime.now());
      expect(controller.readingsForMeal(kabsa), isEmpty);
    });

    test('a reading typed in mmol/L is stored in mg/dL', () async {
      await controller.setGlucoseUnit(GlucoseUnit.mmol);
      final r = await controller.addGlucose(7.0, tag: GlucoseTag.other);
      expect(r.mgdl, closeTo(126, 0.01));
    });

    test('a reading can be deleted', () async {
      final r = await controller.addGlucose(140, tag: GlucoseTag.other);
      await controller.deleteGlucose(r.id);
      expect(controller.glucoseReadings, isEmpty);
    });

    test("the doctor's report lists readings beside meals, with no averages", () async {
      await controller.updateDiabetes(const DiabetesSettings(hasDiabetes: true, type: DiabetesType.type2));
      final at = DateTime.now().subtract(const Duration(hours: 3));
      await mealAt(at, 'Kabsa');
      await controller.addGlucose(162, tag: GlucoseTag.afterMeal, at: at.add(const Duration(hours: 2)));
      final report = controller.doctorReport(7, isAr: false);
      expect(report.readings.single.mgdl, 162);
      expect(report.readings.single.mealName, 'Kabsa');
      expect(report.readings.single.tag, GlucoseTag.afterMeal);
    });
  });
}
