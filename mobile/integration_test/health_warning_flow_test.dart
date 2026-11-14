// End-to-end check of the red health warning (issue #26) in the real app. Needs no scale or Gemini:
// the meal is entered by hand. Run it on a throwaway simulator only, never on Abdullah's own:
//
//   flutter test integration_test/health_warning_flow_test.dart -d <throwaway simulator id>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:miqdar_mobile/app.dart';
import 'package:miqdar_mobile/app_controller.dart';
import 'package:miqdar_mobile/data/local_database.dart';
import 'package:miqdar_mobile/models/diabetes.dart';
import 'package:miqdar_mobile/services/alert_service.dart';
import 'package:miqdar_mobile/services/api_service.dart';
import 'package:miqdar_mobile/theme.dart';
import 'package:miqdar_mobile/ui/screens.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a sweet meal in diabetes mode warns in red before Save, then in the bell and on Home', (tester) async {
    final controller = MiqdarController(
      localDatabase: LocalDatabase(),
      apiService: ApiService(baseUrl: 'http://127.0.0.1:9'),
      alertService: AlertService(),
    );

    Future<void> pumpUntil(bool Function() done, {int seconds = 30}) async {
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

    await controller.initialize();
    await tester.pumpWidget(MiqdarApp(controller: controller));
    await pumpUntil(() => find.text('Get Started').evaluate().isNotEmpty || find.byType(MainShell).evaluate().isNotEmpty);
    if (find.text('Get Started').evaluate().isNotEmpty) {
      await tester.tap(find.text('Get Started').first);
      await hold(2);
    }
    if (find.text('Skip').evaluate().isNotEmpty) await tester.tap(find.text('Skip').first);
    await pumpUntil(() => find.byType(MainShell).evaluate().length == 1);

    await controller.updateDiabetes(const DiabetesSettings(hasDiabetes: true, type: DiabetesType.type2));
    final kunafa = controller.createCustomFood(nameEn: 'Kunafa', basisGrams: 100, calories: 400, carbs: 50, sugar: 30);
    final result = await controller.prepareCatalogDraft(food: kunafa, weightG: 200);

    Navigator.of(tester.element(find.byType(MainShell))).push(
      MaterialPageRoute(builder: (_) => RecognitionResultScreen(result: result)),
    );
    await hold(2);

    // Before eating: the red card, with the smaller portion.
    expect(find.text('Before you eat', skipOffstage: false), findsWidgets);
    expect(find.textContaining('Over your sugar limit', skipOffstage: false), findsWidgets);
    final warning = controller.projectedAlerts.firstWhere((a) => a.nutrientKey == 'sugar_g').message;
    debugPrint('E2E warning: $warning (sugar earlier today: ${controller.todayTotals.sugar} g)');
    if (controller.todayTotals.sugar < controller.goals.sugar) {
      expect(find.textContaining('g keeps you within', skipOffstage: false), findsWidgets);
    }

    // Saving anyway puts the warning in the bell.
    await tester.tap(find.text('Save to Diary'));
    await pumpUntil(() => controller.meals.isNotEmpty, seconds: 10);
    await hold(2);
    expect(controller.alerts.where((a) => !a.read && a.nutrientKey == 'sugar_g'), isNotEmpty);

    // On Home the sugar bar is red.
    await pumpUntil(() => find.byType(RecognitionResultScreen).evaluate().isEmpty);
    final danger = tester.element(find.byType(MainShell)).mq.danger;
    final bars = tester.widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bars.where((b) => b.color == danger), isNotEmpty);
  });
}
