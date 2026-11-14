import 'package:flutter_test/flutter_test.dart';
import 'package:miqdar_mobile/data/local_database.dart';
import 'package:miqdar_mobile/models/nutrition.dart';
import 'package:miqdar_mobile/showcase/showcase.dart';
import 'package:miqdar_mobile/showcase/showcase_host.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

const carry = ShowcaseCarryOver(locale: 'ar', dark: true, apiBaseUrl: 'http://127.0.0.1:9');

MealEntry myMeal() => MealEntry(
      id: 'my-own-meal',
      foodId: 'ai-jareesh',
      nameEn: 'Jareesh',
      nameAr: 'جريش',
      eatenAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
      mealType: 'Lunch',
      weightG: 240,
      confidence: 0.9,
      nutrients: const NutritionValues(
          calories: 336, protein: 10, carbohydrates: 60, fat: 7, sugar: 1, fiber: 2, sodium: 100, potassium: 100),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late LocalDatabase diary;
  late ShowcaseLauncher launcher;

  setUp(() async {
    final root = await getDatabasesPath();
    await databaseFactory.deleteDatabase(p.join(root, LocalDatabase.mainFileName));
    for (final s in Showcase.values) {
      await LocalDatabase.deleteFiles(s.fileName);
    }
    diary = LocalDatabase();
    await diary.initialize();
    await diary.saveSetting('onboarded', '1');
    await diary.insertMealEntry(myMeal());
    launcher = ShowcaseLauncher(diary);
  });

  test('the real diary opens at launch, and is untouched after a scenario', () async {
    final real = await launcher.openAtLaunch();
    expect(real.inShowcase, isFalse);
    expect(real.meals.map((m) => m.id), ['my-own-meal']);
    real.suspend();

    final scenario = await launcher.open(Showcase.everyday, real.showcaseCarryOver);
    expect(scenario.meals.length, greaterThan(50));
    scenario.suspend();

    expect((await diary.loadMeals()).map((m) => m.id), ['my-own-meal']);
    final back = await launcher.open(null, scenario.showcaseCarryOver);
    expect(back.inShowcase, isFalse);
    expect(back.meals.map((m) => m.id), ['my-own-meal']);
    back.suspend();
  });

  test('every day: three weeks of use with the everyday features in it', () async {
    final c = await launcher.open(Showcase.everyday, carry);
    c.suspend();
    expect(c.showcase, Showcase.everyday);
    expect(c.onboarded, isTrue);
    expect(c.isAr, isTrue);
    expect(c.isDark, isTrue);
    expect(c.bodyProfile, isNotNull);
    expect(c.weightEntries.length, 4);
    expect(c.adaptiveGoalOffer, isNotNull);
    expect(c.favouriteMeals, isNotEmpty);
    expect(c.meals.where((m) => m.leftover != null), isNotEmpty);
    expect(c.meals.where((m) => m.pieceCount == 3), isNotEmpty);
    expect(c.meals.where((m) => m.items.length > 1), isNotEmpty);
    expect(c.meals.where((m) => m.verificationStatus == barcodeStatus), isNotEmpty);
    expect(c.waterEntries, isNotEmpty);
    expect(c.meals.every((m) => m.eatenAt.isBefore(DateTime.now().toUtc())), isTrue);
  });

  test('diabetes: carb numbers, readings beside meals, and a sugar warning in the bell', () async {
    final c = await launcher.open(Showcase.diabetes, carry);
    c.suspend();
    expect(c.diabetes.hasDiabetes, isTrue);
    expect(c.diabetes.hasPlan, isTrue);
    expect(c.glucoseReadings.length, greaterThan(30));
    expect(c.meals.where((m) => c.readingsForMeal(m).isNotEmpty), isNotEmpty);
    expect(c.alerts.where((a) => !a.read && a.nutrientKey == 'sugar_g'), isNotEmpty);
  });

  test('Ramadan: the mode is on, with iftar and suhoor meals', () async {
    final c = await launcher.open(Showcase.ramadan, carry);
    c.suspend();
    expect(c.ramadanMode, isTrue);
    expect(c.meals.map((m) => m.mealType).toSet(), containsAll(['Iftar', 'Suhoor']));
  });

  test('first launch: a phone that has never opened Miqdar, keeping the language and the scale', () async {
    final c = await launcher.open(Showcase.firstRun, carry);
    c.suspend();
    expect(c.onboarded, isFalse);
    expect(c.meals, isEmpty);
    expect(c.bodyProfile, isNull);
    expect(c.isAr, isTrue);
    expect(c.apiService.baseUrl, 'http://127.0.0.1:9');
  });

  test('starting a scenario again wipes what was done in it', () async {
    final first = await launcher.open(Showcase.firstRun, carry);
    first.suspend();
    first.signIn(email: '');
    await first.saveBodyProfile(first.bodyProfile ?? (await launcher.open(Showcase.everyday, carry)..suspend()).bodyProfile!);
    final again = await launcher.open(Showcase.firstRun, carry);
    again.suspend();
    expect(again.onboarded, isFalse);
    expect(again.bodyProfile, isNull);
  });

  test('a scenario open when the app closed opens again at the next launch', () async {
    final c = await launcher.open(Showcase.diabetes, carry);
    c.suspend();
    final relaunched = await ShowcaseLauncher(diary).openAtLaunch();
    relaunched.suspend();
    expect(relaunched.showcase, Showcase.diabetes);
    expect(relaunched.diabetes.hasDiabetes, isTrue);
  });
}
