import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miqdar_mobile/app_controller.dart';
import 'package:miqdar_mobile/data/local_database.dart';
import 'package:miqdar_mobile/services/alert_service.dart';
import 'package:miqdar_mobile/services/api_service.dart';
import 'package:miqdar_mobile/services/barcode_reader.dart';
import 'package:miqdar_mobile/services/gemini_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Capture on the phone and the live poll seeing the same photo ask Gemini once, not twice', () async {
    var geminiQuestions = 0;
    final event = {
      'event_id': 'cap-7', 'status': 'photo', 'source': 'phone', 'age_s': 0, 'weight_g': 185.0,
      'image_base64': base64Encode(Uint8List.fromList([0xFF, 0xD8, 1, 2])),
    };
    final client = MockClient((request) async {
      final path = request.url.path;
      if (request.url.host.contains('googleapis')) {
        if (path.endsWith(':generateContent')) geminiQuestions++;
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'candidates': [
                          {
                            'name_en': 'Banana', 'name_ar': 'موز', 'confidence': 0.9, 'edible_fraction': 0.65,
                            'per_100g_edible': {
                              'calories_kcal': 89.0, 'protein_g': 1.1, 'carbohydrate_g': 23.0, 'fat_g': 0.3,
                              'sugar_g': 12.0, 'fiber_g': 2.6, 'sodium_mg': 1.0, 'potassium_mg': 358.0,
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
      }
      if (path == '/scale/live') {
        return http.Response(
            jsonEncode({'mode': 'real', 'live_weight_g': 185.0, 'latest_capture': {...event}..remove('image_base64')}), 200);
      }
      if (path == '/scale/capture/latest') {
        await Future<void>.delayed(const Duration(milliseconds: 200)); // the poll's download is slower
        return http.Response(jsonEncode(event), 200);
      }
      if (path == '/scale/capture') return http.Response(jsonEncode(event), 200);
      return http.Response('{}', 200);
    });
    final controller = MiqdarController(
      localDatabase: LocalDatabase(),
      apiService: ApiService(
        baseUrl: 'http://scale.test',
        client: client,
        gemini: GeminiNutritionService(apiKey: 'k', models: const ['m'], client: client),
      ),
      alertService: AlertService(),
      barcodeReader: const NoBarcodeReader(),
    );

    final poll = controller.syncScaleLive();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await controller.captureFromScale();
    await poll;
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(geminiQuestions, 1);
  });
}
