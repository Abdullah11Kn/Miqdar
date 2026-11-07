// End-to-end check of Weigh What's Left against a running scale API in simulation mode:
//
//   ../start_scale_app.sh --headless --mock                  (freshly started, in another terminal)
//   flutter test integration_test/leftovers_flow_test.dart -d <simulator id>
//
// Needs no Gemini key. Run it on a throwaway simulator: installing the test wipes the app's saved meals.
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

  testWidgets('leftovers weighed in a container come off the meal and show in Insights', (tester) async {
    final api = ApiService();
    final controller = MiqdarController(
      localDatabase: LocalDatabase(),
      apiService: api,
      alertService: AlertService(),
    );

    Future<void> pumpUntil(bool Function() done, {int seconds = 30}) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (!done()) {
        if (DateTime.now().isAfter(end)) fail('Timed out after $seconds s');
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> simulate(double grams) => http.post(
          Uri.parse('${api.baseUrl}/scale/simulate'),
          body: jsonEncode({'weight_g': grams, 'sample': 'jareesh'}),
        );

    await controller.initialize();
    await controller.deleteAllData();
    await tester.pumpWidget(MiqdarApp(controller: controller));
    await pumpUntil(() => find.text('Get Started').evaluate().isNotEmpty);
    await tester.tap(find.text('Get Started').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip').first);
    await pumpUntil(() => find.byType(MainShell).evaluate().length == 1);
    await pumpUntil(() => controller.scaleDevice.online);

    final meal = MealEntry(
      id: 'leftovers-test',
      foodId: 'gemini-jareesh',
      nameEn: 'Jareesh',
      nameAr: 'جريش',
      eatenAt: DateTime.now(),
      mealType: 'Lunch',
      weightG: 240,
      confidence: 0.9,
      nutrients: const NutritionValues(
          calories: 336, protein: 10, carbohydrates: 60, fat: 7, sugar: 1, fiber: 2, sodium: 100, potassium: 100),
    );
    await controller.localDatabase.insertMealEntry(meal);
    controller.meals = [meal];

    Navigator.of(tester.element(find.byType(MainShell))).push(
      MaterialPageRoute<void>(builder: (_) => MealDetailScreen(meal: meal)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("Weigh What's Left"));
    await tester.pumpAndSettle();

    // The empty container goes on and is zeroed.
    await simulate(150);
    await pumpUntil(() => (controller.scaleDevice.liveWeightG - 150).abs() < 1);
    await tester.tap(find.text('Zero'));
    await pumpUntil(() => find.textContaining('put the leftovers').evaluate().isNotEmpty);

    // 60 g of leftovers. The simulated scale takes net weights and resets its zero on each one,
    // so the net 60 g is set directly; the real scale keeps the container zeroed.
    await simulate(60);
    await pumpUntil(() => find.text('Save 60 g Left').evaluate().isNotEmpty, seconds: 15);
    await tester.tap(find.text('Save 60 g Left'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Left 60 g'), findsOneWidget);
    expect(controller.todayTotals.calories, closeTo(252, 0.5));
    final stored = (await controller.localDatabase.loadMeals()).single;
    expect(stored.leftover!.grams, 60);
    expect(stored.servedNutrients.calories, 336);
    expect(MiqdarController.notEaten(controller.meals).values.calories, closeTo(84, 0.5));

    await simulate(0);
  });
}
