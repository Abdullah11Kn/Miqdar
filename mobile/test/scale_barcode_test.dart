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
import 'package:miqdar_mobile/services/barcode_reader.dart';
import 'package:miqdar_mobile/services/gemini_service.dart';
import 'package:miqdar_mobile/services/open_food_facts.dart';

final _photo = Uint8List.fromList([0xFF, 0xD8, 0xFF, 7]);

class _FakeReader implements BarcodeReader {
  _FakeReader(this.code);
  final String? code;
  @override
  Future<String?> read(Uint8List jpeg) async => code;
}

http.Response _geminiKabsa() => http.Response.bytes(
      utf8.encode(jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'candidates': [
                      {
                        'name_en': 'Chicken Kabsa', 'name_ar': 'كبسة دجاج', 'confidence': 0.9, 'edible_fraction': 1, 'note': '',
                        'piece_count': 0, 'piece_unit': 'piece',
                        'per_100g_edible': {
                          'calories_kcal': 160.0, 'protein_g': 9.0, 'carbohydrate_g': 20.0, 'fat_g': 5.0,
                          'sugar_g': 1.0, 'fiber_g': 1.0, 'sodium_mg': 300.0, 'potassium_mg': 150.0, 'free_sugar_g': 0.0,
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

http.Response _offLaban() => http.Response.bytes(
      utf8.encode(jsonEncode({
        'status': 1,
        'product': {
          'product_name': 'Laban',
          'nutriments': {'energy-kcal_100g': 56, 'proteins_100g': 3, 'carbohydrates_100g': 5, 'fat_100g': 2.8, 'sugars_100g': 5},
        },
      })),
      200,
    );

void main() {
  late List<String> hosts;

  MiqdarController controllerWith({String? code, bool known = true}) {
    hosts = [];
    final event = {
      'event_id': 'cap-21', 'status': 'photo', 'source': 'scale', 'age_s': 1, 'weight_g': 330.0,
      'image_base64': base64Encode(_photo),
    };
    final client = MockClient((request) async {
      hosts.add(request.url.host);
      if (request.url.host.contains('googleapis')) return _geminiKabsa();
      if (request.url.host.contains('openfoodfacts')) {
        return known ? _offLaban() : http.Response(jsonEncode({'status': 0}), 404);
      }
      if (request.url.path == '/scale/live') {
        return http.Response(jsonEncode({'mode': 'real', 'live_weight_g': 330.0, 'latest_capture': {...event}..remove('image_base64')}), 200);
      }
      return http.Response(jsonEncode(event), 200);
    });
    return MiqdarController(
      localDatabase: LocalDatabase(),
      apiService: ApiService(
        baseUrl: 'http://scale.test',
        client: client,
        gemini: GeminiNutritionService(apiKey: 'k', models: const ['m'], client: client),
        openFoodFacts: OpenFoodFactsService(client: client),
      ),
      alertService: AlertService(),
      barcodeReader: _FakeReader(code),
    );
  }

  test('a barcode in the scale photo uses the product, with the scale grams, and no Gemini request', () async {
    final controller = controllerWith(code: '6281007030090');
    await controller.syncScaleLive();
    await pumpEventQueue();
    final capture = controller.latestExternalScaleCapture!;
    expect(capture.eventId, 'cap-21');
    expect(capture.verificationStatus, barcodeStatus);
    expect(capture.weightG, 330);
    expect(capture.nutrients.calories, closeTo(184.8, 0.01));
    expect(capture.portionSource, PortionSource.scale);
    expect(capture.imageBytes, _photo);
    expect(hosts.where((h) => h.contains('googleapis')), isEmpty);
  });

  test('no barcode in the photo: Gemini as usual', () async {
    final controller = controllerWith(code: null);
    await controller.syncScaleLive();
    await pumpEventQueue();
    expect(controller.latestExternalScaleCapture!.verificationStatus, aiEstimateStatus);
  });

  test('a barcode Open Food Facts does not know: Gemini as usual', () async {
    final controller = controllerWith(code: '6281007030090', known: false);
    await controller.syncScaleLive();
    await pumpEventQueue();
    expect(controller.latestExternalScaleCapture!.verificationStatus, aiEstimateStatus);
  });
}
