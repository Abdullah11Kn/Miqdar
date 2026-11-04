// End-to-end check of Save to Diary on the scale's touchscreen, against a running scale API in
// simulation mode. A simulation route stands in for the tap, because a headless scale has no screen:
//
//   ../start_scale_app.sh --headless --mock                  (freshly started, in another terminal)
//   flutter test integration_test/scale_save_test.dart -d <simulator id> \
//     --dart-define=GEMINI_API_KEY=<key>
//
// Run it on a throwaway simulator: installing the test wipes the app's saved meals.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:miqdar_mobile/app.dart';
import 'package:miqdar_mobile/app_controller.dart';
import 'package:miqdar_mobile/data/local_database.dart';
import 'package:miqdar_mobile/services/alert_service.dart';
import 'package:miqdar_mobile/services/api_service.dart';
import 'package:miqdar_mobile/ui/screens.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Save on the scale saves the open review once and tells the scale', (tester) async {
    final api = ApiService();
    final controller = MiqdarController(
      localDatabase: LocalDatabase(),
      apiService: api,
      alertService: AlertService(),
    );

    Future<void> pumpUntil(bool Function() done, {int seconds = 60}) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (!done()) {
        if (DateTime.now().isAfter(end)) fail('Timed out after $seconds s');
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> hold(int seconds) async {
      for (var i = 0; i < seconds * 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<http.Response> post(String path, [Object? body]) =>
        http.post(Uri.parse('${api.baseUrl}$path'), body: jsonEncode(body ?? {}));

    await controller.initialize();
    await controller.deleteAllData();
    await tester.pumpWidget(MiqdarApp(controller: controller));
    await pumpUntil(() => find.text('Get Started').evaluate().isNotEmpty);
    await hold(1);
    await tester.tap(find.text('Get Started').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip').first);
    await pumpUntil(() => find.byType(MainShell).evaluate().length == 1);
    await pumpUntil(() => controller.scaleDevice.online);

    await post('/scale/simulate', {'weight_g': 240, 'sample': 'jareesh'});
    await pumpUntil(() => (controller.scaleDevice.liveWeightG - 240).abs() < 1, seconds: 5);
    await post('/scale/capture');
    await pumpUntil(() => find.byType(RecognitionResultScreen).evaluate().isNotEmpty);
    await hold(1);
    expect(controller.meals, isEmpty);

    await post('/scale/simulate/save');
    await pumpUntil(() => controller.meals.isNotEmpty, seconds: 10);
    await hold(3);

    // Saved once, read back from the real database, and the review closed itself.
    expect(controller.meals, hasLength(1));
    expect(find.byType(RecognitionResultScreen), findsNothing);
    expect(find.textContaining('Saved:'), findsOneWidget);
    final stored = await controller.localDatabase.loadMeals();
    expect(stored, hasLength(1));

    // The scale heard the answer, so its request is gone.
    final live = jsonDecode((await http.get(Uri.parse('${api.baseUrl}/scale/live'))).body) as Map<String, dynamic>;
    expect(live['save_request'], isNull);
    await post('/scale/simulate', {'weight_g': 0, 'sample': 'jareesh'});
  });
}
