import 'nutrition.dart';

/// mg/dL is used in Saudi practice and is what Miqdar stores; mmol/L is shown by dividing by 18.
enum GlucoseUnit {
  mgdl,
  mmol;

  static const _factor = 18.0;

  double fromMgdl(double mgdl) => this == mmol ? mgdl / _factor : mgdl;
  double toMgdl(double value) => this == mmol ? value * _factor : value;
  String format(double mgdl) => this == mmol ? fromMgdl(mgdl).toStringAsFixed(1) : mgdl.toStringAsFixed(0);
  String label(bool isAr) => this == mmol ? (isAr ? 'مليمول/لتر' : 'mmol/L') : (isAr ? 'ملغ/دسل' : 'mg/dL');
}

enum GlucoseTag {
  beforeMeal,
  afterMeal,
  other;

  String label(bool isAr) => switch (this) {
        GlucoseTag.beforeMeal => isAr ? 'قبل الوجبة' : 'Before meal',
        GlucoseTag.afterMeal => isAr ? 'بعد الوجبة بساعتين' : '2 hours after',
        GlucoseTag.other => isAr ? 'أخرى' : 'Other',
      };
}

/// A blood sugar reading the user typed or Apple Health gave. A plain log: Miqdar never judges it.
class GlucoseReading {
  const GlucoseReading({
    required this.id,
    required this.mgdl,
    required this.at,
    required this.tag,
    this.fromHealth = false,
  });

  final String id;
  final double mgdl;
  final DateTime at;
  final GlucoseTag tag;
  final bool fromHealth;

  Map<String, Object?> toRow() => {
        'id': id,
        'mgdl': mgdl,
        'at': at.toUtc().toIso8601String(),
        'tag': tag.name,
        'from_health': fromHealth ? 1 : 0,
      };

  factory GlucoseReading.fromRow(Map<String, Object?> row) => GlucoseReading(
        id: row['id'] as String,
        mgdl: (row['mgdl'] as num).toDouble(),
        at: DateTime.parse(row['at'] as String),
        tag: GlucoseTag.values.asNameMap()[row['tag']] ?? GlucoseTag.other,
        fromHealth: row['from_health'] == 1,
      );
}

/// How far from a meal a reading still belongs to it.
const _window = Duration(hours: 3);

/// The meal a reading belongs to: before a meal, the next one; after, the one before; otherwise
/// the nearest. None when no meal is within three hours.
MealEntry? mealForReading(GlucoseReading reading, List<MealEntry> meals) {
  bool near(MealEntry m) => (m.eatenAt.difference(reading.at)).abs() <= _window;
  final candidates = meals.where(near).toList();
  if (candidates.isEmpty) return null;
  Iterable<MealEntry> pool = candidates;
  if (reading.tag == GlucoseTag.beforeMeal) {
    final after = candidates.where((m) => !m.eatenAt.isBefore(reading.at));
    if (after.isNotEmpty) pool = after;
  } else if (reading.tag == GlucoseTag.afterMeal) {
    final before = candidates.where((m) => !m.eatenAt.isAfter(reading.at));
    if (before.isNotEmpty) pool = before;
  }
  return pool.reduce((a, b) =>
      (a.eatenAt.difference(reading.at)).abs() <= (b.eatenAt.difference(reading.at)).abs() ? a : b);
}

/// A reading as the doctor's report lists it, beside its meal.
class ReportReading {
  const ReportReading({required this.at, required this.mgdl, required this.tag, this.mealName, this.mealCarbsG});

  final DateTime at;
  final double mgdl;
  final GlucoseTag tag;
  final String? mealName;
  final double? mealCarbsG;
}
