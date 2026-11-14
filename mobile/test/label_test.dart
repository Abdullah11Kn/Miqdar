import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miqdar_mobile/models/nutrition.dart';
import 'package:miqdar_mobile/services/api_service.dart';
import 'package:miqdar_mobile/services/gemini_service.dart';

final _label = Uint8List.fromList([0xFF, 0xD8, 0xFF, 9]);

http.Response _answer(Map<String, dynamic> json) => http.Response.bytes(
      utf8.encode(jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': jsonEncode(json)},
              ],
            },
          },
        ],
      })),
      200,
    );

Map<String, dynamic> _biscuits({bool readable = true}) => {
      'readable': readable,
      'serving_g': 30,
      'candidates': [
        {
          'name_en': 'Date Biscuits',
          'name_ar': 'بسكويت بالتمر',
          'confidence': 0.95,
          'edible_fraction': 1,
          'note': 'read from label',
          'piece_count': 0,
          'piece_unit': 'piece',
          'per_100g_edible': {
            'calories_kcal': 450.0, 'protein_g': 6.0, 'carbohydrate_g': 65.0, 'fat_g': 18.0,
            'sugar_g': 30.0, 'fiber_g': 3.0, 'sodium_mg': 300.0, 'potassium_mg': 150.0, 'free_sugar_g': 25.0,
          },
        },
      ],
    };

void main() {
  late Map<String, dynamic> sent;
  GeminiNutritionService service(Map<String, dynamic> answer) => GeminiNutritionService(
        apiKey: 'k',
        models: const ['m'],
        client: MockClient((r) async {
          sent = jsonDecode(r.body) as Map<String, dynamic>;
          return _answer(answer);
        }),
      );

  test('Gemini reads the label per 100 g, and the meal says the numbers came from the label', () async {
    final result = await service(_biscuits()).readLabel(photo: _label, weightG: 45);
    expect(result.nameEn, 'Date Biscuits');
    expect(result.weightG, 45);
    expect(result.nutrients.calories, closeTo(202.5, 0.01));
    expect(result.verificationStatus, labelStatus);
    expect(result.foodId, startsWith(labelFoodIdPrefix));
    expect(jsonEncode(sent), contains('nutrition label'));
  });

  test('without grams, the serving on the label is used', () async {
    final result = await service(_biscuits()).readLabel(photo: _label);
    expect(result.weightG, 30);
    expect(result.portionSource, PortionSource.serving);
  });

  test('an unreadable label is an error the screen can explain', () async {
    expect(
      () => service(_biscuits(readable: false)).readLabel(photo: _label),
      throwsA(isA<RecognitionException>().having((e) => e.code, 'code', 'LABEL_UNREADABLE')),
    );
  });
}
