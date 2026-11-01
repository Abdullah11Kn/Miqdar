// End-to-end check of the scale flow in the real app, against a running scale API in
// simulation mode:
//
//   ../start_scale_app.sh --headless --mock --auto-capture                  (freshly started, in another terminal)
//   flutter test integration_test/scale_flow_test.dart -d <simulator id> \
//     --dart-define=GEMINI_API_KEY=<key>
//
// Add --dart-define=MIQDAR_API_URL=<url> to run it through a tunnel instead of localhost.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:miqdar_mobile/app.dart';
import 'package:miqdar_mobile/app_controller.dart';
import 'package:miqdar_mobile/data/local_database.dart';
import 'package:miqdar_mobile/models/nutrition.dart';
import 'package:miqdar_mobile/services/alert_service.dart';
import 'package:miqdar_mobile/services/api_service.dart';
import 'package:miqdar_mobile/ui/screens.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('food on the plate reaches the review screen with photo and calories', (tester) async {
    final api = ApiService();
    final controller = MiqdarController(
      localDatabase: LocalDatabase(),
      apiService: api,
      alertService: AlertService(),
    );

    Future<void> placeFood(double grams, String sample) => http.post(
          Uri.parse('${api.baseUrl}/scale/simulate'),
          body: jsonEncode({'weight_g': grams, 'sample': sample}),
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

    await placeFood(0, 'jareesh');
    await controller.initialize();
    await tester.pumpWidget(MiqdarApp(controller: controller));

    await pumpUntil(() => find.text('Get Started').evaluate().isNotEmpty || find.byType(MainShell).evaluate().isNotEmpty);
    await hold(1);
    if (find.text('Get Started').evaluate().isNotEmpty) await tester.tap(find.text('Get Started').first);
    await pumpUntil(() => find.byType(MainShell).evaluate().isNotEmpty);

    // The scale connects and reports its true state.
    await pumpUntil(() => controller.scaleDevice.online && controller.scaleDevice.liveWeightG == 0);
    expect(controller.scaleDevice.simulated, isTrue);
    await tester.tap(find.text('Add Meal').last);
    await hold(2);

    // The live weight follows the plate before any capture happens.
    await placeFood(240, 'jareesh');
    await pumpUntil(() => (controller.scaleDevice.liveWeightG - 240).abs() < 1, seconds: 5);
    await hold(1);

    // Auto-capture opens the review screen with no tap.
    await pumpUntil(() => find.byType(RecognitionResultScreen).evaluate().isNotEmpty);
    await hold(1);
    expect(find.byType(RecognitionResultScreen), findsOneWidget);
    final result = controller.lastRecognition!;
    expect(result.nameEn.toLowerCase(), contains('jareesh'));
    expect(result.verificationStatus, aiEstimateStatus);
    expect(result.imageBytes, isNotNull);
    expect(result.nutrients.calories, closeTo(result.resolvedBasisPer100g.calories * result.weightG / 100, 0.5));
    expect(result.weightG, closeTo(240, 1));
    debugPrint('E2E: ${result.nameEn} ${result.weightG} g ${result.nutrients.calories} kcal');
    await hold(6);

    // Saving logs it once, and a plate still resting there does not capture again.
    final meals = controller.meals.length;
    await tester.dragUntilVisible(
      find.text('Confirm & Save Meal to Diary'),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    expect(find.text('Gemini AI Estimate — Not a Verified Record'), findsOneWidget);
    await tester.tap(find.text('Confirm & Save Meal to Diary'));
    await pumpUntil(() => controller.meals.length == meals + 1, seconds: 10);
    await hold(4);
    expect(find.byType(RecognitionResultScreen), findsNothing);
    expect(controller.meals.first.nameEn.toLowerCase(), contains('jareesh'));

    await placeFood(0, 'jareesh');
    await hold(2);
  });
}
