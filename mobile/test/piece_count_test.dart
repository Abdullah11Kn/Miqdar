import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miqdar_mobile/app_controller.dart';
import 'package:miqdar_mobile/data/local_database.dart';
import 'package:miqdar_mobile/models/nutrition.dart';
import 'package:miqdar_mobile/services/alert_service.dart';
import 'package:miqdar_mobile/services/api_service.dart';
import 'package:miqdar_mobile/services/gemini_service.dart';

final _photo = Uint8List.fromList([0xFF, 0xD8, 0xFF, 1]);

http.Response _gemini(Map<String, dynamic> candidate) => http.Response.bytes(
      utf8.encode(jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'candidates': [candidate]
                  })
                },
              ],
            },
          },
        ],
      })),
      200,
    );

Map<String, dynamic> _dates({int? count = 3, String unit = 'piece'}) => {
      'name_en': 'Sukari Dates',
      'name_ar': 'تمر سكري',
      'confidence': 0.9,
      'edible_fraction': 0.9,
      'note': '',
      if (count != null) 'piece_count': count,
      'piece_unit': unit,
      'per_100g_edible': {
        'calories_kcal': 300.0, 'protein_g': 2.0, 'carbohydrate_g': 75.0, 'fat_g': 0.2,
        'sugar_g': 65.0, 'fiber_g': 7.0, 'sodium_mg': 2.0, 'potassium_mg': 650.0, 'free_sugar_g': 0.0,
      },
    };

GeminiNutritionService _service(Map<String, dynamic> candidate) => GeminiNutritionService(
      apiKey: 'k',
      models: const ['m'],
      client: MockClient((_) async => _gemini(candidate)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Gemini counts the pieces it sees', () async {
    final result = await _service(_dates()).analyze(imageBytes: _photo, weightG: 30, eventId: 'c1');
    expect(result.pieceCount, 3);
    expect(result.pieceUnit, PieceUnit.piece);
  });

  test('a food that is not counted has no count', () async {
    final none = await _service(_dates(count: 0)).analyze(imageBytes: _photo, weightG: 300, eventId: 'c2');
    expect(none.pieceCount, isNull);
    final missing = await _service(_dates(count: null)).analyze(imageBytes: _photo, weightG: 300, eventId: 'c3');
    expect(missing.pieceCount, isNull);
  });

  test('changing the count scales grams and nutrients from the weight per piece, and can go back', () async {
    final three = await _service(_dates()).analyze(imageBytes: _photo, weightG: 30, eventId: 'c4');
    final five = three.withPieceCount(5);
    expect(five.pieceCount, 5);
    expect(five.weightG, closeTo(50, 0.001));
    expect(five.nutrients.calories, closeTo(three.nutrients.calories * 5 / 3, 0.01));
    expect(five.portionSource, PortionSource.counted);

    final back = five.withPieceCount(3);
    expect(back.weightG, closeTo(30, 0.001));
  });

  test('cups are counted as cups', () async {
    final coffee = await _service(_dates(count: 2, unit: 'cup')).analyze(imageBytes: _photo, weightG: 60, eventId: 'c5');
    expect(coffee.pieceUnit, PieceUnit.cup);
  });

  group('a saved meal', () {
    late MiqdarController controller;
    setUp(() async {
      final client = MockClient((_) async => _gemini(_dates()));
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

    test('keeps its count, and changing it on Meal Detail rescales the meal', () async {
      await controller.recognize(image: null, customImageBytes: _photo, weightG: 30);
      final meal = (await controller.saveLastRecognition(mealType: 'Snack'))!;
      expect(meal.pieceCount, 3);

      await controller.setMealPieceCount(meal, 6);
      final updated = controller.meals.firstWhere((m) => m.id == meal.id);
      expect(updated.pieceCount, 6);
      expect(updated.weightG, closeTo(60, 0.001));
      expect(updated.nutrients.calories, closeTo(meal.nutrients.calories * 2, 0.01));
      expect(updated.portionSource, PortionSource.counted);
    });
  });
}
