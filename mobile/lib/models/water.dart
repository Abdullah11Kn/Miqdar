/// One drink of water, in millilitres.
class WaterEntry {
  const WaterEntry({required this.id, required this.ml, required this.at});

  final String id;
  final double ml;
  final DateTime at;

  Map<String, Object?> toRow() => {'id': id, 'ml': ml, 'at': at.toUtc().toIso8601String()};

  factory WaterEntry.fromRow(Map<String, Object?> row) => WaterEntry(
        id: row['id'] as String,
        ml: (row['ml'] as num).toDouble(),
        at: DateTime.parse(row['at'] as String),
      );
}

/// The daily water goal from body weight: about 35 ml per kg, rounded to 50 ml.
double waterGoalFromWeight(double? weightKg) {
  if (weightKg == null || weightKg <= 0) return 2000;
  return ((weightKg * 35) / 50).round() * 50.0;
}
