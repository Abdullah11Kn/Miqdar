// End-to-end check of Capture on the floating scale bar, from Home, against a running scale API
// in simulation mode, without automatic capture:
//
//   ../start_scale_app.sh --headless --mock                                  (freshly started, in another terminal)
//   flutter test integration_test/scale_bar_capture_test.dart -d <simulator id> \
//     --dart-define=GEMINI_API_KEY=<key>
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

  testWidgets('Capture on the scale bar opens the review screen from another tab', (tester) async {
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

    Future<void> placeFood(double grams) => http.post(
          Uri.parse('${api.baseUrl}/scale/simulate'),
          body: jsonEncode({'weight_g': grams, 'sample': 'jareesh'}),
        );

    await placeFood(0);
    await controller.initialize();
    await tester.pumpWidget(MiqdarApp(controller: controller));
    await pumpUntil(() => find.text('Get Started').evaluate().isNotEmpty || find.byType(MainShell).evaluate().isNotEmpty);
    if (find.text('Get Started').evaluate().isNotEmpty) {
      await tester.tap(find.text('Get Started').first);
      await tester.pumpAndSettle();
    }
    if (find.text('Skip').evaluate().isNotEmpty) await tester.tap(find.text('Skip').first);
    await pumpUntil(() => find.byType(MainShell).evaluate().length == 1);

    // Add Meal is not open: the bar is what shows the scale here.
    await pumpUntil(() => controller.scaleDevice.online);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byTooltip('Capture'), findsOneWidget);

    await placeFood(240);
    await pumpUntil(() => (controller.scaleDevice.liveWeightG - 240).abs() < 1, seconds: 5);
    await tester.tap(find.byTooltip('Capture'));

    await pumpUntil(() => find.byType(RecognitionResultScreen).evaluate().isNotEmpty);
    await tester.pump(const Duration(seconds: 1));
    final result = controller.lastRecognition!;
    expect(result.nameEn, isNotEmpty);
    expect(result.weightG, closeTo(240, 1));
    expect(result.imageBytes, isNotNull);

    await tester.tap(find.text('Discard'));
    await tester.pump(const Duration(seconds: 1));
    await placeFood(0);
  });
}
