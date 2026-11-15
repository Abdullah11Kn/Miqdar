import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:miqdar_mobile/services/gemini_service.dart';

http.Response _answer() => http.Response.bytes(
      utf8.encode(jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'candidates': [
                      {
                        'name_en': 'Rice',
                        'name_ar': 'رز',
                        'confidence': 0.9,
                        'edible_fraction': 1.0,
                        'per_100g_edible': {
                          'calories_kcal': 130.0, 'protein_g': 2.7, 'carbohydrate_g': 28.0, 'fat_g': 0.3,
                          'sugar_g': 0.1, 'fiber_g': 0.4, 'sodium_mg': 1.0, 'potassium_mg': 35.0,
                        },
                      },
                    ],
                  }),
                },
              ],
            },
          },
        ],
      })),
      200,
    );

/// A detailed 1280 x 960 photo, as large as the scale's (a plain one would compress to almost nothing).
Uint8List _bigPhoto() {
  final photo = img.Image(width: 1280, height: 960);
  var seed = 7;
  for (final p in photo) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    p.setRgb(seed & 255, (seed >> 8) & 255, (seed >> 16) & 255);
  }
  return Uint8List.fromList(img.encodeJpg(photo, quality: 90));
}

void main() {
  test('the scale photo is sent to Gemini at 768 px on its long side', () async {
    late Map<String, dynamic> sent;
    final service = GeminiNutritionService(
      apiKey: 'k',
      models: const ['m'],
      client: MockClient((r) async {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return _answer();
      }),
    );
    final photo = _bigPhoto();
    expect(photo.length, greaterThan(300 * 1024));
    final result = await service.analyze(imageBytes: photo, weightG: 200);
    final data = ((sent['contents'] as List).first['parts'] as List).first['inline_data']['data'] as String;
    final shown = img.decodeJpg(base64Decode(data))!;
    expect(shown.width, 768);
    expect(shown.height, 576);
    expect(result.imageBytes, photo, reason: 'the meal keeps the full photo');
  });

  test('Gemini is asked to think little, since naming a food needs no long reasoning', () async {
    late Map<String, dynamic> sent;
    final service = GeminiNutritionService(
      apiKey: 'k',
      models: const ['m'],
      client: MockClient((r) async {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return _answer();
      }),
    );
    await service.analyze(imageBytes: _bigPhoto(), weightG: 200);
    expect(sent['generationConfig']['thinkingConfig'], {'thinkingLevel': 'low'});
  });

  test('a model that refuses the thinking setting is asked again without it, not skipped', () async {
    final bodies = <Map<String, dynamic>>[];
    final models = <String>[];
    final service = GeminiNutritionService(
      apiKey: 'k',
      models: const ['old-model', 'other'],
      client: MockClient((r) async {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        bodies.add(body);
        models.add(r.url.pathSegments.last);
        if ((body['generationConfig'] as Map).containsKey('thinkingConfig')) {
          return http.Response('{"error":{"code":400,"message":"Thinking level is not supported for this model."}}', 400);
        }
        return _answer();
      }),
    );
    final result = await service.analyze(imageBytes: _bigPhoto(), weightG: 200);
    expect(result.nameEn, 'Rice');
    expect(models, ['old-model:generateContent', 'old-model:generateContent']);
    expect((bodies.last['generationConfig'] as Map).containsKey('thinkingConfig'), isFalse);
  });

  test('a small photo, or one that cannot be read, is sent as it is', () async {
    late Map<String, dynamic> sent;
    final service = GeminiNutritionService(
      apiKey: 'k',
      models: const ['m'],
      client: MockClient((r) async {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return _answer();
      }),
    );
    final odd = Uint8List.fromList([0xFF, 0xD8, 1, 2, 3]);
    await service.analyze(imageBytes: odd, weightG: 200);
    final data = ((sent['contents'] as List).first['parts'] as List).first['inline_data']['data'] as String;
    expect(base64Decode(data), odd);
  });
}
