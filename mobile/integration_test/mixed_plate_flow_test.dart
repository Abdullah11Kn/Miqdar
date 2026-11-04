// End-to-end check of a mixed plate in the real app, against a running scale API in simulation mode:
//
//   ../start_scale_app.sh --headless --mock                  (freshly started, in another terminal)
//   flutter test integration_test/mixed_plate_flow_test.dart -d <simulator id> \
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

  testWidgets('foods added one at a time on the scale save as one meal', (tester) async {
    final api = ApiService();
    final controller = MiqdarController(
      localDatabase: LocalDatabase(),
      apiService: api,
      alertService: AlertService(),
    );

    Future<void> placeFood(double grams, String sample) => http.post(
          Uri.parse('${api.baseUrl}/scale/simulate'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'weight_g': grams, 'sample': sample}),
        );

    Future<void> hold(int seconds) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pumpUntil(bool Function() done, {int seconds = 70}) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (!done()) {
        if (DateTime.now().isAfter(end)) fail('Timed out waiting for the next step of the plate');
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> shot(String name) async {
      await hold(1);
      // ignore: avoid_print
      print('SHOT:$name');
      await hold(2);
    }

    await placeFood(0, 'kabsa');
    await controller.initialize();
    await controller.deleteAllData();
    await tester.pumpWidget(MiqdarApp(controller: controller));
    await pumpUntil(() => find.text('Get Started').evaluate().isNotEmpty);
    await hold(1);
    await tester.tap(find.text('Get Started').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip').first);
    await pumpUntil(() => find.byType(MainShell).evaluate().isNotEmpty);
    await hold(1);
    await tester.tap(find.text('Add Meal').last);
    await pumpUntil(() => controller.scaleDevice.online);

    await placeFood(200, 'kabsa');
    await hold(2);
    await shot('plate_start');
    await tester.tap(find.text('Add Next Food'));
    await pumpUntil(() => controller.scalePlate?.steps.length == 1 && !controller.plateBusy);
    await hold(1);
    expect(find.text('Finish'), findsOneWidget);
    await shot('plate_one');

    // Too little added is refused and changes nothing.
    await placeFood(202, 'kabsa');
    await hold(1);
    await tester.tap(find.text('Add Next Food'));
    await pumpUntil(() => !controller.plateBusy);
    await hold(1);
    expect(controller.scalePlate!.steps, hasLength(1));

    await placeFood(320, 'jareesh');
    await hold(1);
    await tester.tap(find.text('Finish'));
    await pumpUntil(() => find.byType(RecognitionResultScreen).evaluate().isNotEmpty);
    await hold(1);
    final result = controller.lastRecognition!;
    expect(result.isPlate, isTrue);
    expect(result.plateItems, hasLength(2));
    expect(result.plateItems[0].weightG, closeTo(200, 2));
    expect(result.plateItems[1].weightG, closeTo(120, 3));
    expect(find.text('On this plate'), findsOneWidget);
    // ignore: avoid_print
    print('PLATE:${result.plateNameEn}|${result.plateItems.map((i) => '${i.nameEn} ${i.weightG}g ${i.nutrients.calories.round()}kcal').join('; ')}');
    await shot('plate_review');

    if (!result.plateNeedsNames) {
      await tester.tap(find.text('Save to Diary'));
      await pumpUntil(() => find.byType(MainShell).evaluate().isNotEmpty);
      await hold(1);
      await shot('plate_saved');
      expect(controller.meals, hasLength(1));
      final meal = controller.meals.single;
      expect(meal.items, hasLength(2));

      // Read back from the real database, as after a restart.
      final reloaded = await controller.localDatabase.loadMeals();
      expect(reloaded.single.items, hasLength(2));
      expect(reloaded.single.weightG, closeTo(320, 3));
      // ignore: avoid_print
      print('RELOAD_OK:${reloaded.single.nameEn}');
    }
    await controller.deleteAllData();
  });
}
