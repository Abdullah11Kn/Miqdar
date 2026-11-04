import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miqdar_mobile/app_controller.dart';
import 'package:miqdar_mobile/data/local_database.dart';
import 'package:miqdar_mobile/models/body_profile.dart';
import 'package:miqdar_mobile/models/nutrition.dart';
import 'package:miqdar_mobile/services/alert_service.dart';
import 'package:miqdar_mobile/services/api_service.dart';
import 'package:miqdar_mobile/services/gemini_service.dart';
import 'package:miqdar_mobile/services/reminder_service.dart';

class _FakeReminders implements ReminderScheduler {
  _FakeReminders({this.allow = true});

  final bool allow;
  int asked = 0;
  List<DailyReminder> scheduled = [];

  @override
  Future<bool> requestPermission() async {
    asked++;
    return allow;
  }

  @override
  Future<void> replaceAll(List<DailyReminder> reminders) async => scheduled = reminders;
}

const _profile = BodyProfile(
  sex: BodySex.male,
  birthYear: 1996,
  heightCm: 180,
  weightKg: 80,
  activity: ActivityLevel.moderate,
  goal: WeightGoal.maintain,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> geminiCalls;
  late _FakeReminders reminders;

  Future<MiqdarController> build({bool allow = true}) async {
    geminiCalls = [];
    reminders = _FakeReminders(allow: allow);
    final client = MockClient((request) async {
      if (request.url.host.contains('googleapis')) geminiCalls.add(request.url.path);
      return http.Response('{}', 200);
    });
    final database = LocalDatabase();
    await database.initialize();
    final controller = MiqdarController(
      localDatabase: database,
      apiService: ApiService(
        baseUrl: 'http://scale.test',
        client: client,
        gemini: GeminiNutritionService(apiKey: 'k', models: const ['m'], client: client),
      ),
      alertService: AlertService(),
      reminderScheduler: reminders,
    );
    controller.signIn(email: '');
    return controller;
  }

  MealEntry meal(String name, DateTime when, {double kcal = 300}) => MealEntry(
        id: '$name-$when',
        foodId: 'gemini-$name',
        nameEn: name,
        nameAr: name,
        eatenAt: when,
        mealType: 'Lunch',
        weightG: 200,
        confidence: 0.9,
        nutrients: NutritionValues(calories: kcal, protein: 0, carbohydrates: 0, fat: 0, sugar: 0, fiber: 0, sodium: 0, potassium: 0),
        verificationStatus: aiEstimateStatus,
        portionSource: PortionSource.scale,
      );

  group('quick re-logging', () {
    test('recent foods are newest first, one per name, at most five', () async {
      final c = await build();
      final now = DateTime(2026, 11, 4, 12);
      c.meals = [
        for (var i = 0; i < 7; i++) meal('Food $i', now.subtract(Duration(days: i))),
        meal('Food 0', now.subtract(const Duration(days: 9))),
      ];
      expect(c.recentFoods.map((m) => m.nameEn), ['Food 0', 'Food 1', 'Food 2', 'Food 3', 'Food 4']);
    });

    test('repeating a food uses saved values, sends nothing to Gemini, and keeps its source', () async {
      final c = await build();
      final draft = await c.prepareRelog(meal('Kabsa', DateTime(2026, 11, 4), kcal: 300));
      expect(geminiCalls, isEmpty);
      expect(draft.nutrients.calories, closeTo(300, 0.01));
      expect(draft.verificationStatus, aiEstimateStatus);
      expect(draft.portionSource, PortionSource.manual);
      expect(c.meals, isEmpty);
    });
  });

  group('body weight log', () {
    Future<MiqdarController> withGoal() async {
      final c = await build();
      await c.saveBodyProfile(_profile);
      await c.rememberGoalWeight(80);
      return c;
    }

    test('entries sort by date, and the newest becomes the profile weight', () async {
      final c = await withGoal();
      await c.saveWeightEntry(measuredOn: DateTime(2026, 11, 3), weightKg: 79);
      await c.saveWeightEntry(measuredOn: DateTime(2026, 10, 1), weightKg: 85);
      expect(c.weightEntries.map((e) => e.weightKg), [85, 79]);
      expect(c.bodyProfile!.weightKg, 79);
    });

    test('a correction replaces the entry, and deleting removes it', () async {
      final c = await withGoal();
      await c.saveWeightEntry(measuredOn: DateTime(2026, 11, 3), weightKg: 790);
      final id = c.weightEntries.single.id;
      await c.saveWeightEntry(id: id, measuredOn: DateTime(2026, 11, 3), weightKg: 79);
      expect(c.weightEntries.single.weightKg, 79);
      await c.deleteWeightEntry(id);
      expect(c.weightEntries, isEmpty);
    });

    test('a goal update is offered at 2 kg, not before, and goals wait for an answer', () async {
      final c = await withGoal();
      final before = c.goals.calories;
      await c.saveWeightEntry(measuredOn: DateTime(2026, 11, 3), weightKg: 78.5);
      expect(c.goalUpdateOffer, isNull);
      await c.saveWeightEntry(measuredOn: DateTime(2026, 11, 4), weightKg: 78);
      expect(c.goalUpdateOffer, isNotNull);
      expect(c.goals.calories, before);
    });

    test('declining changes nothing and stops asking until weight moves as far again', () async {
      final c = await withGoal();
      final before = c.goals.calories;
      await c.saveWeightEntry(measuredOn: DateTime(2026, 11, 4), weightKg: 75);
      await c.declineGoalUpdate();
      expect(c.goals.calories, before);
      expect(c.goalUpdateOffer, isNull);
      await c.saveWeightEntry(measuredOn: DateTime(2026, 11, 5), weightKg: 73);
      expect(c.goalUpdateOffer, isNotNull);
    });

    test('tracking without goals is never offered one', () async {
      final c = await withGoal();
      c.goals = c.goals.copyWith(trackingOnly: true);
      await c.saveWeightEntry(measuredOn: DateTime(2026, 11, 4), weightKg: 70);
      expect(c.goalUpdateOffer, isNull);
    });

    test('the demo saves none of it', () async {
      final c = await build();
      c.signIn(email: '', displayName: 'Demo', isDemo: true);
      await c.saveWeightEntry(measuredOn: DateTime(2026, 11, 4), weightKg: 70);
      expect(await c.localDatabase.loadBodyWeights(), isEmpty);
    });
  });

  group('meal reminders', () {
    test('are off by default, and permission is asked only when turned on', () async {
      final c = await build();
      expect(c.reminderSettings.enabled, isFalse);
      expect(reminders.asked, 0);
      expect(await c.updateReminders(c.reminderSettings.copyWith(enabled: true)), isTrue);
      expect(reminders.asked, 1);
      expect(reminders.scheduled, hasLength(3));
    });

    test('a refusal leaves them off and is reported', () async {
      final c = await build(allow: false);
      expect(await c.updateReminders(c.reminderSettings.copyWith(enabled: true)), isFalse);
      expect(c.reminderSettings.enabled, isFalse);
      expect(reminders.scheduled, isEmpty);
    });

    test('chosen meals and times are scheduled, and turning off removes them', () async {
      final c = await build();
      await c.updateReminders(c.reminderSettings.copyWith(enabled: true));
      await c.updateReminders(c.reminderSettings.copyWith(meals: [
        c.reminderSettings.meals[0].copyWith(hour: 9, minute: 30),
        c.reminderSettings.meals[1].copyWith(on: false),
        c.reminderSettings.meals[2],
      ]));
      expect(reminders.scheduled.map((r) => (r.id, r.hour, r.minute)), [(1, 9, 30), (3, 19, 0)]);
      await c.updateReminders(c.reminderSettings.copyWith(enabled: false));
      expect(reminders.scheduled, isEmpty);
    });

    test('settings survive being stored, and the text follows the language', () async {
      final c = await build();
      await c.updateReminders(c.reminderSettings.copyWith(enabled: true));
      final read = ReminderSettings.decode(c.reminderSettings.encode());
      expect(read.enabled, isTrue);
      expect(read.meals, hasLength(3));
      expect(reminders.scheduled.first.body, contains('breakfast'));
      c.setLocale(const Locale('ar'));
      await pumpEventQueue();
      expect(reminders.scheduled.first.body, contains('فطورك'));
    });
  });
}
