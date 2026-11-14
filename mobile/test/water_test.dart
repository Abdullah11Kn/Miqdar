import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miqdar_mobile/app_controller.dart';
import 'package:miqdar_mobile/data/local_database.dart';
import 'package:miqdar_mobile/models/body_profile.dart';
import 'package:miqdar_mobile/services/alert_service.dart';
import 'package:miqdar_mobile/services/api_service.dart';
import 'package:miqdar_mobile/services/gemini_service.dart';

BodyProfile _profile(double kg) => BodyProfile(
      sex: BodySex.male,
      birthYear: 1995,
      heightCm: 175,
      weightKg: kg,
      activity: ActivityLevel.light,
      goal: WeightGoal.maintain,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MiqdarController controller;

  setUp(() async {
    final client = MockClient((_) async => http.Response('{}', 200));
    final database = LocalDatabase();
    await database.initialize();
    controller = MiqdarController(
      localDatabase: database,
      apiService: ApiService(
        baseUrl: 'http://scale.test',
        client: client,
        gemini: GeminiNutritionService(apiKey: 'k', models: const ['m'], client: client),
      ),
      alertService: AlertService(),
    );
    controller.signIn(email: '');
  });

  test('the goal is about 35 ml per kg, rounded to 50 ml', () {
    controller.bodyProfile = _profile(72);
    expect(controller.waterGoalMl, 2500); // 72 x 35 = 2520
  });

  test('without a body profile the goal is 2,000 ml', () {
    expect(controller.waterGoalMl, 2000);
  });

  test('the goal can be set by hand, and that wins', () async {
    controller.bodyProfile = _profile(72);
    await controller.setWaterGoal(3000);
    expect(controller.waterGoalMl, 3000);
  });

  test("cups add up to today's water", () async {
    await controller.addWater(250);
    await controller.addWater(250);
    await controller.addWater(330);
    expect(controller.waterForDate(controller.today), 830);
  });

  test('an entry can be undone', () async {
    final entry = await controller.addWater(500);
    await controller.deleteWater(entry.id);
    expect(controller.waterForDate(controller.today), 0);
  });

  test('water from another day does not count today', () async {
    await controller.addWater(250, at: DateTime.now().subtract(const Duration(days: 1)));
    expect(controller.waterForDate(controller.today), 0);
  });
}
