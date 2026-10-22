import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/nutrition.dart';

class LocalDatabase {
  Database? _database;
  bool _useInMemory = false;

  NutritionGoals _memGoals = const NutritionGoals(
    calories: 2200,
    sugar: 50,
    sodium: 2300,
    potassium: 3500,
    carbohydrates: 275,
    protein: 120,
  );
  HealthProfile _memHealthProfile = const HealthProfile();
  final List<MealEntry> _memMeals = [];
  final List<HealthAlert> _memAlerts = [];

  Future<void> initialize() async {
    if (kIsWeb) {
      _useInMemory = true;
      _seedMemoryHistory();
      return;
    }
    try {
      final root = await getDatabasesPath();
      _database = await openDatabase(
        p.join(root, 'miqdar_mobile.db'),
        version: 2,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE goals(
              id INTEGER PRIMARY KEY CHECK(id=1), calories REAL, sugar REAL,
              sodium REAL, potassium REAL, carbohydrates REAL, protein REAL
            )
          ''');
          await db.execute('''
            CREATE TABLE meals(
              id TEXT PRIMARY KEY, food_id TEXT, name_en TEXT, name_ar TEXT,
              eaten_at TEXT, meal_type TEXT, weight_g REAL, confidence REAL,
              calories_kcal REAL, protein_g REAL, carbohydrate_g REAL, fat_g REAL,
              sugar_g REAL, fiber_g REAL, sodium_mg REAL, potassium_mg REAL
            )
          ''');
          await db.execute('''
            CREATE TABLE alerts(
              id TEXT PRIMARY KEY, nutrient_key TEXT, severity TEXT,
              current_value REAL, threshold_value REAL, message TEXT,
              created_at TEXT, evaluation_ms INTEGER
            )
          ''');
          await _createHealthProfileTable(db);
        },
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) await _createHealthProfileTable(db);
        },
      );
      await _seedGoals();
      await _seedHealthProfile();
      await _seedHistory();
    } catch (_) {
      _useInMemory = true;
      _seedMemoryHistory();
    }
  }

  void _seedMemoryHistory() {
    const foods = [
      ('food_rice_white_cooked', 'White rice', 'أرز أبيض', 180.0, 234.0, 4.8, 50.7, 0.5, 0.1, 0.7, 2.0, 63.0),
      ('food_chicken_breast_roasted', 'Chicken breast', 'صدر دجاج', 145.0, 239.0, 45.0, 0.0, 5.2, 0.0, 0.0, 107.0, 371.0),
      ('food_hummus_prepared', 'Hummus', 'حمص', 95.0, 158.0, 7.5, 13.6, 9.1, 0.3, 5.7, 360.0, 217.0),
      ('food_dates_medjool', 'Medjool dates', 'تمر مجدول', 42.0, 116.0, 0.8, 31.5, 0.1, 27.9, 2.8, 0.4, 292.0),
      ('food_salmon_cooked', 'Cooked salmon', 'سلمون مطبوخ', 130.0, 268.0, 28.7, 0.0, 16.1, 0.0, 0.0, 77.0, 499.0),
    ];
    final now = DateTime.now().toUtc();
    for (var day = 0; day < 91; day++) {
      final food = foods[day % foods.length];
      _memMeals.add(MealEntry(
        id: 'seed-$day',
        foodId: food.$1,
        nameEn: food.$2,
        nameAr: food.$3,
        eatenAt: now.subtract(Duration(days: day)),
        mealType: 'Lunch',
        weightG: food.$4,
        confidence: 0.94,
        nutrients: NutritionValues(
          calories: food.$5,
          protein: food.$6,
          carbohydrates: food.$7,
          fat: food.$8,
          sugar: food.$9,
          fiber: food.$10,
          sodium: food.$11,
          potassium: food.$12,
        ),
      ));
    }
  }

  static Future<void> _createHealthProfileTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS health_profile(
      id INTEGER PRIMARY KEY CHECK(id=1),
      conditions TEXT NOT NULL,
      dietary_preferences TEXT NOT NULL,
      allergens TEXT NOT NULL,
      disliked_foods TEXT NOT NULL
    )
  ''');

  Database get db {
    final value = _database;
    if (value == null) throw StateError('Local database is not initialized');
    return value;
  }

  Future<void> _seedGoals() async {
    if (Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM goals')) != 0) return;
    await db.insert('goals', {
      'id': 1,
      'calories': 2200.0,
      'sugar': 50.0,
      'sodium': 2300.0,
      'potassium': 3500.0,
      'carbohydrates': 275.0,
      'protein': 120.0,
    });
  }

  Future<void> _seedHealthProfile() async {
    if (Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM health_profile')) != 0) return;
    await db.insert('health_profile', {
      'id': 1,
      'conditions': '',
      'dietary_preferences': '',
      'allergens': '',
      'disliked_foods': '',
    });
  }

  Future<void> _seedHistory() async {
    if (Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM meals')) != 0) return;
    const foods = [
      ('food_rice_white_cooked', 'White rice', 'أرز أبيض', 180.0, 234.0, 4.8, 50.7, 0.5, 0.1, 0.7, 2.0, 63.0),
      ('food_chicken_breast_roasted', 'Chicken breast', 'صدر دجاج', 145.0, 239.0, 45.0, 0.0, 5.2, 0.0, 0.0, 107.0, 371.0),
      ('food_hummus_prepared', 'Hummus', 'حمص', 95.0, 158.0, 7.5, 13.6, 9.1, 0.3, 5.7, 360.0, 217.0),
      ('food_dates_medjool', 'Medjool dates', 'تمر مجدول', 42.0, 116.0, 0.8, 31.5, 0.1, 27.9, 2.8, 0.4, 292.0),
      ('food_salmon_cooked', 'Cooked salmon', 'سلمون مطبوخ', 130.0, 268.0, 28.7, 0.0, 16.1, 0.0, 0.0, 77.0, 499.0),
    ];
    final now = DateTime.now().toUtc();
    final batch = db.batch();
    for (var day = 0; day < 91; day++) {
      final food = foods[day % foods.length];
      batch.insert('meals', {
        'id': 'seed-$day',
        'food_id': food.$1,
        'name_en': food.$2,
        'name_ar': food.$3,
        'eaten_at': now.subtract(Duration(days: day)).toIso8601String(),
        'meal_type': 'Lunch',
        'weight_g': food.$4,
        'confidence': 0.94,
        'calories_kcal': food.$5,
        'protein_g': food.$6,
        'carbohydrate_g': food.$7,
        'fat_g': food.$8,
        'sugar_g': food.$9,
        'fiber_g': food.$10,
        'sodium_mg': food.$11,
        'potassium_mg': food.$12,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<NutritionGoals> loadGoals() async {
    if (_useInMemory) return _memGoals;
    final row = (await db.query('goals', where: 'id=1')).single;
    return NutritionGoals(
      calories: (row['calories'] as num).toDouble(),
      sugar: (row['sugar'] as num).toDouble(),
      sodium: (row['sodium'] as num).toDouble(),
      potassium: (row['potassium'] as num).toDouble(),
      carbohydrates: (row['carbohydrates'] as num).toDouble(),
      protein: (row['protein'] as num).toDouble(),
    );
  }

  Future<void> saveGoals(NutritionGoals goals) async {
    if (_useInMemory) {
      _memGoals = goals;
      return;
    }
    await db.update(
      'goals',
      {
        'calories': goals.calories,
        'sugar': goals.sugar,
        'sodium': goals.sodium,
        'potassium': goals.potassium,
        'carbohydrates': goals.carbohydrates,
        'protein': goals.protein,
      },
      where: 'id=1',
    );
  }

  Future<HealthProfile> loadHealthProfile() async {
    if (_useInMemory) return _memHealthProfile;
    final row = (await db.query('health_profile', where: 'id=1')).single;
    List<String> split(Object? value) => value
        .toString()
        .split('|')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return HealthProfile(
      conditions: split(row['conditions']),
      dietaryPreferences: split(row['dietary_preferences']),
      allergens: split(row['allergens']),
      dislikedFoods: split(row['disliked_foods']),
    );
  }

  Future<void> saveHealthProfile(HealthProfile profile) async {
    if (_useInMemory) {
      _memHealthProfile = profile;
      return;
    }
    await db.update(
      'health_profile',
      {
        'conditions': profile.conditions.join('|'),
        'dietary_preferences': profile.dietaryPreferences.join('|'),
        'allergens': profile.allergens.join('|'),
        'disliked_foods': profile.dislikedFoods.join('|'),
      },
      where: 'id=1',
    );
  }

  Future<List<MealEntry>> loadMeals({int days = 90}) async {
    if (_useInMemory) {
      final now = DateTime.now().toUtc();
      final cutoff = DateTime.utc(now.year, now.month, now.day)
          .subtract(Duration(days: max(0, days - 1)));
      return _memMeals
          .where((m) => !m.eatenAt.isBefore(cutoff))
          .toList()
        ..sort((a, b) => b.eatenAt.compareTo(a.eatenAt));
    }
    final now = DateTime.now().toUtc();
    final cutoff = DateTime.utc(now.year, now.month, now.day)
        .subtract(Duration(days: max(0, days - 1)));
    final rows = await db.query(
      'meals',
      where: 'eaten_at >= ?',
      whereArgs: [cutoff.toIso8601String()],
      orderBy: 'eaten_at DESC',
    );
    return rows.map(_mealFromRow).toList();
  }

  MealEntry _mealFromRow(Map<String, Object?> row) => MealEntry(
        id: row['id'] as String,
        foodId: row['food_id'] as String,
        nameEn: row['name_en'] as String,
        nameAr: row['name_ar'] as String,
        eatenAt: DateTime.parse(row['eaten_at'] as String),
        mealType: row['meal_type'] as String,
        weightG: (row['weight_g'] as num).toDouble(),
        confidence: (row['confidence'] as num).toDouble(),
        nutrients: NutritionValues.fromJson(row.cast<String, dynamic>()),
      );

  Future<MealEntry> saveRecognition(RecognitionResult result) async {
    final stamp = DateTime.now().toUtc();
    final meal = MealEntry(
      id: 'local-${stamp.microsecondsSinceEpoch}',
      foodId: result.foodId,
      nameEn: result.nameEn,
      nameAr: result.nameAr,
      eatenAt: stamp,
      mealType: 'Meal',
      weightG: result.weightG,
      confidence: result.confidence,
      nutrients: result.nutrients,
    );
    if (_useInMemory) {
      _memMeals.insert(0, meal);
      return meal;
    }
    await db.insert('meals', {
      'id': meal.id,
      'food_id': meal.foodId,
      'name_en': meal.nameEn,
      'name_ar': meal.nameAr,
      'eaten_at': meal.eatenAt.toIso8601String(),
      'meal_type': meal.mealType,
      'weight_g': meal.weightG,
      'confidence': meal.confidence,
      ...meal.nutrients.toDatabase(),
    });
    return meal;
  }

  Future<void> updateMeal(MealEntry meal) async {
    if (_useInMemory) {
      final index = _memMeals.indexWhere((m) => m.id == meal.id);
      if (index != -1) _memMeals[index] = meal;
      return;
    }
    await db.update(
      'meals',
      {
        'eaten_at': meal.eatenAt.toUtc().toIso8601String(),
        'meal_type': meal.mealType,
        'weight_g': meal.weightG,
        ...meal.nutrients.toDatabase(),
      },
      where: 'id = ?',
      whereArgs: [meal.id],
    );
  }

  Future<void> deleteMeal(String id) async {
    if (_useInMemory) {
      _memMeals.removeWhere((m) => m.id == id);
      return;
    }
    await db.delete(
      'meals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> saveAlerts(List<HealthAlert> alerts) async {
    if (_useInMemory) {
      _memAlerts.insertAll(0, alerts);
      return;
    }
    final batch = db.batch();
    for (final alert in alerts) {
      batch.insert('alerts', {
        'id': alert.id,
        'nutrient_key': alert.nutrientKey,
        'severity': alert.severity,
        'current_value': alert.currentValue,
        'threshold_value': alert.thresholdValue,
        'message': alert.message,
        'created_at': alert.createdAt.toIso8601String(),
        'evaluation_ms': alert.evaluationMs,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<HealthAlert>> loadAlerts() async {
    if (_useInMemory) {
      return List.unmodifiable(_memAlerts.take(100));
    }
    final rows = await db.query('alerts', orderBy: 'created_at DESC', limit: 100);
    return rows.map((row) => HealthAlert(
      id: row['id'] as String,
      nutrientKey: row['nutrient_key'] as String,
      severity: row['severity'] as String,
      currentValue: (row['current_value'] as num).toDouble(),
      thresholdValue: (row['threshold_value'] as num).toDouble(),
      message: row['message'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      evaluationMs: row['evaluation_ms'] as int,
    )).toList();
  }
}
