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

final _photo = Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 2, 3]);

Map<String, dynamic> _candidate(String name, {double kcal = 140, double carbs = 25}) => {
      'name_en': name,
      'name_ar': 'جريش',
      'confidence': 0.9,
      'per_100g': {
        'calories_kcal': kcal, 'protein_g': 4.0, 'carbohydrate_g': carbs, 'fat_g': 3.0,
        'sugar_g': 1.0, 'fiber_g': 2.0, 'sodium_mg': 300.0, 'potassium_mg': 100.0,
      },
    };

http.Response _gemini(List<Map<String, dynamic>> candidates) => http.Response.bytes(
      utf8.encode(jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': jsonEncode({'candidates': candidates})},
              ],
            },
          },
        ],
      })),
      200,
    );

GeminiNutritionService _service(Future<http.Response> Function(http.Request) handler) =>
    GeminiNutritionService(
      apiKey: 'test-key',
      models: const ['first-model', 'second-model'],
      client: MockClient(handler),
    );

Matcher _failsWith(String code) =>
    throwsA(isA<RecognitionException>().having((e) => e.code, 'code', code));

void main() {
  test('calories come from Gemini per 100 g times the measured grams', () async {
    final service = _service((_) async => _gemini([_candidate('Jareesh'), _candidate('Saleeg', kcal: 200)]));

    final result = await service.analyze(imageBytes: _photo, weightG: 240, eventId: 'cap-1');

    expect(result.eventId, 'cap-1');
    expect(result.nameEn, 'Jareesh');
    expect(result.nutrients.calories, closeTo(336, 0.01));
    expect(result.verificationStatus, aiEstimateStatus);
    expect(result.foodId, startsWith(aiFoodIdPrefix));
    expect(result.imageBytes, _photo);
    final alternative = result.withCandidate(result.candidates[1]);
    expect(alternative.nutrients.calories, closeTo(480, 0.01));
    expect(alternative.withWeight(100).nutrients.calories, closeTo(200, 0.01));
  });

  test('the key travels in a header, never in the URL', () async {
    late http.Request sent;
    await _service((request) async {
      sent = request;
      return _gemini([_candidate('Jareesh')]);
    }).analyze(imageBytes: _photo, weightG: 100);

    expect(sent.headers['x-goog-api-key'], 'test-key');
    expect(sent.url.toString(), isNot(contains('test-key')));
  });

  test('falls back to the next model when one is unavailable', () async {
    final urls = <String>[];
    final result = await _service((request) async {
      urls.add(request.url.path);
      return urls.length == 1 ? http.Response('busy', 503) : _gemini([_candidate('Jareesh')]);
    }).analyze(imageBytes: _photo, weightG: 100);

    expect(urls.length, 2);
    expect(result.model, 'second-model');
  });

  test('a rejected key stops at once and is reported', () async {
    var calls = 0;
    await expectLater(
      _service((_) async {
        calls++;
        return http.Response('denied', 403);
      }).analyze(imageBytes: _photo, weightG: 100),
      _failsWith('AI_PROVIDER_UNAVAILABLE'),
    );
    expect(calls, 1);
  });

  test('no food in the photo is reported', () async {
    await expectLater(
      _service((_) async => _gemini([_candidate('not food', kcal: 0, carbs: 0)]))
          .analyze(imageBytes: _photo, weightG: 100),
      _failsWith('NOT_FOOD'),
    );
  });

  test('physically impossible nutrition is rejected', () async {
    await expectLater(
      _service((_) async => _gemini([_candidate('Rice', kcal: 2000)])).analyze(imageBytes: _photo, weightG: 100),
      _failsWith('AI_PROVIDER_UNAVAILABLE'),
    );
    await expectLater(
      _service((_) async => _gemini([_candidate('Rice', carbs: 300)])).analyze(imageBytes: _photo, weightG: 100),
      _failsWith('AI_PROVIDER_UNAVAILABLE'),
    );
  });

  test('a build with no key says so', () async {
    final service = GeminiNutritionService(apiKey: '', client: MockClient((_) async => http.Response('', 200)));
    expect(service.configured, isFalse);
    await expectLater(service.analyze(imageBytes: _photo, weightG: 100), _failsWith('AI_KEY_MISSING'));
  });

  group('scale photo sent to the app', () {
    late List<String> paths;

    MiqdarController controllerFor(List<Map<String, dynamic>> answer, {String source = 'auto'}) {
      paths = [];
      final event = {
        'event_id': 'cap-9', 'status': 'photo', 'source': source, 'age_s': 1, 'weight_g': 240.0,
        'image_base64': base64Encode(_photo),
      };
      final client = MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.host.contains('googleapis')) return _gemini(answer);
        if (request.url.path == '/scale/live') {
          return http.Response(jsonEncode({'mode': 'real', 'live_weight_g': 240.0, 'latest_capture': {...event}..remove('image_base64')}), 200);
        }
        return http.Response(jsonEncode(event), 200);
      });
      return MiqdarController(
        localDatabase: LocalDatabase(),
        apiService: ApiService(
          baseUrl: 'http://scale.test',
          client: client,
          gemini: GeminiNutritionService(apiKey: 'test-key', models: const ['m'], client: client),
        ),
        alertService: AlertService(),
      );
    }

    test('is analyzed once, and the scale is told the result', () async {
      final controller = controllerFor([_candidate('Jareesh')]);

      await controller.syncScaleLive();
      await controller.syncScaleLive();
      await pumpEventQueue();

      final capture = controller.latestExternalScaleCapture!;
      expect(capture.eventId, 'cap-9');
      expect(capture.nutrients.calories, closeTo(336, 0.01));
      expect(paths.where((path) => path.contains('generateContent')).length, 1);
      expect(paths, contains('/scale/capture/result'));
      expect(controller.analyzingScalePhoto, isFalse);
    });

    test('an empty plate from auto-capture does not interrupt the user', () async {
      final controller = controllerFor([_candidate('not food', kcal: 0, carbs: 0)]);
      await controller.syncScaleLive();
      await pumpEventQueue();
      expect(controller.latestExternalScaleCapture, isNull);
      expect(controller.latestScaleCaptureFailure, isNull);
    });

    test('a failed analysis keeps the photo on the failure screen', () async {
      final controller = controllerFor([_candidate('not food', kcal: 0, carbs: 0)], source: 'phone');
      await controller.syncScaleLive();
      await pumpEventQueue();
      expect(controller.latestScaleCaptureFailure?.error.code, 'NOT_FOOD');
      expect(controller.latestScaleCaptureFailure?.imageBytes, _photo);
    });
  });
}
