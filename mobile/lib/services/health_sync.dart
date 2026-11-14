import 'package:health/health.dart';

import '../models/body_profile.dart';
import '../models/glucose.dart';
import '../models/nutrition.dart';
import '../models/water.dart';

/// What Miqdar shares with Apple Health (Health Connect on Android). Off until the user turns it on.
abstract class HealthSync {
  /// Asks for permission; true when the user allowed it.
  Future<bool> requestPermission();
  Future<void> writeMeal(MealEntry meal);
  Future<void> deleteMeal(MealEntry meal);
  Future<void> writeWater(WaterEntry entry);
  Future<void> deleteWater(WaterEntry entry);
  Future<void> writeWeight(BodyWeightEntry entry);

  /// Weigh-ins from other apps and smart scales.
  Future<List<BodyWeightEntry>> readWeights(DateTime since);

  /// Blood sugar from meter and sensor apps.
  Future<List<GlucoseReading>> readGlucose(DateTime since);
}

/// HealthKit on iOS and Health Connect on Android, through the health package. Every call swallows
/// errors: Health is a convenience, and the diary on the phone stays the record.
class PlatformHealthSync implements HealthSync {
  final _health = Health();
  bool _configured = false;

  static const _writeTypes = [
    HealthDataType.NUTRITION,
    HealthDataType.WATER,
    HealthDataType.WEIGHT,
  ];
  static const _readTypes = [HealthDataType.WEIGHT, HealthDataType.BLOOD_GLUCOSE];

  Future<void> _ready() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<bool> requestPermission() async {
    try {
      await _ready();
      final types = [..._writeTypes, ..._readTypes.where((t) => !_writeTypes.contains(t))];
      final permissions = [
        for (final t in types)
          _writeTypes.contains(t)
              ? (_readTypes.contains(t) ? HealthDataAccess.READ_WRITE : HealthDataAccess.WRITE)
              : HealthDataAccess.READ,
      ];
      return await _health.requestAuthorization(types, permissions: permissions);
    } catch (_) {
      return false;
    }
  }

  static MealType _mealType(String type) => switch (type) {
        'Breakfast' || 'Suhoor' => MealType.BREAKFAST,
        'Lunch' => MealType.LUNCH,
        'Dinner' || 'Iftar' => MealType.DINNER,
        'Snack' => MealType.SNACK,
        _ => MealType.UNKNOWN,
      };

  double? _known(NutritionValues v, String key, double value) => v.isMissing(key) ? null : value;

  @override
  Future<void> writeMeal(MealEntry meal) async {
    try {
      await _ready();
      final n = meal.nutrients;
      final at = meal.eatenAt.toLocal();
      await _health.writeMeal(
        mealType: _mealType(meal.mealType),
        startTime: at,
        endTime: at.add(const Duration(seconds: 1)),
        clientRecordId: meal.id,
        name: meal.nameEn,
        caloriesConsumed: _known(n, 'calories_kcal', n.calories),
        carbohydrates: _known(n, 'carbohydrate_g', n.carbohydrates),
        protein: _known(n, 'protein_g', n.protein),
        fatTotal: _known(n, 'fat_g', n.fat),
        sugar: _known(n, 'sugar_g', n.sugar),
        fiber: _known(n, 'fiber_g', n.fiber),
        // The package takes sodium and potassium in grams.
        sodium: n.isMissing('sodium_mg') ? null : n.sodium / 1000,
        potassium: n.isMissing('potassium_mg') ? null : n.potassium / 1000,
      );
    } catch (_) {}
  }

  @override
  Future<void> deleteMeal(MealEntry meal) async {
    try {
      await _ready();
      final at = meal.eatenAt.toLocal();
      await _health.delete(type: HealthDataType.NUTRITION, startTime: at, endTime: at.add(const Duration(seconds: 1)));
    } catch (_) {}
  }

  @override
  Future<void> writeWater(WaterEntry entry) async {
    try {
      await _ready();
      final at = entry.at.toLocal();
      await _health.writeHealthData(
        value: entry.ml / 1000,
        type: HealthDataType.WATER,
        unit: HealthDataUnit.LITER,
        startTime: at,
        endTime: at.add(const Duration(seconds: 1)),
        clientRecordId: entry.id,
      );
    } catch (_) {}
  }

  @override
  Future<void> deleteWater(WaterEntry entry) async {
    try {
      await _ready();
      final at = entry.at.toLocal();
      await _health.delete(type: HealthDataType.WATER, startTime: at, endTime: at.add(const Duration(seconds: 1)));
    } catch (_) {}
  }

  @override
  Future<void> writeWeight(BodyWeightEntry entry) async {
    try {
      await _ready();
      final at = DateTime(entry.measuredOn.year, entry.measuredOn.month, entry.measuredOn.day, 8);
      await _health.writeHealthData(
        value: entry.weightKg,
        type: HealthDataType.WEIGHT,
        unit: HealthDataUnit.KILOGRAM,
        startTime: at,
        endTime: at,
        clientRecordId: entry.id,
      );
    } catch (_) {}
  }

  Future<List<HealthDataPoint>> _read(HealthDataType type, DateTime since) async {
    try {
      await _ready();
      final points = await _health.getHealthDataFromTypes(types: [type], startTime: since, endTime: DateTime.now());
      return _health.removeDuplicates(points);
    } catch (_) {
      return const [];
    }
  }

  static double? _value(HealthDataPoint p) {
    final v = p.value;
    return v is NumericHealthValue ? v.numericValue.toDouble() : null;
  }

  @override
  Future<List<BodyWeightEntry>> readWeights(DateTime since) async => [
        for (final p in await _read(HealthDataType.WEIGHT, since))
          if (_value(p) != null && p.sourceName != 'Miqdar')
            BodyWeightEntry(id: 'health-weight-${p.dateFrom.millisecondsSinceEpoch}', measuredOn: p.dateFrom, weightKg: _value(p)!),
      ];

  @override
  Future<List<GlucoseReading>> readGlucose(DateTime since) async => [
        for (final p in await _read(HealthDataType.BLOOD_GLUCOSE, since))
          if (_value(p) != null)
            GlucoseReading(
              id: 'health-glucose-${p.dateFrom.millisecondsSinceEpoch}',
              mgdl: p.unit == HealthDataUnit.MILLIMOLES_PER_LITER ? _value(p)! * 18 : _value(p)!,
              at: p.dateFrom,
              tag: GlucoseTag.other,
              fromHealth: true,
            ),
      ];
}
