import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miqdar_mobile/app_controller.dart';
import 'package:miqdar_mobile/data/local_database.dart';
import 'package:miqdar_mobile/services/alert_service.dart';
import 'package:miqdar_mobile/services/api_service.dart';

const _photo = 'AQID';

Map<String, dynamic> _liveBody({Map<String, dynamic>? capture, double grams = 200}) => {
      'mode': 'real',
      'live_weight_g': grams,
      'is_stable': true,
      'capture_state': 'idle',
      'auto_capture': true,
      'latest_capture': capture,
    };

Map<String, dynamic> _event(String id, {double ageS = 1}) => {
      'event_id': id,
      'status': 'ok',
      'age_s': ageS,
      'weight_g': 200.0,
      'confidence': 0.9,
      'food': {'food_id': 'F1', 'name_en': 'White Rice', 'name_ar': 'أرز', 'verification_status': 'reference_seed'},
      'nutrients': {
        'calories_kcal': 100.0, 'protein_g': 1.0, 'carbohydrate_g': 20.0, 'fat_g': 0.5,
        'sugar_g': 0.0, 'fiber_g': 0.0, 'sodium_mg': 1.0, 'potassium_mg': 1.0,
      },
      'candidates': <dynamic>[],
    };

class _Harness {
  _Harness() {
    controller = MiqdarController(
      localDatabase: LocalDatabase(),
      apiService: ApiService(
        baseUrl: 'http://scale.test',
        client: MockClient((request) async {
          requests.add(request);
          return handler(request);
        }),
      ),
      alertService: AlertService(),
    );
  }

  late final MiqdarController controller;
  final requests = <http.Request>[];
  late Future<http.Response> Function(http.Request) handler;

  int count(String path) => requests.where((r) => r.url.path == path).length;
}

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  test('a new capture downloads its photo once and survives further polls', () async {
    final h = _Harness();
    h.handler = (r) async => r.url.path == '/scale/live'
        ? _json(_liveBody(capture: _event('cap-1')))
        : _json({..._event('cap-1'), 'image_base64': _photo});

    await h.controller.syncScaleLive();
    await h.controller.syncScaleLive();

    expect(h.count('/scale/capture/latest'), 1);
    expect(h.controller.scaleDevice.online, isTrue);
    expect(h.controller.scaleDevice.liveWeightG, 200);
    final capture = h.controller.latestExternalScaleCapture!;
    expect(capture.eventId, 'cap-1');
    expect(capture.imageBytes, [1, 2, 3]);
    expect(capture.nutrients.calories, 100);
  });

  test('a capture from before the app opened does not pop up', () async {
    final h = _Harness();
    h.handler = (r) async => _json(_liveBody(capture: _event('cap-old', ageS: 3600)));

    await h.controller.syncScaleLive();

    expect(h.count('/scale/capture/latest'), 0);
    expect(h.controller.latestExternalScaleCapture, isNull);
  });

  test('a failed capture surfaces its reason and photo', () async {
    final h = _Harness();
    final failed = {
      'event_id': 'cap-2', 'status': 'error', 'age_s': 1, 'weight_g': 150.0,
      'error': 'FOOD_NOT_IN_DATABASE', 'message': 'Not mapped',
      'candidates': [{'label': 'lobster', 'confidence': 0.8}],
    };
    h.handler = (r) async => r.url.path == '/scale/live'
        ? _json(_liveBody(capture: failed))
        : _json({...failed, 'image_base64': _photo});

    await h.controller.syncScaleLive();

    final failure = h.controller.latestScaleCaptureFailure!;
    expect(failure.error.code, 'FOOD_NOT_IN_DATABASE');
    expect(failure.error.candidates, ['lobster']);
    expect(failure.imageBytes, [1, 2, 3]);
    expect(h.controller.latestExternalScaleCapture, isNull);
  });

  test('a photo download failure retries on the next poll', () async {
    final h = _Harness();
    var downloads = 0;
    h.handler = (r) async {
      if (r.url.path == '/scale/live') return _json(_liveBody(capture: _event('cap-3')));
      if (r.url.path != '/scale/capture/latest') return _json({'status': 'ok'});
      downloads++;
      if (downloads == 1) return http.Response('oops', 500);
      return _json({..._event('cap-3'), 'image_base64': _photo});
    };

    await h.controller.syncScaleLive();
    expect(h.controller.latestExternalScaleCapture, isNull);
    await h.controller.syncScaleLive();
    expect(h.controller.latestExternalScaleCapture?.eventId, 'cap-3');
  });

  test('phone capture asks for a draft and is not applied twice by the poll', () async {
    final h = _Harness();
    h.handler = (r) async {
      if (r.url.path == '/scale/capture') return _json({..._event('cap-4'), 'image_base64': _photo});
      return _json(_liveBody(capture: _event('cap-4')));
    };

    final result = (await h.controller.captureFromScale())!;
    final applied = h.controller.latestExternalScaleCapture;
    await h.controller.syncScaleLive();

    final body = jsonDecode(h.requests.first.body) as Map<String, dynamic>;
    expect(body['save'], isFalse);
    expect(result.eventId, 'cap-4');
    expect(identical(h.controller.latestExternalScaleCapture, applied), isTrue);
    expect(h.count('/scale/capture/latest'), 0);
    expect(h.controller.busy, isFalse);
  });

  test('capture errors keep the code from the scale', () async {
    final h = _Harness();
    h.handler = (r) async => _json({'error': 'CAMERA_UNAVAILABLE', 'message': 'No camera'}, 503);

    await expectLater(
      h.controller.captureFromScale(),
      throwsA(isA<RecognitionException>().having((e) => e.code, 'code', 'CAMERA_UNAVAILABLE')),
    );
  });

  test('one lost poll is tolerated, a run of them is offline with a useful reason', () async {
    final h = _Harness();
    h.handler = (r) async => _json(_liveBody());
    await h.controller.syncScaleLive();
    await Future<void>.delayed(const Duration(milliseconds: 20)); // reconnect's /health recheck
    expect(h.controller.scaleDevice.online, isTrue);

    h.handler = (r) async => http.Response('error code: 1033', 530);
    await h.controller.syncScaleLive();
    expect(h.controller.scaleDevice.online, isTrue);
    await h.controller.syncScaleLive();
    await h.controller.syncScaleLive();
    expect(h.controller.scaleDevice.online, isFalse);
    expect(h.controller.scaleConnectionIssue, contains('tunnel URL'));
  });

  test('a scale that cannot zero is reported, not faked', () async {
    final h = _Harness();
    h.handler = (r) async => r.url.path == '/scale/tare'
        ? _json({'success': false})
        : _json(_liveBody());
    await h.controller.syncScaleLive();

    expect(await h.controller.tareScale(), isFalse);
    expect(h.controller.scaleDevice.liveWeightG, 200);
  });
}
