import 'package:flutter_test/flutter_test.dart';
import 'package:miqdar_mobile/data/local_database.dart';
import 'package:miqdar_mobile/models/body_profile.dart';
import 'package:miqdar_mobile/models/nutrition.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The database as version 3 of the app left it.
Future<void> _createVersion3(String path) async {
  final db = await openDatabase(path, version: 3, onCreate: (db, _) async {
    await db.execute('''CREATE TABLE goals(id INTEGER PRIMARY KEY CHECK(id=1), calories REAL, sugar REAL,
      sodium REAL, potassium REAL, carbohydrates REAL, protein REAL, fat REAL, fiber REAL,
      tracking_only INTEGER NOT NULL DEFAULT 0)''');
    await db.execute('''CREATE TABLE meals(id TEXT PRIMARY KEY, food_id TEXT, name_en TEXT, name_ar TEXT,
      eaten_at TEXT, meal_type TEXT, weight_g REAL, confidence REAL, calories_kcal REAL, protein_g REAL,
      carbohydrate_g REAL, fat_g REAL, sugar_g REAL, fiber_g REAL, sodium_mg REAL, potassium_mg REAL,
      notes TEXT NOT NULL DEFAULT '', portion_source TEXT NOT NULL DEFAULT 'scale')''');
    await db.execute('''CREATE TABLE alerts(id TEXT PRIMARY KEY, nutrient_key TEXT, severity TEXT,
      current_value REAL, threshold_value REAL, message TEXT, created_at TEXT, evaluation_ms INTEGER,
      message_ar TEXT NOT NULL DEFAULT '', is_read INTEGER NOT NULL DEFAULT 0, acknowledged INTEGER NOT NULL DEFAULT 0)''');
    await db.execute('''CREATE TABLE health_profile(id INTEGER PRIMARY KEY CHECK(id=1), conditions TEXT NOT NULL,
      dietary_preferences TEXT NOT NULL, allergens TEXT NOT NULL, disliked_foods TEXT NOT NULL)''');
    await db.insert('goals', {'id': 1, 'calories': 1900, 'sugar': 40, 'sodium': 2000, 'potassium': 3000, 'carbohydrates': 200, 'protein': 100, 'fat': 60, 'fiber': 25});
    await db.insert('meals', {
      'id': 'old-meal', 'food_id': 'gemini-jareesh', 'name_en': 'Jareesh', 'name_ar': 'جريش',
      'eaten_at': DateTime.now().toUtc().toIso8601String(), 'meal_type': 'Lunch', 'weight_g': 240.0, 'confidence': 0.9,
      'calories_kcal': 336.0, 'protein_g': 10.0, 'carbohydrate_g': 60.0, 'fat_g': 7.0, 'sugar_g': 1.0, 'fiber_g': 2.0, 'sodium_mg': 100.0, 'potassium_mg': 100.0,
    });
  });
  await db.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('upgrading from version 3 keeps meals and goals, and the new data is stored for real', () async {
    final path = p.join(await getDatabasesPath(), 'miqdar_mobile.db');
    await databaseFactory.deleteDatabase(path);
    await _createVersion3(path);

    final database = LocalDatabase();
    await database.initialize();

    final goals = await database.loadGoals();
    expect(goals.calories, 1900);
    final meals = await database.loadMeals();
    expect(meals.single.nameEn, 'Jareesh');
    expect(meals.single.nutrients.calories, 336);
    expect(meals.single.items, isEmpty);
    expect(meals.single.leftover, isNull);
    // Version 8: meals from before free sugar have none, and count their total sugar.
    expect(meals.single.nutrients.freeSugar, isNull);
    expect(meals.single.nutrients.sugarForLimit, 1);

    await database.updateMeal(meals.single.copyWith(
      leftover: MealLeftover(grams: 60, weighedAt: DateTime.now()),
    ));
    final weighed = (await database.loadMeals()).single;
    expect(weighed.leftover!.grams, 60);
    expect(weighed.servedNutrients.calories, 336);
    expect(weighed.nutrients.calories, 252);

    await database.updateMeal(weighed.copyWith(
      nutrients: NutritionValues.fromJson({...weighed.servedNutrients.toDatabase(), 'free_sugar_g': 0.5}),
    ));
    expect((await database.loadMeals()).single.servedNutrients.freeSugar, 0.5);

    // Version 9: favourites are kept.
    expect((await database.loadMeals()).single.favourite, isFalse);
    await database.updateMeal((await database.loadMeals()).single.copyWith(favourite: true));
    expect((await database.loadMeals()).single.favourite, isTrue);

    const profile = BodyProfile(
      sex: BodySex.female, birthYear: 1995, heightCm: 165, weightKg: 62,
      activity: ActivityLevel.light, goal: WeightGoal.maintain,
    );
    await database.saveBodyProfile(profile);
    expect((await database.loadBodyProfile())!.heightCm, 165);

    await database.saveBodyWeight(BodyWeightEntry(id: 'w', measuredOn: DateTime(2026, 11, 4), weightKg: 62));
    expect((await database.loadBodyWeights()).single.weightKg, 62);

    final basis = NutritionValues.fromJson(const {
      'calories_kcal': 150.0, 'protein_g': 5.0, 'carbohydrate_g': 20.0, 'fat_g': 4.0,
      'sugar_g': 1.0, 'fiber_g': 1.0, 'sodium_mg': 10.0, // potassium unknown
    });
    MealItemEntry item(String id, double g) => MealItemEntry(
          id: id, foodId: id, nameEn: id, nameAr: id, weightG: g,
          nutrients: basis.forPortionGrams(g), basisPer100g: basis,
        );
    final plate = RecognitionResult.forPlate(
      eventId: 'p', items: [item('rice', 200), item('chicken', 100)],
      nameEn: 'Chicken Kabsa', nameAr: 'كبسة', confidence: 0.9, provider: 'gemini',
    );
    final saved = await database.saveRecognition(plate);
    final reloaded = (await database.loadMeals()).firstWhere((m) => m.id == saved.id);
    expect(reloaded.nameEn, 'Chicken Kabsa');
    expect(reloaded.items.map((i) => i.nameEn), ['rice', 'chicken']);
    expect(reloaded.items.first.nutrients.calories, closeTo(300, 0.01));
    expect(reloaded.items.first.nutrients.isMissing('potassium_mg'), isTrue);

    await database.deleteMeal(saved.id);
    await database.deleteAllData();
    expect(await database.loadBodyProfile(), isNull);
    expect(await database.loadBodyWeights(), isEmpty);
    expect(await database.loadMeals(), isEmpty);
    await databaseFactory.deleteDatabase(path);
  });
}
