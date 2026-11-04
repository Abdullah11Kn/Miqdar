import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miqdar_mobile/app_controller.dart';
import 'package:miqdar_mobile/data/food_catalog.dart';
import 'package:miqdar_mobile/data/local_database.dart';
import 'package:miqdar_mobile/models/nutrition.dart';
import 'package:miqdar_mobile/services/alert_service.dart';
import 'package:miqdar_mobile/services/api_service.dart';
import 'package:miqdar_mobile/services/gemini_service.dart';

Map<String, dynamic> _food(String name, {double kcal = 100, double edible = 1, double confidence = 0.9}) => {
      'name_en': name,
      'name_ar': 'طعام',
      'confidence': confidence,
      'edible_fraction': edible,
      'per_100g_edible': {
        'calories_kcal': kcal, 'protein_g': 5.0, 'carbohydrate_g': kcal > 56 ? (kcal - 56) / 4 : 0.0, 'fat_g': 4.0,
        'sugar_g': 1.0, 'fiber_g': 1.0, 'sodium_mg': 100.0, 'potassium_mg': 100.0,
      },
    };

http.Response _gemini(Map<String, dynamic> answer) => http.Response.bytes(
      utf8.encode(jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': jsonEncode(answer)},
              ],
            },
          },
        ],
      })),
      200,
      headers: {'content-type': 'application/json'},
    );

class _Rig {
  _Rig({this.geminiStatus = 200, Map<String, dynamic>? answer})
      : answer = answer ??
            {
              'meal_name_en': 'Chicken Kabsa',
              'meal_name_ar': 'كبسة دجاج',
              'foods': [_food('Rice', kcal: 150), _food('Chicken', kcal: 200, edible: 0.5)],
            };

  int geminiStatus;
  Map<String, dynamic> answer;
  final geminiBodies = <String>[];
  final scaleCalls = <String>[];
  late final MiqdarController controller;

  Map<String, dynamic>? plate;
  Map<String, dynamic>? refusal;
  String bootId = 'one';
  int photoFetches = 0;

  Map<String, dynamic> plateJson(List<double> grams, {bool finished = false}) => {
        'plate_id': 'plate-1',
        'state': finished ? 'finished' : 'open',
        'simulated': true,
        'steps': [
          for (var i = 0; i < grams.length; i++)
            <String, dynamic>{'index': i, 'grams': grams[i], 'reading_g': grams.take(i + 1).reduce((a, b) => a + b)},
        ],
      };

  Future<void> setUp() async {
    final client = MockClient((request) async {
      if (request.url.host.contains('googleapis')) {
        geminiBodies.add(request.body);
        return geminiStatus == 200 ? _gemini(answer) : http.Response('{}', geminiStatus);
      }
      final path = request.url.path;
      if (path == '/scale/live') {
        return http.Response(jsonEncode({'mode': 'simulated', 'live_weight_g': 300.0, 'plate': plate, 'boot_id': bootId}), 200);
      }
      if (path == '/scale/plate/photo') {
        photoFetches++;
        return http.Response(jsonEncode({'image_base64': base64Encode(Uint8List.fromList([0xFF, 0xD8, 1]))}), 200);
      }
      if (path.startsWith('/scale/plate/')) {
        scaleCalls.add(path.split('/').last);
        if (refusal != null) return http.Response(jsonEncode(refusal), 422);
        if (path.endsWith('cancel')) plate = null;
        return http.Response(jsonEncode({'plate': plate}), 200);
      }
      return http.Response('{}', 200);
    });
    final database = LocalDatabase();
    await database.initialize(); // no plugin in tests, so it stays in memory
    controller = MiqdarController(
      localDatabase: database,
      apiService: ApiService(
        baseUrl: 'http://scale.test',
        client: client,
        gemini: GeminiNutritionService(apiKey: 'test-key', models: const ['m'], client: client),
      ),
      alertService: AlertService(),
    );
    controller.signIn(email: '');
  }

  Future<void> finishPlate() async {
    plate = plateJson([200, 100], finished: true);
    await controller.syncScaleLive();
    await pumpEventQueue();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the phone follows an open plate from the scale, photo included', () async {
    final rig = _Rig();
    await rig.setUp();
    rig.plate = rig.plateJson([200]);
    await rig.controller.syncScaleLive();
    final plate = rig.controller.scalePlate!;
    expect(plate.isOpen, isTrue);
    expect(plate.totalG, 200);
    expect(rig.controller.platePhoto(plate.steps.first), isNotNull);
    expect(rig.geminiBodies, isEmpty);
  });

  test('a finished plate makes exactly one Gemini request with every photo and each food\'s grams', () async {
    final rig = _Rig();
    await rig.setUp();
    await rig.finishPlate();
    await rig.controller.syncScaleLive();
    expect(rig.geminiBodies, hasLength(1));
    expect('inline_data'.allMatches(rig.geminiBodies.single), hasLength(2));
    expect(rig.geminiBodies.single, contains('200 g'));
    expect(rig.geminiBodies.single, contains('100 g'));
    expect(rig.scaleCalls, contains('cancel'));
    expect(rig.controller.scalePlate, isNull);
  });

  test('each food uses its value times its edible share times its measured grams', () async {
    final rig = _Rig();
    await rig.setUp();
    await rig.finishPlate();
    final result = rig.controller.lastRecognition!;
    expect(result.isPlate, isTrue);
    expect(result.plateNameEn, 'Chicken Kabsa');
    expect(result.plateItems.map((i) => i.weightG), [200, 100]);
    expect(result.plateItems[0].nutrients.calories, closeTo(300, 0.01)); // 150 per 100 g x 200 g
    expect(result.plateItems[1].nutrients.calories, closeTo(100, 0.01)); // 200 x 0.5 edible x 100 g
    expect(result.totalNutrients.calories, closeTo(400, 0.01));
    expect(result.totalWeightG, 300);
    expect(rig.controller.latestExternalScaleCapture, isNotNull);
  });

  test('a plate saves as one meal with its foods listed, counted once', () async {
    final rig = _Rig();
    await rig.setUp();
    await rig.finishPlate();
    final meal = (await rig.controller.saveLastRecognition(mealType: 'Lunch'))!;
    expect(meal.nameEn, 'Chicken Kabsa');
    expect(meal.items, hasLength(2));
    expect(meal.weightG, 300);
    expect(meal.nutrients.calories, closeTo(400, 0.01));
    expect(rig.controller.meals.where((m) => m.id == meal.id), hasLength(1));
    expect(rig.controller.todayTotals.calories, closeTo(400, 0.01));
  });

  test('foods can be removed or reweighed, and edited grams are labelled as entered by hand', () async {
    final rig = _Rig();
    await rig.setUp();
    await rig.finishPlate();
    final items = rig.controller.lastRecognition!.plateItems;
    await rig.controller.setPlateItemWeight(items[1].id, 50);
    var result = rig.controller.lastRecognition!;
    expect(result.plateItems[1].portionSource, PortionSource.manual);
    expect(result.plateItems[0].portionSource, PortionSource.scale);
    expect(result.totalNutrients.calories, closeTo(350, 0.01));

    await rig.controller.removePlateItem(items[0].id);
    result = rig.controller.lastRecognition!;
    expect(result.plateItems, hasLength(1));
    expect(result.totalNutrients.calories, closeTo(50, 0.01));
  });

  test('an unsaved plate goes by the plate\'s name, not its first food', () async {
    final rig = _Rig();
    await rig.setUp();
    await rig.finishPlate();
    final result = rig.controller.lastRecognition!;
    expect(result.displayName(false), 'Chicken Kabsa');
    expect(result.displayName(true), 'كبسة دجاج');
  });

  group('what a plate says about its sources', () {
    test('it stays an estimate while any food is, even if the first came from the catalog', () async {
      final rig = _Rig();
      await rig.setUp();
      await rig.finishPlate();
      final first = rig.controller.lastRecognition!.plateItems.first;
      final food = MiqdarFoodCatalog.builtInFoods.firstWhere((f) => f.verificationStatus != aiEstimateStatus);
      await rig.controller.replacePlateItemFood(first.id, food);
      expect(rig.controller.lastRecognition!.verificationStatus, aiEstimateStatus);
      final meal = (await rig.controller.saveLastRecognition())!;
      expect(meal.verificationStatus, aiEstimateStatus);
    });

    test('it counts as entered by hand once any food\'s grams were typed', () async {
      final rig = _Rig();
      await rig.setUp();
      await rig.finishPlate();
      await rig.controller.setPlateItemWeight(rig.controller.lastRecognition!.plateItems[1].id, 50);
      expect(rig.controller.lastRecognition!.portionSource, PortionSource.manual);
    });

    test('Log Again keeps an estimated amount estimated', () async {
      final rig = _Rig();
      await rig.setUp();
      await rig.finishPlate();
      final meal = (await rig.controller.saveLastRecognition())!;
      final again = await rig.controller.prepareMealAgain(meal.copyWith(items: [
        for (final item in meal.items) item.withWeight(item.weightG, newSource: PortionSource.estimated),
      ]));
      expect(again.plateItems.first.portionSource, PortionSource.estimated);
    });
  });

  test('a photo is fetched again when undo and a new food land on the same reading', () async {
    final rig = _Rig();
    await rig.setUp();
    rig.plate = rig.plateJson([200]);
    (rig.plate!['steps'] as List).first['step_id'] = 'a';
    await rig.controller.syncScaleLive();
    final before = rig.photoFetches;
    rig.plate = rig.plateJson([200]);
    (rig.plate!['steps'] as List).first['step_id'] = 'b';
    await rig.controller.syncScaleLive();
    expect(rig.photoFetches, before + 1);
  });

  test('a plate lost to a scale restart is reported, but a cancelled one is not', () async {
    final rig = _Rig();
    await rig.setUp();
    rig.bootId = 'one';
    rig.plate = rig.plateJson([200]);
    await rig.controller.syncScaleLive();
    rig.plate = null;
    await rig.controller.syncScaleLive();
    expect(rig.controller.plateLostToRestart, isFalse);

    rig.plate = rig.plateJson([200]);
    await rig.controller.syncScaleLive();
    rig.bootId = 'two';
    rig.plate = null;
    await rig.controller.syncScaleLive();
    expect(rig.controller.plateLostToRestart, isTrue);
    rig.controller.dismissPlateLost();
    expect(rig.controller.plateLostToRestart, isFalse);
  });

  test('a food can be entered by hand, keeping its measured grams, with unknowns left unknown', () async {
    final rig = _Rig(geminiStatus: 503);
    await rig.setUp();
    await rig.finishPlate();
    await rig.controller.openPlateForNaming(rig.controller.latestScaleCaptureFailure!.plate!);
    final item = rig.controller.lastRecognition!.plateItems.first;
    await rig.controller.enterPlateItemByHand(item.id, name: 'Home bread', caloriesPer100g: 250);
    final entered = rig.controller.lastRecognition!.plateItems.first;
    expect(entered.nameEn, 'Home bread');
    expect(entered.weightG, 200);
    expect(entered.nutrients.calories, closeTo(500, 0.01));
    expect(entered.nutrients.isMissing('protein_g'), isTrue);
    expect(entered.isUnidentified, isFalse);
  });

  test('a plate named by hand is called after all its foods, but Gemini\'s name for a plate stays', () async {
    final failed = _Rig(geminiStatus: 503);
    await failed.setUp();
    await failed.finishPlate();
    await failed.controller.openPlateForNaming(failed.controller.latestScaleCaptureFailure!.plate!);
    final items = failed.controller.lastRecognition!.plateItems;
    await failed.controller.enterPlateItemByHand(items[0].id, name: 'Home bread', caloriesPer100g: 250);
    expect(failed.controller.lastRecognition!.plateNameEn, 'Home bread');
    await failed.controller.enterPlateItemByHand(items[1].id, name: 'Grilled fish', caloriesPer100g: 250);
    expect(failed.controller.lastRecognition!.plateNameEn, 'Home bread + Grilled fish');

    final named = _Rig();
    await named.setUp();
    await named.finishPlate();
    await named.controller.removePlateItem(named.controller.lastRecognition!.plateItems[1].id);
    expect(named.controller.lastRecognition!.plateNameEn, 'Chicken Kabsa');
  });

  test('Log Again brings back every food', () async {
    final rig = _Rig();
    await rig.setUp();
    await rig.finishPlate();
    final meal = (await rig.controller.saveLastRecognition())!;
    final again = await rig.controller.prepareMealAgain(meal);
    expect(again.plateItems.map((i) => i.nameEn), ['Rice', 'Chicken']);
    expect(again.totalNutrients.calories, closeTo(400, 0.01));
  });

  test('stored meal items come back with their values', () {
    final item = MealItemEntry(
      id: 'i',
      foodId: 'rice',
      nameEn: 'Rice',
      nameAr: 'أرز',
      weightG: 200,
      nutrients: NutritionValues.fromJson(_food('Rice')['per_100g_edible'] as Map<String, dynamic>).forPortionGrams(200),
      basisPer100g: NutritionValues.fromJson(_food('Rice')['per_100g_edible'] as Map<String, dynamic>),
      portionSource: PortionSource.manual,
    );
    final read = MealItemEntry.fromRow(item.toRow('meal', 0));
    expect(read.nutrients.calories, closeTo(200, 0.01));
    expect(read.portionSource, PortionSource.manual);
    expect(read.nameAr, 'أرز');
  });

  group('when Gemini fails', () {
    test('the photos and grams are kept, and asking again does not weigh again', () async {
      final rig = _Rig(geminiStatus: 503);
      await rig.setUp();
      await rig.finishPlate();
      final failure = rig.controller.latestScaleCaptureFailure!;
      expect(failure.canRetry, isTrue);
      expect(failure.plate!.steps.map((s) => s.grams), [200, 100]);
      expect(rig.controller.lastRecognition, isNull);

      rig.geminiStatus = 200;
      final addsBefore = rig.scaleCalls.where((c) => c == 'add').length;
      await rig.controller.retryScaleAnalysis(failure);
      expect(rig.controller.lastRecognition!.totalNutrients.calories, closeTo(400, 0.01));
      expect(rig.scaleCalls.where((c) => c == 'add').length, addsBefore);
    });

    test('running out of quota is reported as such', () async {
      final rig = _Rig(geminiStatus: 429);
      await rig.setUp();
      await rig.finishPlate();
      expect(rig.controller.latestScaleCaptureFailure!.error.code, 'AI_QUOTA_EXCEEDED');
    });

    test('foods can be named by hand, which keeps the measured grams, and saving waits for all of them', () async {
      final rig = _Rig(geminiStatus: 503);
      await rig.setUp();
      await rig.finishPlate();
      await rig.controller.openPlateForNaming(rig.controller.latestScaleCaptureFailure!.plate!);
      var result = rig.controller.lastRecognition!;
      expect(result.plateNeedsNames, isTrue);
      expect(await rig.controller.saveLastRecognition(), isNull);

      rig.geminiStatus = 200;
      rig.answer = {'candidates': [_food('Jareesh', kcal: 120)]};
      await rig.controller.namePlateItem(result.plateItems[0].id, 'jareesh');
      result = rig.controller.lastRecognition!;
      expect(result.plateItems[0].nameEn, 'Jareesh');
      expect(result.plateItems[0].weightG, 200);
      expect(result.plateItems[0].portionSource, PortionSource.scale);
      expect(result.plateItems[0].nutrients.calories, closeTo(240, 0.01));

      final food = MiqdarFoodCatalog.builtInFoods.first;
      await rig.controller.replacePlateItemFood(result.plateItems[1].id, food);
      result = rig.controller.lastRecognition!;
      expect(result.plateItems[1].weightG, 100);
      expect(result.plateItems[1].nutrients.calories, closeTo(food.per100g.calories, 0.01));
      expect(result.plateNeedsNames, isFalse);
      expect(await rig.controller.saveLastRecognition(), isNotNull);
    });

    test('nutrients read as unknown, not zero, until every food has a name', () async {
      final rig = _Rig(geminiStatus: 503);
      await rig.setUp();
      await rig.finishPlate();
      await rig.controller.openPlateForNaming(rig.controller.latestScaleCaptureFailure!.plate!);
      var result = rig.controller.lastRecognition!;
      expect(result.totalNutrients.isMissing('calories_kcal'), isTrue);
      expect(result.totalNutrients.isMissing('protein_g'), isTrue);

      final food = MiqdarFoodCatalog.builtInFoods.first;
      await rig.controller.replacePlateItemFood(result.plateItems[0].id, food);
      result = rig.controller.lastRecognition!;
      expect(result.totalNutrients.isMissing('calories_kcal'), isTrue, reason: 'one food is still unnamed');

      await rig.controller.replacePlateItemFood(result.plateItems[1].id, food);
      expect(rig.controller.lastRecognition!.totalNutrients.isMissing('calories_kcal'), isFalse);
    });

    test('a food Gemini cannot tell stays unnamed while the others keep their answers', () async {
      final rig = _Rig(answer: {
        'meal_name_en': 'Plate',
        'meal_name_ar': 'طبق',
        'foods': [_food('Rice', kcal: 150), _food('not food', kcal: 0, confidence: 0)],
      });
      await rig.setUp();
      await rig.finishPlate();
      final result = rig.controller.lastRecognition!;
      expect(result.plateItems[0].nameEn, 'Rice');
      expect(result.plateItems[1].isUnidentified, isTrue);
      expect(result.plateNeedsNames, isTrue);
    });

    test('an answer missing a food is not trusted', () async {
      final rig = _Rig(answer: {'meal_name_en': 'Plate', 'meal_name_ar': 'طبق', 'foods': [_food('Rice')]});
      await rig.setUp();
      await rig.finishPlate();
      expect(rig.controller.lastRecognition, isNull);
      expect(rig.controller.latestScaleCaptureFailure, isNotNull);
    });
  });

  test('a refusal from the scale reaches the screen with its code', () async {
    final rig = _Rig();
    await rig.setUp();
    rig.refusal = {'error': 'PLATE_STEP_TOO_SMALL', 'message': 'Only 3 g'};
    await expectLater(
      rig.controller.plateAction('add'),
      throwsA(isA<RecognitionException>().having((e) => e.code, 'code', 'PLATE_STEP_TOO_SMALL')),
    );
    expect(rig.controller.plateBusy, isFalse);
  });

  group('describing food in words', () {
    GeminiNutritionService service(Map<String, dynamic> answer, List<String> bodies) {
      final client = MockClient((request) async {
        bodies.add(request.body);
        return _gemini(answer);
      });
      return GeminiNutritionService(apiKey: 'k', models: const ['m'], client: client);
    }

    test('without a weight, the amount is Gemini\'s and is marked as estimated', () async {
      final bodies = <String>[];
      final result = await service({'estimated_grams': 250, 'candidates': [_food('Kabsa', kcal: 180)]}, bodies)
          .analyzeDescription(description: 'half a plate of kabsa');
      expect(result.weightG, 250);
      expect(result.portionSource, PortionSource.estimated);
      expect(result.nutrients.calories, closeTo(450, 0.01));
      expect(bodies.single, contains('half a plate of kabsa'));
      expect(bodies.single, isNot(contains('inline_data')));
    });

    test('an optional photo goes with the words', () async {
      final bodies = <String>[];
      await service({'estimated_grams': 100, 'candidates': [_food('Kabsa')]}, bodies).analyzeDescription(
        description: 'kabsa',
        photo: Uint8List.fromList([0xFF, 0xD8, 1]),
      );
      expect(bodies.single, contains('inline_data'));
    });

    test('a meal logged this way reaches Review marked as estimated, and nothing is saved', () async {
      final rig = _Rig(answer: {'estimated_grams': 300, 'candidates': [_food('Kabsa', kcal: 180)]});
      await rig.setUp();
      final result = await rig.controller.logEstimatedMeal(description: 'kabsa');
      expect(rig.controller.lastRecognition, same(result));
      expect(result.portionSource, PortionSource.estimated);
      expect(rig.controller.meals, isEmpty);
    });

    test('a photo alone is enough', () async {
      final bodies = <String>[];
      final result = await service({'estimated_grams': 150, 'candidates': [_food('Kabsa')]}, bodies).analyzeDescription(
        description: '',
        photo: Uint8List.fromList([0xFF, 0xD8, 1]),
      );
      expect(result.portionSource, PortionSource.estimated);
      expect(result.weightG, 150);
    });

    test('an answer with no amount is not trusted', () async {
      await expectLater(
        service({'candidates': [_food('Kabsa')]}, []).analyzeDescription(description: 'kabsa'),
        throwsA(isA<RecognitionException>().having((e) => e.code, 'code', 'AI_PROVIDER_UNAVAILABLE')),
      );
    });

    test('words that are not food are reported', () async {
      await expectLater(
        service({'estimated_grams': 0, 'candidates': [_food('not food', kcal: 0)]}, []).analyzeDescription(
          description: 'hello',
        ),
        throwsA(isA<RecognitionException>().having((e) => e.code, 'code', 'NOT_FOOD')),
      );
    });
  });
}
