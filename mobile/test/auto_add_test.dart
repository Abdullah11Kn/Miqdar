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

Map<String, dynamic> _food(String name, double kcal) => {
      'name_en': name,
      'name_ar': name,
      'confidence': 0.9,
      'edible_fraction': 1.0,
      'per_100g_edible': {
        'calories_kcal': kcal, 'protein_g': 5.0, 'carbohydrate_g': 20.0, 'fat_g': 4.0,
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

/// A pretend scale that behaves like app.py: each added step is the weight added since the last one.
class _Scale {
  double weight = 0;
  bool stable = true;
  List<Map<String, dynamic>>? steps; // null: no plate
  bool finished = false;
  final calls = <String>[];
  final geminiBodies = <String>[];
  DateTime now = DateTime(2026, 11, 15, 13);
  late final MiqdarController controller;

  Map<String, dynamic>? get plateJson => steps == null
      ? null
      : {'plate_id': 'plate-1', 'state': finished ? 'finished' : 'open', 'steps': steps};

  double get lastReading => steps == null || steps!.isEmpty ? 0 : (steps!.last['reading_g'] as num).toDouble();

  void _addStep() {
    steps ??= [];
    steps!.add({
      'index': steps!.length,
      'step_id': 's${calls.length}',
      'grams': weight - lastReading,
      'reading_g': weight,
    });
  }

  Future<void> setUp() async {
    final client = MockClient((request) async {
      if (request.url.host.contains('googleapis') && request.method == 'GET') return http.Response('', 404); // warm-up
      if (request.url.host.contains('googleapis')) {
        geminiBodies.add(request.body);
        return _gemini(request.body.contains('one food at a time')
            ? {
                'meal_name_en': 'Chicken with rice',
                'meal_name_ar': 'دجاج مع رز',
                'foods': [_food('Rice', 130), _food('Chicken', 200)],
              }
            : {'candidates': [_food('Rice', 130)]});
      }
      final path = request.url.path;
      if (path == '/scale/live') {
        return http.Response(
            jsonEncode({'mode': 'real', 'live_weight_g': weight, 'is_stable': stable, 'plate': plateJson, 'boot_id': 'b'}),
            200);
      }
      if (path == '/scale/plate/photo') {
        return http.Response(jsonEncode({'image_base64': base64Encode(Uint8List.fromList([0xFF, 0xD8, 9]))}), 200);
      }
      if (path.startsWith('/scale/plate/')) {
        final action = path.split('/').last;
        calls.add(action);
        final added = weight - lastReading;
        if (action == 'add') {
          if (added < 5) return http.Response(jsonEncode({'error': 'PLATE_STEP_TOO_SMALL', 'message': 'small'}), 422);
          _addStep();
        } else if (action == 'finish') {
          if (added >= 5) _addStep();
          finished = true;
        } else if (action == 'undo') {
          steps!.removeLast();
          if (steps!.isEmpty) steps = null;
        } else if (action == 'cancel') {
          steps = null;
          finished = false;
        }
        return http.Response(jsonEncode({'plate': plateJson}), 200);
      }
      if (path == '/scale/tare') return http.Response(jsonEncode({'ok': true}), 200);
      return http.Response('{}', 200);
    });
    final database = LocalDatabase();
    await database.initialize();
    controller = MiqdarController(
      localDatabase: database,
      apiService: ApiService(
        baseUrl: 'http://scale.test',
        client: client,
        gemini: GeminiNutritionService(apiKey: 'test-key', models: const ['m'], client: client),
      ),
      alertService: AlertService(),
      barcodeReader: const NoBarcodeReader(),
    )..clock = () => now;
    controller.signIn(email: '');
    controller.setAutoAddWatching(true);
  }

  /// Polls as the app does, every half second, for [seconds].
  Future<void> wait(double seconds) async {
    for (var t = 0.0; t < seconds; t += 0.5) {
      await controller.syncScaleLive();
      await pumpEventQueue();
      now = now.add(const Duration(milliseconds: 500));
    }
    await controller.syncScaleLive();
    await pumpEventQueue();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('food that rests on the plate for 5 seconds is weighed and photographed by itself', () async {
    final scale = _Scale();
    await scale.setUp();
    scale.weight = 200;
    await scale.wait(4);
    expect(scale.calls, isEmpty, reason: 'not before 5 seconds');
    await scale.wait(1.5);
    expect(scale.calls, ['add']);
    expect(scale.controller.scalePlate!.steps.single.grams, 200);
    await scale.wait(10);
    expect(scale.calls, ['add'], reason: 'a resting plate is recorded once');
    expect(scale.geminiBodies, isEmpty, reason: 'Gemini waits for Done');
  });

  test('a second food of 20 g or more is recorded as its own step, with only its added grams', () async {
    final scale = _Scale();
    await scale.setUp();
    scale.weight = 200;
    await scale.wait(6);
    scale.weight = 230;
    await scale.wait(6);
    expect(scale.calls, ['add', 'add']);
    expect(scale.controller.scalePlate!.steps.map((s) => s.grams), [200, 30]);
  });

  test('less than 20 g added is not a new food', () async {
    final scale = _Scale();
    await scale.setUp();
    scale.weight = 200;
    await scale.wait(6);
    scale.weight = 215;
    await scale.wait(10);
    expect(scale.calls, ['add']);
  });

  test('nothing is recorded while the weight keeps moving', () async {
    final scale = _Scale();
    await scale.setUp();
    for (var i = 0; i < 20; i++) {
      scale.weight = 200 + (i.isEven ? 0 : 15);
      await scale.wait(0.5);
    }
    expect(scale.calls, isEmpty);
    scale.stable = false;
    scale.weight = 200;
    await scale.wait(10);
    expect(scale.calls, isEmpty, reason: 'the scale itself says unsteady');
  });

  test('Done sends every photo in one Gemini request and shows the whole meal', () async {
    final scale = _Scale();
    await scale.setUp();
    scale.weight = 200;
    await scale.wait(6);
    scale.weight = 230;
    await scale.wait(6);
    await scale.controller.plateAction('finish');
    await scale.wait(1);
    expect(scale.geminiBodies, hasLength(1));
    final result = scale.controller.lastRecognition!;
    expect(result.plateNameEn, 'Chicken with rice');
    expect(result.plateItems.map((i) => i.weightG), [200, 30]);
  });

  test('a single food goes through the normal single-food analysis', () async {
    final scale = _Scale();
    await scale.setUp();
    scale.weight = 200;
    await scale.wait(6);
    await scale.controller.plateAction('finish');
    await scale.wait(1);
    expect(scale.geminiBodies, hasLength(1));
    expect(scale.geminiBodies.single, isNot(contains('one food at a time')));
    final result = scale.controller.lastRecognition!;
    expect(result.isPlate, isFalse);
    expect(result.weightG, 200);
  });

  test('after Done the food still on the scale is not recorded again until the plate is cleared', () async {
    final scale = _Scale();
    await scale.setUp();
    scale.weight = 200;
    await scale.wait(6);
    await scale.controller.plateAction('finish');
    await scale.wait(10);
    expect(scale.calls, ['add', 'finish', 'cancel']);
    expect(scale.controller.autoAddWaitingForClear, isTrue);
    scale.controller.clearExternalScaleCapture(); // Review opened it, as the app does
    scale.weight = 0;
    await scale.wait(1);
    expect(scale.controller.autoAddWaitingForClear, isFalse);
    scale.weight = 150;
    await scale.wait(6);
    expect(scale.calls.last, 'add');
  });

  test('after Undo the same food is not recorded again unless the weight changes', () async {
    final scale = _Scale();
    await scale.setUp();
    scale.weight = 200;
    await scale.wait(6);
    await scale.controller.plateAction('undo');
    await scale.wait(10);
    expect(scale.calls, ['add', 'undo']);
    scale.weight = 260;
    await scale.wait(6);
    expect(scale.calls, ['add', 'undo', 'add']);
  });

  test('it watches only while Add Meal is on screen and the switch is on', () async {
    final scale = _Scale();
    await scale.setUp();
    scale.controller.setAutoAddWatching(false);
    scale.weight = 200;
    await scale.wait(10);
    expect(scale.calls, isEmpty);
    scale.controller.setAutoAddWatching(true);
    await scale.controller.setAutoAdd(false);
    await scale.wait(10);
    expect(scale.calls, isEmpty);
    await scale.controller.setAutoAdd(true);
    await scale.wait(6);
    expect(scale.calls, ['add']);
  });

  test('a hidden Add Meal does not switch detection off for the one on screen', () async {
    final scale = _Scale();
    await scale.setUp();
    scale.controller.setAutoAddWatching(true, owner: 'shown');
    scale.controller.setAutoAddWatching(false, owner: 'hidden tab');
    scale.controller.setAutoAddWatching(false); // the rig's own watcher
    scale.weight = 200;
    await scale.wait(6);
    expect(scale.calls, ['add']);
  });

  test('the countdown runs from 0 to 1 while a food settles', () async {
    final scale = _Scale();
    await scale.setUp();
    expect(scale.controller.autoAddProgress, isNull);
    scale.weight = 200;
    await scale.wait(2.5);
    final p = scale.controller.autoAddProgress!;
    expect(p, greaterThan(0.3));
    expect(p, lessThan(0.7));
  });
}
