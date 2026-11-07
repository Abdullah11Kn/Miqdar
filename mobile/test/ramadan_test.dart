import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miqdar_mobile/app_controller.dart';
import 'package:miqdar_mobile/data/local_database.dart';
import 'package:miqdar_mobile/models/diabetes.dart';
import 'package:miqdar_mobile/models/nutrition.dart';
import 'package:miqdar_mobile/models/ramadan.dart';
import 'package:miqdar_mobile/services/alert_service.dart';
import 'package:miqdar_mobile/services/api_service.dart';
import 'package:miqdar_mobile/services/gemini_service.dart';
import 'package:miqdar_mobile/services/reminder_service.dart';

class _FakeReminders implements ReminderScheduler {
  List<DailyReminder> scheduled = [];

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> replaceAll(List<DailyReminder> reminders) async => scheduled = reminders;
}

MealEntry _meal(String id, DateTime at, double kcal) => MealEntry(
      id: id, foodId: 'f', nameEn: id, nameAr: '', eatenAt: at, mealType: 'Meal', weightG: 100, confidence: 1,
      nutrients: NutritionValues(calories: kcal, protein: 0, carbohydrates: 0, fat: 0, sugar: 0, fiber: 0, sodium: 0, potassium: 0),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MiqdarController controller;
  late _FakeReminders reminders;

  setUp(() async {
    final client = MockClient((_) async => http.Response('{}', 200));
    final database = LocalDatabase();
    await database.initialize();
    reminders = _FakeReminders();
    controller = MiqdarController(
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
  });

  test('is off by default, with the usual meal types and midnight days', () {
    expect(controller.ramadanMode, isFalse);
    expect(controller.mealTypes, ['Breakfast', 'Lunch', 'Dinner', 'Snack']);
    expect(controller.diaryDayOf(DateTime(2027, 2, 10, 3)), DateTime(2027, 2, 10));
  });

  test('while on, an iftar and the suhoor after it fall on one day', () {
    controller.ramadanPeriods = [(start: DateTime(2027, 2, 8), end: null)];
    expect(controller.ramadanMode, isTrue);
    expect(controller.diaryDayOf(DateTime(2027, 2, 10, 18, 5)), DateTime(2027, 2, 10));
    expect(controller.diaryDayOf(DateTime(2027, 2, 11, 4, 30)), DateTime(2027, 2, 10));
    expect(controller.diaryDayOf(DateTime(2027, 2, 11, 12)), DateTime(2027, 2, 11));
    expect(controller.diaryDayOf(DateTime(2027, 2, 11, 11, 59)), DateTime(2027, 2, 10));

    controller.meals = [
      _meal('iftar', DateTime(2027, 2, 10, 18, 5), 700),
      _meal('suhoor', DateTime(2027, 2, 11, 4, 30), 400),
      _meal('next iftar', DateTime(2027, 2, 11, 18, 10), 650),
    ];
    expect(controller.totalsForDate(DateTime(2027, 2, 10)).calories, 1100);
    expect(controller.totalsForDate(DateTime(2027, 2, 11)).calories, 650);
  });

  test('days before the mode was on keep midnight', () {
    controller.ramadanPeriods = [(start: DateTime(2027, 2, 8, 20), end: null)];
    expect(controller.diaryDayOf(DateTime(2027, 2, 8, 9)), DateTime(2027, 2, 8));
    expect(controller.diaryDayOf(DateTime(2027, 2, 7, 3)), DateTime(2027, 2, 7));
    expect(controller.diaryDayOf(DateTime(2027, 2, 9, 3)), DateTime(2027, 2, 8));
  });

  test('days after it ended go back to midnight, and Ramadan nights stay together', () {
    controller.ramadanPeriods = [(start: DateTime(2027, 2, 8), end: DateTime(2027, 3, 10, 12))];
    expect(controller.ramadanMode, isFalse);
    expect(controller.diaryDayOf(DateTime(2027, 3, 5, 3)), DateTime(2027, 3, 4));
    expect(controller.diaryDayOf(DateTime(2027, 3, 12, 3)), DateTime(2027, 3, 12));
  });

  test('meal types are Iftar, Suhoor and Snack, picked from the time', () async {
    await controller.setRamadanMode(true);
    expect(controller.mealTypes, ['Iftar', 'Suhoor', 'Snack']);
    expect(controller.mealTypeFor(DateTime(2027, 2, 10, 18)), 'Iftar');
    expect(controller.mealTypeFor(DateTime(2027, 2, 11, 3)), 'Suhoor');
    await controller.setRamadanMode(false);
    expect(controller.mealTypeFor(DateTime(2027, 2, 11, 13)), 'Lunch');
  });

  test('timed reminders pause and come back unchanged', () async {
    await controller.updateReminders(const ReminderSettings(enabled: true));
    final before = reminders.scheduled.length;
    expect(before, greaterThan(0));

    await controller.setRamadanMode(true);
    expect(reminders.scheduled, isEmpty);
    expect(controller.reminderSettings.enabled, isTrue);

    await controller.setRamadanMode(false);
    expect(reminders.scheduled.length, before);
  });

  test('is stored, restored and removed by Delete All', () async {
    await controller.setRamadanMode(true);
    controller.ramadanPeriods = [];
    await controller.restorePreferences();
    expect(controller.ramadanMode, isTrue);
    await controller.deleteAllData();
    expect(controller.ramadanMode, isFalse);
  });

  test('goals do not change', () async {
    final goals = controller.goals.calories;
    await controller.setRamadanMode(true);
    expect(controller.goals.calories, goals);
  });

  test('while fasting no carb number is offered, and doctor numbers still apply', () async {
    await controller.updateDiabetes(const DiabetesSettings(hasDiabetes: true, type: DiabetesType.type2));
    await controller.useSuggestedCarbs();
    expect(controller.carbTargetFor('Lunch'), 45);

    await controller.setRamadanMode(true);
    expect(controller.suggestedCarbPlan, isNull);
    expect(controller.carbBlock, CarbAdviceBlock.fasting);
    expect(controller.carbTargetFor('Iftar'), isNull);

    await controller.setDoctorCarbs(meal: 50, snack: 15);
    expect(controller.carbTargetFor('Iftar'), 50);
  });

  group('the suggestion', () {
    // 1 Ramadan 1448 is 8 February 2027 and 1 Shawwal is 9 March 2027 by Umm al-Qura.
    test('comes three days before Ramadan, not earlier', () {
      expect(ramadanDates(1448).start, DateTime(2027, 2, 8));
      expect(ramadanPromptFor(DateTime(2027, 2, 4), modeOn: false, dismissed: {}), isNull);
      final prompt = ramadanPromptFor(DateTime(2027, 2, 5), modeOn: false, dismissed: {});
      expect(prompt!.kind, RamadanPromptKind.turnOn);
      expect(ramadanPromptFor(DateTime(2027, 3, 1), modeOn: false, dismissed: {})!.hijriYear, 1448);
    });

    test('is not repeated once answered, and never while the mode is already on', () {
      expect(ramadanPromptFor(DateTime(2027, 2, 6), modeOn: false, dismissed: {'turnOn-1448'}), isNull);
      expect(ramadanPromptFor(DateTime(2027, 2, 10), modeOn: true, dismissed: {}), isNull);
    });

    test('after Ramadan, suggests turning the mode off for two weeks', () {
      expect(ramadanPromptFor(DateTime(2027, 3, 9), modeOn: true, dismissed: {})!.kind, RamadanPromptKind.turnOff);
      expect(ramadanPromptFor(DateTime(2027, 3, 24), modeOn: true, dismissed: {}), isNull);
      expect(ramadanPromptFor(DateTime(2027, 3, 9), modeOn: false, dismissed: {}), isNull);
    });

    test('accepting switches the mode on; Not Now leaves it off; neither shows again', () async {
      const prompt = RamadanPrompt(RamadanPromptKind.turnOn, 1448);
      await controller.answerRamadanPrompt(prompt, accept: false);
      expect(controller.ramadanMode, isFalse);
      expect(controller.answeredRamadanPrompts, contains('turnOn-1448'));
      await controller.answerRamadanPrompt(prompt, accept: true);
      expect(controller.ramadanMode, isTrue);
    });
  });
}
