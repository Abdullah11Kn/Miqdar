import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../data/food_catalog.dart';
import '../data/local_database.dart';
import '../models/body_profile.dart';
import '../models/diabetes.dart';
import '../models/glucose.dart';
import '../models/nutrition.dart';
import '../models/water.dart';
import '../services/alert_service.dart';

/// Ready-made stories for showing Miqdar to someone, each started from the splash with its own
/// sample data. A scenario lives in its own database file, so nothing in it touches the real diary,
/// and leaving it returns to the diary exactly as it was.
enum Showcase {
  firstRun,
  everyday,
  diabetes,
  ramadan;

  /// The database file this scenario keeps its data in.
  String get fileName => 'miqdar_showcase_$name.db';

  static Showcase? byName(String? value) => Showcase.values.asNameMap()[value];
}

/// What the scenario keeps from the app it was started from: language, look and the scale's address.
class ShowcaseCarryOver {
  const ShowcaseCarryOver({
    this.locale = 'en',
    this.dark = false,
    this.apiBaseUrl,
    this.lastCaptureEvent,
  });

  final String locale;
  final bool dark;
  final String? apiBaseUrl;

  /// The scale's last capture, already seen, so it does not reopen as a new meal in the scenario.
  final String? lastCaptureEvent;
}

/// One sample food: values per 100 g, and the free sugar (WHO) the warnings count.
class _Food {
  const _Food(this.key, this.en, this.ar, this.per100, {this.freeSugarPer100 = 0, this.photo});

  final String key;
  final String en;
  final String ar;
  final NutritionValues per100;
  final double freeSugarPer100;
  final String? photo;

  NutritionValues forGrams(double g) {
    final n = per100.forPortionGrams(g);
    return NutritionValues(
      calories: n.calories,
      protein: n.protein,
      carbohydrates: n.carbohydrates,
      fat: n.fat,
      sugar: n.sugar,
      fiber: n.fiber,
      sodium: n.sodium,
      potassium: n.potassium,
      freeSugar: freeSugarPer100 * g / 100,
    );
  }
}

NutritionValues _n(double kcal, double p, double c, double f, double s, double fib, double na, double k) =>
    NutritionValues(calories: kcal, protein: p, carbohydrates: c, fat: f, sugar: s, fiber: fib, sodium: na, potassium: k);

_Food _catalog(String id, {double freeSugar = 0, String? photo}) {
  final item = MiqdarFoodCatalog.builtInFoods.firstWhere((f) => f.foodId == id);
  return _Food(id.replaceFirst('food_', ''), item.nameEn, item.nameAr, item.per100g,
      freeSugarPer100: freeSugar, photo: photo);
}

class _Foods {
  static final kabsa = _catalog('food_chicken_kabsa', freeSugar: 0.3, photo: 'assets/demo/kabsa.jpg');
  static final mandi = _catalog('food_chicken_mandi', photo: 'assets/welcome/mandi-plate.jpg');
  static final jareesh = _catalog('food_jareesh', photo: 'assets/demo/jareesh.jpeg');
  static final saleeg = _catalog('food_saleeg');
  static final margoog = _catalog('food_margoog');
  static final chicken = _catalog('food_chicken_breast_roasted', photo: 'assets/welcome/grilled-chicken.jpg');
  static final hummus = _catalog('food_hummus_prepared', photo: 'assets/welcome/hummus.jpg');
  static final eggs = _catalog('food_egg_boiled');
  static final yogurt = _catalog('food_greek_yogurt');
  static final dates = _catalog('food_dates_sukari');
  static final almonds = _catalog('food_almonds_raw');
  static final apple = _catalog('food_apple_raw');
  static final salad = _catalog('food_garden_salad');
  static final shawarma = _catalog('food_chicken_shawarma', photo: 'assets/demo/shawarma.jpeg');
  static final falafel = _catalog('food_falafel_wrap', photo: 'assets/welcome/falafel-pita.jpg');
  static final pizza = _catalog('food_pizza_margherita', freeSugar: 1.5, photo: 'assets/demo/pizza.jpeg');
  static final burger = _catalog('food_chicken_burger', freeSugar: 2, photo: 'assets/demo/burger.jpg');
  static final rice = _catalog('food_rice_white_cooked');
  static final tuna = _catalog('food_tuna_salad');

  static final harees =
      _Food('harees', 'Harees', 'هريس', _n(110, 6, 15, 3, 0.5, 2, 250, 120), photo: 'assets/welcome/harees.jpg');
  static final foul = _Food('foul', 'Foul medames', 'فول مدمس', _n(110, 7, 15, 3, 1, 5, 300, 300));
  static final tamees = _Food('tamees', 'Tamees bread', 'خبز تميس', _n(270, 9, 52, 3, 3, 3, 500, 120), freeSugarPer100: 2);
  static final lentilSoup = _Food('lentil_soup', 'Lentil soup', 'شوربة عدس', _n(70, 4.5, 11, 1.2, 1.5, 3, 300, 200));
  static final samboosa = _Food('samboosa', 'Samboosa', 'سمبوسة', _n(290, 8, 28, 16, 2, 2, 450, 150), freeSugarPer100: 0.5);
  static final kunafa = _Food('kunafa', 'Kunafa', 'كنافة', _n(400, 7, 45, 21, 25, 1, 250, 100), freeSugarPer100: 24);
  /// A laban carton, as if its barcode was found in Open Food Facts.
  static final laban = _Food('laban', 'Laban (cultured milk)', 'لبن', _n(60, 3.3, 4.7, 3.3, 4.7, 0, 50, 150));
}

/// Writes one scenario's sample data into its own, empty database.
class ShowcaseSeeder {
  ShowcaseSeeder(this.db, {DateTime? now}) : now = now ?? DateTime.now();

  final LocalDatabase db;
  final DateTime now;
  int _next = 0;
  final Map<String, Uint8List?> _photos = {};

  DateTime get _today => DateTime(now.year, now.month, now.day);

  DateTime _at(int daysAgo, int hour, [int minute = 0]) {
    final d = _today.subtract(Duration(days: daysAgo));
    return DateTime(d.year, d.month, d.day, hour, minute);
  }

  /// Only moments already past belong in the diary.
  bool _past(DateTime t) => t.isBefore(now.subtract(const Duration(minutes: 10)));

  Future<void> seed(Showcase showcase, ShowcaseCarryOver carry) async {
    await db.saveSetting('locale', carry.locale);
    await db.saveSetting('theme', carry.dark ? 'dark' : 'light');
    if (carry.apiBaseUrl != null && carry.apiBaseUrl!.isNotEmpty) await db.saveSetting('api_base_url', carry.apiBaseUrl!);
    if (carry.lastCaptureEvent != null) await db.saveSetting('last_capture_event', carry.lastCaptureEvent!);
    switch (showcase) {
      case Showcase.firstRun:
        return; // A phone that has never opened Miqdar.
      case Showcase.everyday:
        await _everyday();
      case Showcase.diabetes:
        await _diabetes();
      case Showcase.ramadan:
        await _ramadan();
    }
  }

  Future<void> _person({
    required String en,
    required String ar,
    required BodyProfile profile,
    double? goalBasisKg,
    NutritionGoals Function(NutritionGoals goals)? adjust,
  }) async {
    await db.saveSetting('onboarded', '1');
    await db.saveSetting('body_profile_first_run', '0');
    await db.saveSetting('account_name', en);
    await db.saveSetting('account_name_ar', ar);
    await db.saveBodyProfile(profile);
    final goals = suggestGoals(profile, LocalDatabase.defaultGoals, now).goals!;
    await db.saveGoals(adjust == null ? goals : adjust(goals));
    await db.saveSetting('goal_weight_kg', (goalBasisKg ?? profile.weightKg).toString());
  }

  Future<Uint8List?> _photo(String? asset) async {
    if (asset == null) return null;
    if (_photos.containsKey(asset)) return _photos[asset];
    try {
      return _photos[asset] = (await rootBundle.load(asset)).buffer.asUint8List();
    } catch (_) {
      return _photos[asset] = null;
    }
  }

  /// One food, weighed on the scale and named by Gemini, as a real meal would be.
  Future<MealEntry?> _meal(
    _Food food,
    double grams,
    DateTime at,
    String type, {
    int? pieces,
    bool favourite = false,
    double? leftoverG,
    String idPrefix = aiFoodIdPrefix,
    PortionSource source = PortionSource.scale,
  }) async {
    if (!_past(at)) return null;
    final id = 'showcase-${_next++}';
    final nutrients = food.forGrams(grams);
    final meal = MealEntry(
      id: id,
      foodId: '$idPrefix${food.key}',
      nameEn: food.en,
      nameAr: food.ar,
      eatenAt: at.toUtc(),
      mealType: type,
      weightG: grams,
      confidence: 0.9,
      nutrients: nutrients,
      basisPer100g: food.forGrams(100),
      portionSource: source,
      verificationStatus: idPrefix == barcodeFoodIdPrefix ? barcodeStatus : aiEstimateStatus,
      favourite: favourite,
      pieceCount: pieces,
      leftover: leftoverG == null ? null : MealLeftover(grams: leftoverG, weighedAt: at.add(const Duration(minutes: 40))),
    );
    await db.insertMealEntry(meal);
    final photo = await _photo(food.photo);
    if (photo != null) await db.saveMealPhoto(id, photo);
    return meal;
  }

  /// A mixed plate: each food weighed in turn on the scale, analyzed together.
  Future<MealEntry?> _plate(String en, String ar, List<(_Food, double)> parts, DateTime at, String type) async {
    if (!_past(at)) return null;
    final id = 'showcase-${_next++}';
    final items = [
      for (var i = 0; i < parts.length; i++)
        MealItemEntry(
          id: '$id-item-$i',
          foodId: '$aiFoodIdPrefix${parts[i].$1.key}',
          nameEn: parts[i].$1.en,
          nameAr: parts[i].$1.ar,
          weightG: parts[i].$2,
          nutrients: parts[i].$1.forGrams(parts[i].$2),
          basisPer100g: parts[i].$1.forGrams(100),
          verificationStatus: aiEstimateStatus,
        ),
    ];
    final total = items.map((i) => i.nutrients).reduce(_add);
    final grams = parts.fold(0.0, (sum, p) => sum + p.$2);
    final meal = MealEntry(
      id: id,
      foodId: '${aiFoodIdPrefix}plate-$id',
      nameEn: en,
      nameAr: ar,
      eatenAt: at.toUtc(),
      mealType: type,
      weightG: grams,
      confidence: 0.88,
      nutrients: total,
      basisPer100g: total.scaledBy(100 / grams),
      verificationStatus: aiEstimateStatus,
      items: items,
    );
    await db.insertMealEntry(meal);
    final photo = await _photo(parts.first.$1.photo);
    if (photo != null) await db.saveMealPhoto(id, photo);
    return meal;
  }

  static NutritionValues _add(NutritionValues a, NutritionValues b) => NutritionValues(
        calories: a.calories + b.calories,
        protein: a.protein + b.protein,
        carbohydrates: a.carbohydrates + b.carbohydrates,
        fat: a.fat + b.fat,
        sugar: a.sugar + b.sugar,
        fiber: a.fiber + b.fiber,
        sodium: a.sodium + b.sodium,
        potassium: a.potassium + b.potassium,
        freeSugar: (a.freeSugar ?? 0) + (b.freeSugar ?? 0),
      );

  Future<void> _water(int daysAgo, List<(int, double)> cups) async {
    for (final (hour, ml) in cups) {
      final at = _at(daysAgo, hour, 15);
      if (_past(at)) await db.saveWater(WaterEntry(id: 'showcase-water-${_next++}', ml: ml, at: at.toUtc()));
    }
  }

  Future<void> _weights(List<(int, double)> entries) async {
    for (final (daysAgo, kg) in entries) {
      await db.saveBodyWeight(BodyWeightEntry(id: 'showcase-weight-$daysAgo', measuredOn: _at(daysAgo, 7), weightKg: kg));
    }
  }

  Future<void> _glucose(DateTime at, double mgdl, GlucoseTag tag) async {
    if (!_past(at)) return;
    await db.saveGlucose(GlucoseReading(id: 'showcase-glucose-${_next++}', mgdl: mgdl, at: at.toUtc(), tag: tag));
  }

  // ---------------------------------------------------------------------------------------------
  // Khalid: three weeks of ordinary use, with every everyday feature in it.

  Future<void> _everyday() async {
    await _person(
      en: 'Khalid',
      ar: 'خالد',
      profile: BodyProfile(
        sex: BodySex.male,
        birthYear: now.year - 27,
        heightCm: 178,
        weightKg: 82.5,
        activity: ActivityLevel.light,
        goal: WeightGoal.lose,
        targetWeightKg: 76,
        weeklyPaceKg: 0.5,
      ),
      goalBasisKg: 84,
    );
    await _weights([(21, 84.0), (14, 83.4), (7, 82.9), (1, 82.5)]);

    final lunches = [_Foods.kabsa, _Foods.mandi, _Foods.jareesh, _Foods.saleeg, _Foods.kabsa, _Foods.margoog, _Foods.mandi];
    final lunchGrams = [380.0, 340.0, 300.0, 320.0, 360.0, 330.0, 320.0];
    for (var d = 21; d >= 1; d--) {
      final w = d % 7;
      // Breakfast
      switch (d % 4) {
        case 0:
          await _meal(_Foods.hummus, 150, _at(d, 8, 10), 'Breakfast');
        case 1:
          await _plate('Eggs with tamees', 'بيض مع تميس', [(_Foods.eggs, 100), (_Foods.tamees, 90)], _at(d, 8, 30), 'Breakfast');
        case 2:
          await _meal(_Foods.foul, 220, _at(d, 8, 0), 'Breakfast');
        default:
          await _meal(_Foods.yogurt, 170, _at(d, 7, 45), 'Breakfast');
      }
      // Lunch; yesterday's kabsa had some left on the plate.
      await _meal(lunches[w], lunchGrams[w], _at(d, 13, 20), 'Lunch',
          favourite: d == 3 && lunches[w] == _Foods.kabsa, leftoverG: d == 1 ? 90 : null);
      // Dinner, except on two busy days.
      if (d != 9 && d != 16) {
        switch (d % 5) {
          case 0:
            await _meal(_Foods.shawarma, 230, _at(d, 20, 30), 'Dinner');
          case 1:
            await _plate('Grilled chicken with salad', 'دجاج مشوي مع سلطة', [(_Foods.chicken, 180), (_Foods.salad, 150)],
                _at(d, 20, 0), 'Dinner');
          case 2:
            await _meal(_Foods.falafel, 170, _at(d, 21, 0), 'Dinner');
          case 3:
            await _meal(d < 8 ? _Foods.pizza : _Foods.burger, d < 8 ? 214 : 190, _at(d, 21, 15), 'Dinner');
          default:
            await _meal(_Foods.tuna, 200, _at(d, 19, 45), 'Dinner');
        }
      }
      // Snack: dates counted by Gemini, almonds, an apple, or laban by its barcode.
      switch (d % 4) {
        case 0:
          await _meal(_Foods.dates, 45, _at(d, 16, 30), 'Snack', pieces: 3, favourite: d == 4);
        case 1:
          await _meal(_Foods.almonds, 28, _at(d, 17, 0), 'Snack');
        case 2:
          await _meal(_Foods.apple, 180, _at(d, 16, 0), 'Snack');
        default:
          await _meal(_Foods.laban, 250, _at(d, 16, 45), 'Snack', idPrefix: barcodeFoodIdPrefix);
      }
      await _water(d, [(9, 250), (13, 500), (17, 250), (21, 500)]);
    }
    // Today so far: breakfast and two glasses of water. Lunch is left for the live demo.
    await _meal(_Foods.hummus, 150, _at(0, 8, 15), 'Breakfast');
    await _water(0, [(8, 250), (11, 250)]);
  }

  // ---------------------------------------------------------------------------------------------
  // Noura: type 2 diabetes, Miqdar's carb numbers, blood sugar beside her meals.

  Future<void> _diabetes() async {
    const settings = DiabetesSettings(
      hasDiabetes: true,
      type: DiabetesType.type2,
      mealCarbsG: 45,
      snackCarbsG: 15,
      source: CarbPlanSource.suggested,
      sugarSource: SugarLimitSource.recommended,
    );
    final profile = BodyProfile(
      sex: BodySex.female,
      birthYear: now.year - 52,
      heightCm: 160,
      weightKg: 74,
      activity: ActivityLevel.light,
      goal: WeightGoal.lose,
      targetWeightKg: 68,
      weeklyPaceKg: 0.25,
    );
    await _person(en: 'Noura', ar: 'نورة', profile: profile);
    await db.saveSetting('diabetes', jsonEncode(settings.toJson()));
    await _weights([(20, 75.1), (13, 74.7), (6, 74.3), (1, 74.0)]);

    for (var d = 14; d >= 1; d--) {
      // Breakfast with a fasting reading before it and one two hours after.
      final breakfast = _at(d, 7, 30);
      await _glucose(breakfast.subtract(const Duration(minutes: 20)), 112 + (d * 7) % 22, GlucoseTag.beforeMeal);
      switch (d % 3) {
        case 0:
          await _plate('Eggs with tamees', 'بيض مع تميس', [(_Foods.eggs, 100), (_Foods.tamees, 60)], breakfast, 'Breakfast');
        case 1:
          await _meal(_Foods.foul, 200, breakfast, 'Breakfast');
        default:
          await _plate('Yogurt with apple', 'زبادي مع تفاح', [(_Foods.yogurt, 170), (_Foods.apple, 120)], breakfast, 'Breakfast');
      }
      await _glucose(breakfast.add(const Duration(hours: 2)), 140 + (d * 11) % 30, GlucoseTag.afterMeal);

      // Lunch about one carb number. On day 5 a larger kabsa went past it.
      final lunch = _at(d, 13, 30);
      switch (d % 3) {
        case 0:
          await _meal(_Foods.kabsa, d == 5 ? 330 : 210, lunch, 'Lunch');
        case 1:
          await _meal(_Foods.jareesh, 230, lunch, 'Lunch');
        default:
          await _plate('Grilled chicken, rice and salad', 'دجاج مشوي مع رز وسلطة',
              [(_Foods.chicken, 150), (_Foods.rice, 100), (_Foods.salad, 150)], lunch, 'Lunch');
      }
      await _glucose(lunch.add(const Duration(hours: 2)), d == 5 ? 214 : 150 + (d * 13) % 28, GlucoseTag.afterMeal);

      // Snack: two dates, counted; or almonds.
      if (d.isEven) {
        await _meal(_Foods.dates, 30, _at(d, 17, 0), 'Snack', pieces: 2, favourite: d == 2);
      } else {
        await _meal(_Foods.almonds, 25, _at(d, 17, 0), 'Snack');
      }
      // Dinner
      await _meal(d.isEven ? _Foods.lentilSoup : _Foods.tuna, d.isEven ? 250 : 200, _at(d, 20, 0), 'Dinner');
      await _water(d, [(8, 250), (12, 500), (16, 250), (20, 250)]);
    }

    // Yesterday evening: kunafa at a family visit, well past her sugar limit. It is in the bell.
    final yesterdayBefore = await db.loadMeals(days: 3);
    final eveningOf = _at(1, 18, 30);
    final kunafa = await _meal(_Foods.kunafa, 120, eveningOf, 'Snack');
    await _glucose(eveningOf.add(const Duration(hours: 2)), 228, GlucoseTag.afterMeal);
    if (kunafa != null) {
      final goals = await db.loadGoals();
      final dayBefore = yesterdayBefore
          .where((m) => DateTime(m.eatenAt.toLocal().year, m.eatenAt.toLocal().month, m.eatenAt.toLocal().day) ==
              DateTime(eveningOf.year, eveningOf.month, eveningOf.day))
          .where((m) => m.eatenAt.toLocal().isBefore(eveningOf))
          .map((m) => m.nutrients)
          .fold<NutritionValues>(_n(0, 0, 0, 0, 0, 0, 0, 0), _add);
      final result = AlertService().evaluate(
        currentTotals: dayBefore,
        incoming: kunafa.nutrients,
        goals: goals.copyWith(sugar: freeSugarLimitG(goals.calories, diabetes: true)),
        context: AlertContext(
          hasDiabetes: true,
          weightGoal: profile.goal,
          mealCarbLimitG: settings.snackCarbsG,
          dayCarbLimitG: settings.dayCarbLimit(),
        ),
        incomingWeightG: 120,
      );
      await db.saveAlerts([
        for (final a in result.alerts)
          HealthAlert(
            id: 'showcase-${a.id}',
            nutrientKey: a.nutrientKey,
            severity: a.severity,
            currentValue: a.currentValue,
            thresholdValue: a.thresholdValue,
            message: a.message,
            messageAr: a.messageAr,
            createdAt: eveningOf.add(const Duration(minutes: 5)),
            evaluationMs: a.evaluationMs,
          ),
      ]);
    }

    // Today: the morning reading and breakfast. A sweet drink is ready to show the red warning.
    await _glucose(_at(0, 7, 10), 124, GlucoseTag.beforeMeal);
    await _meal(_Foods.foul, 200, _at(0, 7, 30), 'Breakfast');
    await _glucose(_at(0, 9, 30), 151, GlucoseTag.afterMeal);
    await _water(0, [(8, 250), (11, 250)]);
  }

  // ---------------------------------------------------------------------------------------------
  // Faisal: Ramadan mode, iftar and suhoor, the day running noon to noon.

  Future<void> _ramadan() async {
    await _person(
      en: 'Faisal',
      ar: 'فيصل',
      profile: BodyProfile(
        sex: BodySex.male,
        birthYear: now.year - 35,
        heightCm: 175,
        weightKg: 80,
        activity: ActivityLevel.moderate,
        goal: WeightGoal.maintain,
      ),
    );
    final start = _today.subtract(const Duration(days: 11));
    await db.saveSetting(
      'ramadan_periods',
      jsonEncode([
        {'start': start.toUtc().toIso8601String(), 'end': null},
      ]),
    );
    await _weights([(10, 80.0), (3, 79.6)]);

    for (var d = 10; d >= 0; d--) {
      // Iftar at sunset: dates and laban, then soup and samboosa as one plate, then the main dish.
      await _meal(_Foods.dates, 45, _at(d, 17, 50), 'Iftar', pieces: 3, favourite: d == 2);
      await _meal(_Foods.laban, 250, _at(d, 17, 52), 'Iftar', idPrefix: barcodeFoodIdPrefix);
      await _plate('Lentil soup and samboosa', 'شوربة عدس وسمبوسة', [(_Foods.lentilSoup, 250), (_Foods.samboosa, 80)],
          _at(d, 18, 10), 'Iftar');
      await _meal(d.isEven ? _Foods.kabsa : _Foods.harees, d.isEven ? 320 : 300, _at(d, 20, 30), 'Iftar');
      if (d % 3 == 0) await _meal(_Foods.kunafa, 90, _at(d, 22, 0), 'Snack');
      // Suhoor before dawn, which belongs to the same diary day.
      await _plate('Foul with tamees', 'فول مع تميس', [(_Foods.foul, 200), (_Foods.tamees, 80)], _at(d - 1, 3, 30), 'Suhoor');
      await _meal(_Foods.yogurt, 170, _at(d - 1, 3, 45), 'Suhoor');
      await _water(d, [(18, 250), (19, 500), (21, 250), (23, 500)]);
      await _water(d - 1, [(1, 250), (3, 500)]);
    }
  }
}
