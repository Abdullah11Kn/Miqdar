import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/body_profile.dart';
import '../models/nutrition.dart';

class LocalDatabase {
  Database? _database;
  bool _useInMemory = false;

  static const defaultGoals = NutritionGoals(
    calories: 2200,
    sugar: 50,
    sodium: 2300,
    potassium: 3500,
    carbohydrates: 275,
    protein: 120,
    fat: 70,
    fiber: 28,
  );
  static const _defaultHealthProfile = HealthProfile(
    conditions: ['weight_management'],
    dietaryPreferences: [],
    allergens: [],
    dislikedFoods: [],
  );

  NutritionGoals _memGoals = defaultGoals;
  HealthProfile _memHealthProfile = _defaultHealthProfile;
  final Map<String, Uint8List> _memPhotos = {};
  final List<MealEntry> _memMeals = [];
  final List<HealthAlert> _memAlerts = [];
  final List<FoodCatalogItem> _memCustomFoods = [];

  static const _seedFoodDefs = [
    (
      'food_chicken_kabsa',
      'Chicken Kabsa',
      'كبسة دجاج',
      'Lunch',
      280.0,
      'reference_seed',
      185.0,
      12.5,
      21.0,
      5.5,
      0.5,
      1.2,
      320.0,
      210.0,
    ),
    (
      'food_dates_medjool',
      'Dates - Medjool',
      'تمر مجدول',
      'Snack',
      48.0,
      'verified_official_record',
      277.0,
      1.81,
      74.97,
      0.15,
      66.47,
      6.7,
      1.0,
      696.0,
    ),
    (
      'food_chicken_breast_roasted',
      'Chicken breast - roasted',
      'صدر دجاج مشوي',
      'Dinner',
      165.0,
      'reference_seed',
      165.0,
      31.02,
      0.0,
      3.57,
      0.0,
      0.0,
      74.0,
      256.0,
    ),
    (
      'food_hummus_prepared',
      'Hummus - prepared',
      'حمص محضر',
      'Breakfast',
      110.0,
      'reference_seed',
      166.0,
      7.9,
      14.3,
      9.6,
      0.3,
      6.0,
      379.0,
      228.0,
    ),
    (
      'food_salmon_cooked',
      'Salmon - cooked',
      'سلمون مطبوخ',
      'Dinner',
      150.0,
      'reference_seed',
      206.0,
      22.1,
      0.0,
      12.35,
      0.0,
      0.0,
      59.0,
      384.0,
    ),
    (
      'food_jareesh',
      'Jareesh',
      'جريش',
      'Lunch',
      240.0,
      'reference_seed',
      140.0,
      6.2,
      18.0,
      4.8,
      1.5,
      2.8,
      310.0,
      180.0,
    ),
    (
      'food_greek_yogurt',
      'Greek Yogurt',
      'زبادي يوناني',
      'Breakfast',
      170.0,
      'reference_seed',
      97.0,
      9.0,
      4.0,
      5.0,
      4.0,
      0.0,
      45.0,
      140.0,
    ),
  ];

  Future<void> initialize() async {
    if (kIsWeb) {
      _useInMemory = true;
      return;
    }
    try {
      final root = await getDatabasesPath();
      _database = await openDatabase(
        p.join(root, 'miqdar_mobile.db'),
        version: 8,
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
          await _addRestartSafeColumns(db);
          await _createBodyProfileTable(db);
          await _createMealItemsTable(db);
          await _createBodyWeightsTable(db);
          await _addLeftoverColumns(db);
          await _addFreeSugarColumn(db);
        },
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) await _createHealthProfileTable(db);
          if (oldVersion < 3) await _addRestartSafeColumns(db);
          if (oldVersion < 4) await _createBodyProfileTable(db);
          if (oldVersion < 5) await _createMealItemsTable(db);
          if (oldVersion < 6) await _createBodyWeightsTable(db);
          if (oldVersion < 7) await _addLeftoverColumns(db);
          if (oldVersion < 8) await _addFreeSugarColumn(db);
        },
      );
      await _seedGoals();
      await _seedHealthProfile();
      await _removeSampleHistory();
    } catch (_) {
      _useInMemory = true;
    }
  }

  /// Sample history for the clearly labelled demo workspace only. Never stored.
  List<MealEntry> demoHistory() {
    final demo = <MealEntry>[];
    final now = DateTime.now().toUtc();
    for (var day = 0; day < 91; day++) {
      // Today and recent days get 2 meals so daily progress and charts look rich and realistic!
      final mealsCount = day < 7 ? 2 : 1;
      for (var m = 0; m < mealsCount; m++) {
        final def = _seedFoodDefs[(day + m * 3) % _seedFoodDefs.length];
        final weight = def.$5;
        final basis = NutritionValues(
          calories: def.$7,
          protein: def.$8,
          carbohydrates: def.$9,
          fat: def.$10,
          sugar: def.$11,
          fiber: def.$12,
          sodium: def.$13,
          potassium: def.$14,
        );
        final scaled = basis.forPortionGrams(weight);
        demo.add(MealEntry(
          id: m == 0 ? 'seed-$day' : 'seed-$day-$m',
          foodId: def.$1,
          nameEn: def.$2,
          nameAr: def.$3,
          eatenAt: now.subtract(Duration(days: day, hours: m * 5 + 1)),
          mealType: def.$4,
          weightG: weight,
          confidence: 0.94,
          nutrients: scaled,
          basisPer100g: basis,
          verificationStatus: def.$6,
          portionSource: m == 0 ? PortionSource.scale : PortionSource.manual,
          syncStatus: 'synced',
        ));
      }
    }
    return demo;
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

  static Future<void> _createBodyProfileTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS body_profile(
      id INTEGER PRIMARY KEY CHECK(id=1),
      sex TEXT NOT NULL,
      birth_year INTEGER NOT NULL,
      height_cm REAL NOT NULL,
      weight_kg REAL NOT NULL,
      activity TEXT NOT NULL,
      goal TEXT NOT NULL,
      target_weight_kg REAL,
      weekly_pace_kg REAL,
      pregnant_or_breastfeeding INTEGER NOT NULL DEFAULT 0
    )
  ''');

  static Future<void> _createMealItemsTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS meal_items(
      id TEXT PRIMARY KEY,
      meal_id TEXT NOT NULL,
      position INTEGER NOT NULL,
      food_id TEXT NOT NULL,
      name_en TEXT NOT NULL,
      name_ar TEXT NOT NULL,
      weight_g REAL NOT NULL,
      portion_source TEXT NOT NULL,
      verification_status TEXT NOT NULL,
      preparation TEXT NOT NULL,
      basis_json TEXT NOT NULL
    )
  ''');

  static Future<void> _createBodyWeightsTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS body_weights(
      id TEXT PRIMARY KEY,
      measured_on TEXT NOT NULL,
      weight_kg REAL NOT NULL
    )
  ''');

  /// Free sugar, per the WHO, for the sugar limit (database v8). Older meals keep null and count their
  /// total sugar. Plate items keep theirs inside basis_json, so that table needs no column.
  static Future<void> _addFreeSugarColumn(Database db) =>
      db.execute('ALTER TABLE meals ADD COLUMN free_sugar_g REAL');

  /// Food weighed after eating (database v7). Served values stay in the meal's own columns.
  static Future<void> _addLeftoverColumns(Database db) async {
    await db.execute('ALTER TABLE meals ADD COLUMN leftover_g REAL');
    await db.execute('ALTER TABLE meals ADD COLUMN leftover_item INTEGER');
    await db.execute('ALTER TABLE meals ADD COLUMN leftover_at TEXT');
  }

  static Map<String, Object?> _leftoverColumns(MealEntry meal) => {
        'leftover_g': meal.leftover?.grams,
        'leftover_item': meal.leftover?.itemIndex,
        'leftover_at': meal.leftover?.weighedAt.toUtc().toIso8601String(),
      };

  /// Fields that used to live only in memory and were lost on every restart.
  static Future<void> _addRestartSafeColumns(Database db) async {
    await db.execute('ALTER TABLE goals ADD COLUMN fat REAL');
    await db.execute('ALTER TABLE goals ADD COLUMN fiber REAL');
    await db.execute('ALTER TABLE goals ADD COLUMN tracking_only INTEGER NOT NULL DEFAULT 0');
    await db.execute("ALTER TABLE meals ADD COLUMN notes TEXT NOT NULL DEFAULT ''");
    await db.execute("ALTER TABLE meals ADD COLUMN portion_source TEXT NOT NULL DEFAULT 'scale'");
    await db.execute("ALTER TABLE alerts ADD COLUMN message_ar TEXT NOT NULL DEFAULT ''");
    await db.execute('ALTER TABLE alerts ADD COLUMN is_read INTEGER NOT NULL DEFAULT 0');
    await db.execute('ALTER TABLE alerts ADD COLUMN acknowledged INTEGER NOT NULL DEFAULT 0');
  }

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
      'conditions': 'weight_management',
      'dietary_preferences': '',
      'allergens': '',
      'disliked_foods': '',
    });
  }

  /// Earlier versions filled the diary with sample meals that counted toward real totals.
  Future<void> _removeSampleHistory() async {
    final removed = await db.delete('meals', where: "id LIKE 'seed-%'");
    if (removed > 0) await db.delete('alerts');
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
      fat: (row['fat'] as num?)?.toDouble() ?? defaultGoals.fat,
      fiber: (row['fiber'] as num?)?.toDouble() ?? defaultGoals.fiber,
      goalTypes: _memGoals.goalTypes,
      source: _memGoals.source,
      trackingOnly: row['tracking_only'] == 1,
    );
  }

  Future<void> saveGoals(NutritionGoals goals) async {
    _memGoals = goals;
    if (_useInMemory) return;
    await db.update(
      'goals',
      {
        'calories': goals.calories,
        'sugar': goals.sugar,
        'sodium': goals.sodium,
        'potassium': goals.potassium,
        'carbohydrates': goals.carbohydrates,
        'protein': goals.protein,
        'fat': goals.fat,
        'fiber': goals.fiber,
        'tracking_only': goals.trackingOnly ? 1 : 0,
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
    _memHealthProfile = profile;
    if (_useInMemory) return;
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
    final itemRows = await db.query('meal_items', orderBy: 'position');
    final items = <String, List<MealItemEntry>>{};
    for (final row in itemRows) {
      (items[row['meal_id'] as String] ??= []).add(MealItemEntry.fromRow(row));
    }
    return rows.map((row) {
      final meal = _mealFromRow(row);
      return items.containsKey(meal.id) ? meal.copyWith(items: items[meal.id]) : meal;
    }).toList();
  }

  MealEntry _mealFromRow(Map<String, Object?> row) {
    final weightG = (row['weight_g'] as num).toDouble();
    final nutrients = NutritionValues.fromJson(row.cast<String, dynamic>());
    return MealEntry(
      id: row['id'] as String,
      foodId: row['food_id'] as String,
      nameEn: row['name_en'] as String,
      nameAr: row['name_ar'] as String,
      eatenAt: DateTime.parse(row['eaten_at'] as String),
      mealType: row['meal_type'] as String,
      weightG: weightG,
      confidence: (row['confidence'] as num).toDouble(),
      nutrients: nutrients,
      notes: row['notes'] as String? ?? '',
      portionSource: PortionSource.values.asNameMap()[row['portion_source']] ?? PortionSource.scale,
      leftover: row['leftover_g'] is num && row['leftover_at'] is String
          ? MealLeftover(
              grams: (row['leftover_g'] as num).toDouble(),
              itemIndex: (row['leftover_item'] as num?)?.toInt(),
              weighedAt: DateTime.parse(row['leftover_at'] as String),
            )
          : null,
      basisPer100g: weightG > 0 ? nutrients.scaledBy(100.0 / weightG) : nutrients,
      verificationStatus: (row['food_id'] as String).startsWith(aiFoodIdPrefix)
          ? aiEstimateStatus
          : ((row['food_id'] as String) == 'food_dates_medjool'
              ? 'verified_official_record'
              : 'reference_seed'),
    );
  }

  Future<MealEntry> saveRecognition(
    RecognitionResult result, {
    String mealType = 'Meal',
    DateTime? eatenAt,
    String notes = '',
    String syncStatus = 'saved_locally',
    bool persist = true,
  }) async {
    final stamp = (eatenAt ?? DateTime.now()).toUtc();
    final totalNutrients = result.totalNutrients;
    final totalWeight = result.totalWeightG;
    final meal = MealEntry(
      id: 'local-${stamp.microsecondsSinceEpoch}',
      foodId: result.foodId,
      nameEn: result.isPlate
          ? result.plateNameEn
          : result.additionalItems.isEmpty
              ? result.nameEn
              : '${result.nameEn} + ${result.additionalItems.length} item(s)',
      nameAr: result.isPlate
          ? result.plateNameAr
          : result.additionalItems.isEmpty
              ? result.nameAr
              : '${result.nameAr} + ${result.additionalItems.length}',
      eatenAt: stamp,
      mealType: mealType,
      weightG: totalWeight,
      confidence: result.confidence,
      nutrients: totalNutrients,
      portionSource: result.portionSource,
      verificationStatus: result.verificationStatus,
      syncStatus: syncStatus,
      notes: notes,
      basisPer100g: totalWeight > 0 ? totalNutrients.scaledBy(100.0 / totalWeight) : totalNutrients,
      items: result.isPlate ? result.plateItems : [
        MealItemEntry(
          id: 'item-main-${stamp.microsecondsSinceEpoch}',
          foodId: result.foodId,
          nameEn: result.nameEn,
          nameAr: result.nameAr,
          weightG: result.weightG,
          nutrients: result.nutrients,
          basisPer100g: result.resolvedBasisPer100g,
          portionSource: result.portionSource,
          verificationStatus: result.verificationStatus,
        ),
        ...result.additionalItems,
      ],
    );
    return persist ? insertMealEntry(meal) : meal;
  }

  Future<MealEntry> insertMealEntry(MealEntry meal) async {
    if (_useInMemory) {
      _memMeals.removeWhere((m) => m.id == meal.id);
      _memMeals.insert(0, meal);
      _memMeals.sort((a, b) => b.eatenAt.compareTo(a.eatenAt));
      return meal;
    }
    await db.insert(
      'meals',
      {
        'id': meal.id,
        'food_id': meal.foodId,
        'name_en': meal.nameEn,
        'name_ar': meal.nameAr,
        'eaten_at': meal.eatenAt.toUtc().toIso8601String(),
        'meal_type': meal.mealType,
        'weight_g': meal.weightG,
        'confidence': meal.confidence,
        'notes': meal.notes,
        'portion_source': meal.portionSource.name,
        ..._leftoverColumns(meal),
        ...meal.servedNutrients.toDatabase(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (meal.items.length > 1) {
      for (var i = 0; i < meal.items.length; i++) {
        await db.insert(
          'meal_items',
          meal.items[i].toRow(meal.id, i),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
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
        'notes': meal.notes,
        'portion_source': meal.portionSource.name,
        ..._leftoverColumns(meal),
        ...meal.servedNutrients.toDatabase(),
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
    await db.delete('meal_items', where: 'meal_id = ?', whereArgs: [id]);
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
        'message_ar': alert.messageAr,
        'created_at': alert.createdAt.toIso8601String(),
        'evaluation_ms': alert.evaluationMs,
        'is_read': alert.read ? 1 : 0,
        'acknowledged': alert.acknowledged ? 1 : 0,
      });
    }
    await batch.commit(noResult: true);
  }

  /// Remembers which notices were already read, so they stay read after a restart.
  Future<void> updateAlertStates(List<HealthAlert> alerts) async {
    if (_useInMemory) {
      _memAlerts
        ..clear()
        ..addAll(alerts);
      return;
    }
    final batch = db.batch();
    for (final alert in alerts) {
      batch.update(
        'alerts',
        {'is_read': alert.read ? 1 : 0, 'acknowledged': alert.acknowledged ? 1 : 0},
        where: 'id = ?',
        whereArgs: [alert.id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<HealthAlert>> loadAlerts() async {
    if (_useInMemory) {
      return List.unmodifiable(_memAlerts.take(100));
    }
    final rows = await db.query('alerts', orderBy: 'created_at DESC', limit: 100);
    return rows
        .map((row) => HealthAlert(
              id: row['id'] as String,
              nutrientKey: row['nutrient_key'] as String,
              severity: row['severity'] as String,
              currentValue: (row['current_value'] as num).toDouble(),
              thresholdValue: (row['threshold_value'] as num).toDouble(),
              message: row['message'] as String,
              messageAr: row['message_ar'] as String? ?? '',
              read: row['is_read'] == 1,
              acknowledged: row['acknowledged'] == 1,
              createdAt: DateTime.parse(row['created_at'] as String),
              evaluationMs: row['evaluation_ms'] as int,
            ))
        .toList();
  }

  /// Meal photos live as files named after the meal, so the database stays small.
  Future<File> _photoFile(String mealId) async =>
      File(p.join(await getDatabasesPath(), 'meal_photos', '$mealId.jpg'));

  Future<void> saveMealPhoto(String mealId, Uint8List bytes) async {
    if (_useInMemory) {
      _memPhotos[mealId] = bytes;
      return;
    }
    final file = await _photoFile(mealId);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  Future<Uint8List?> loadMealPhoto(String mealId) async {
    if (_useInMemory) return _memPhotos[mealId];
    final file = await _photoFile(mealId);
    return await file.exists() ? file.readAsBytes() : null;
  }

  Future<void> deleteMealPhoto(String mealId) async {
    if (_useInMemory) {
      _memPhotos.remove(mealId);
      return;
    }
    final file = await _photoFile(mealId);
    if (await file.exists()) await file.delete();
  }

  /// Removes everything this app stored on this phone and goes back to the defaults.
  Future<void> deleteAllData() async {
    _memGoals = defaultGoals;
    _memHealthProfile = _defaultHealthProfile;
    _memMeals.clear();
    _memAlerts.clear();
    _memCustomFoods.clear();
    _memPhotos.clear();
    _memSettings.clear();
    _memBodyProfile = null;
    _memWeights.clear();
    if (_useInMemory) return;
    await db.delete('meals');
    await db.delete('alerts');
    await db.delete('goals');
    await db.delete('health_profile');
    await db.delete('body_profile');
    await db.delete('meal_items');
    await db.delete('body_weights');
    await db.execute('DROP TABLE IF EXISTS settings');
    await _seedGoals();
    await _seedHealthProfile();
    final photos = Directory(p.join(await getDatabasesPath(), 'meal_photos'));
    if (await photos.exists()) await photos.delete(recursive: true);
  }

  List<FoodCatalogItem> get customFoods => List.unmodifiable(_memCustomFoods);

  void addCustomFood(FoodCatalogItem item) {
    _memCustomFoods.removeWhere((f) => f.foodId == item.foodId);
    _memCustomFoods.insert(0, item);
  }

  final Map<String, String> _memSettings = {};
  BodyProfile? _memBodyProfile;
  final Map<String, BodyWeightEntry> _memWeights = {};

  Future<void> saveBodyWeight(BodyWeightEntry entry) async {
    _memWeights[entry.id] = entry;
    final database = _database;
    if (database == null || _useInMemory) return;
    await database.insert('body_weights', entry.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteBodyWeight(String id) async {
    _memWeights.remove(id);
    final database = _database;
    if (database == null || _useInMemory) return;
    await database.delete('body_weights', where: 'id = ?', whereArgs: [id]);
  }

  /// Oldest first.
  Future<List<BodyWeightEntry>> loadBodyWeights() async {
    final database = _database;
    if (database == null || _useInMemory) {
      return _memWeights.values.toList()..sort((a, b) => a.measuredOn.compareTo(b.measuredOn));
    }
    final rows = await database.query('body_weights', orderBy: 'measured_on');
    return rows.map(BodyWeightEntry.fromRow).toList();
  }

  Future<void> saveBodyProfile(BodyProfile profile) async {
    _memBodyProfile = profile;
    final database = _database;
    if (database == null || _useInMemory) return;
    await database.insert('body_profile', profile.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<BodyProfile?> loadBodyProfile() async {
    final database = _database;
    if (database == null || _useInMemory) return _memBodyProfile;
    final rows = await database.query('body_profile', limit: 1);
    return rows.isEmpty ? null : BodyProfile.fromRow(rows.first);
  }

  Future<void> saveSetting(String key, String value) async {
    _memSettings[key] = value;
    final database = _database;
    if (database == null || _useInMemory) return;
    try {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS settings(
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
      await database.insert(
        'settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<String?> getSetting(String key) async {
    final database = _database;
    if (database == null || _useInMemory) return _memSettings[key];
    try {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS settings(
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
      final rows = await database.query(
        'settings',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first['value'] as String?;
      }
    } catch (_) {}
    return _memSettings[key];
  }
}

