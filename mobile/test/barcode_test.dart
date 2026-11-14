import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miqdar_mobile/app_controller.dart';
import 'package:miqdar_mobile/data/local_database.dart';
import 'package:miqdar_mobile/models/nutrition.dart';
import 'package:miqdar_mobile/services/alert_service.dart';
import 'package:miqdar_mobile/services/api_service.dart';
import 'package:miqdar_mobile/services/gemini_service.dart';
import 'package:miqdar_mobile/services/open_food_facts.dart';

const _code = '6281007030090';

http.Response _off({bool found = true, Map<String, Object?>? nutriments, Object? serving = 200}) => http.Response.bytes(
      utf8.encode(jsonEncode(found
          ? {
              'status': 1,
              'product': {
                'product_name': 'Laban Up',
                'product_name_ar': 'لبن أب',
                'brands': 'Almarai',
                'serving_quantity': serving,
                'nutriments': nutriments ??
                    {
                      'energy-kcal_100g': 56,
                      'proteins_100g': 3.2,
                      'carbohydrates_100g': 4.6,
                      'fat_100g': 2.8,
                      'sugars_100g': 4.6,
                      'fiber_100g': 0,
                      'sodium_100g': 0.05,
                      'potassium_100g': 0.15,
                    },
              },
            }
          : {'status': 0, 'status_verbose': 'product not found'})),
      found ? 200 : 404,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Open Food Facts lookup', () {
    test('a known product gives its name and values per 100 g, sodium in mg', () async {
      late Uri asked;
      final off = OpenFoodFactsService(client: MockClient((r) async {
        asked = r.url;
        return _off();
      }));
      final product = (await off.lookup(_code))!;
      expect(asked.path, contains(_code));
      expect(product.nameEn, 'Laban Up');
      expect(product.nameAr, 'لبن أب');
      expect(product.per100g.calories, 56);
      expect(product.per100g.sodium, closeTo(50, 0.001));
      expect(product.per100g.potassium, closeTo(150, 0.001));
      expect(product.servingG, 200);
    });

    test('an unknown product gives nothing', () async {
      final off = OpenFoodFactsService(client: MockClient((_) async => _off(found: false)));
      expect(await off.lookup(_code), isNull);
    });

    test('missing values read as unknown, never zero', () async {
      final off = OpenFoodFactsService(client: MockClient((_) async => _off(nutriments: {'energy-kcal_100g': 400, 'sugars_100g': 30})));
      final product = (await off.lookup(_code))!;
      expect(product.per100g.isMissing('protein_g'), isTrue);
      expect(product.per100g.isMissing('sugar_g'), isFalse);
    });

    test('a product with no calories cannot be used', () async {
      final off = OpenFoodFactsService(client: MockClient((_) async => _off(nutriments: {'sugars_100g': 30})));
      expect(await off.lookup(_code), isNull);
    });

    test('a network failure gives nothing rather than an error', () async {
      final off = OpenFoodFactsService(client: MockClient((_) async => throw http.ClientException('offline')));
      expect(await off.lookup(_code), isNull);
    });
  });

  group('logging a barcode', () {
    MiqdarController controllerWith(http.Client off) {
      final none = MockClient((_) async => http.Response('{}', 200));
      final database = LocalDatabase();
      return MiqdarController(
        localDatabase: database,
        apiService: ApiService(
          baseUrl: 'http://scale.test',
          client: none,
          gemini: GeminiNutritionService(apiKey: 'k', models: const ['m'], client: none),
          openFoodFacts: OpenFoodFactsService(client: off),
        ),
        alertService: AlertService(),
      )..signIn(email: '');
    }

    test('uses the given grams and says the numbers came from the barcode', () async {
      final controller = controllerWith(MockClient((_) async => _off()));
      await controller.localDatabase.initialize();
      final draft = (await controller.prepareBarcodeDraft(_code, weightG: 250))!;
      expect(draft.weightG, 250);
      expect(draft.nutrients.calories, closeTo(140, 0.01));
      expect(draft.verificationStatus, barcodeStatus);
      final meal = (await controller.saveLastRecognition())!;
      expect(meal.verificationStatus, barcodeStatus);
    });

    test("away from the scale with no grams, the pack's serving is used", () async {
      final controller = controllerWith(MockClient((_) async => _off()));
      final draft = (await controller.prepareBarcodeDraft(_code))!;
      expect(draft.weightG, 200);
      expect(draft.portionSource, PortionSource.serving);
    });

    test('an unknown product gives no draft', () async {
      final controller = controllerWith(MockClient((_) async => _off(found: false)));
      expect(await controller.prepareBarcodeDraft(_code, weightG: 100), isNull);
    });
  });
}
