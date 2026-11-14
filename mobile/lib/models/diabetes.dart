import 'body_profile.dart';
import 'nutrition.dart';

enum DiabetesType { type1, type2, other, notSure }

/// Where the per-meal carb numbers came from. [waiting] means the user chose to wait for a doctor.
enum CarbPlanSource { none, suggested, doctor, waiting }

/// Why no carb number is suggested. A fixed starting number is riskiest for these people,
/// so the app says their care team should set it (docs/research/diabetes-carb-guidance.md).
enum CarbAdviceBlock { type1, insulin, pregnancy, underAge, kidney, fasting }

/// The diabetes answers and carb numbers. Stays on the phone, like the body profile.
class DiabetesSettings {
  const DiabetesSettings({
    this.hasDiabetes = false,
    this.type = DiabetesType.notSure,
    this.usesInsulin = false,
    this.mealCarbsG,
    this.snackCarbsG,
    this.source = CarbPlanSource.none,
  });

  final bool hasDiabetes;
  final DiabetesType type;
  final bool usesInsulin;
  final double? mealCarbsG;
  final double? snackCarbsG;
  final CarbPlanSource source;

  /// Carbs come first, in grams and portions, only when this is on.
  bool get carbsFirst => hasDiabetes;

  bool get hasPlan =>
      hasDiabetes && (source == CarbPlanSource.suggested || source == CarbPlanSource.doctor) && mealCarbsG != null;

  /// The planned carbs for one meal of [mealType], or null without a plan.
  double? carbTargetFor(String mealType) {
    if (!hasPlan) return null;
    return mealType == 'Snack' ? (snackCarbsG ?? mealCarbsG) : mealCarbsG;
  }

  /// The day's carb limit: one carb number per main meal plus one snack, or null without a plan.
  /// Ramadan has two main meals (iftar and suhoor).
  double? dayCarbLimit({int mainMeals = 3}) {
    if (!hasPlan) return null;
    return mealCarbsG! * mainMeals + (snackCarbsG ?? 0);
  }

  DiabetesSettings copyWith({
    bool? hasDiabetes,
    DiabetesType? type,
    bool? usesInsulin,
    double? mealCarbsG,
    double? snackCarbsG,
    CarbPlanSource? source,
    bool clearPlan = false,
  }) =>
      DiabetesSettings(
        hasDiabetes: hasDiabetes ?? this.hasDiabetes,
        type: type ?? this.type,
        usesInsulin: usesInsulin ?? this.usesInsulin,
        mealCarbsG: clearPlan ? null : (mealCarbsG ?? this.mealCarbsG),
        snackCarbsG: clearPlan ? null : (snackCarbsG ?? this.snackCarbsG),
        source: clearPlan ? (source ?? CarbPlanSource.none) : (source ?? this.source),
      );

  Map<String, Object?> toJson() => {
        'has_diabetes': hasDiabetes,
        'type': type.name,
        'uses_insulin': usesInsulin,
        'meal_carbs_g': mealCarbsG,
        'snack_carbs_g': snackCarbsG,
        'source': source.name,
      };

  factory DiabetesSettings.fromJson(Map<String, dynamic> json) => DiabetesSettings(
        hasDiabetes: json['has_diabetes'] == true,
        type: DiabetesType.values.asNameMap()[json['type']] ?? DiabetesType.notSure,
        usesInsulin: json['uses_insulin'] == true,
        mealCarbsG: (json['meal_carbs_g'] as num?)?.toDouble(),
        snackCarbsG: (json['snack_carbs_g'] as num?)?.toDouble(),
        source: CarbPlanSource.values.asNameMap()[json['source']] ?? CarbPlanSource.none,
      );
}

/// Carb portions as diabetes education teaches them: 15 g each, to the nearest half.
double carbPortions(double grams) => (grams / 15 * 2).round() / 2;

String formatPortions(double portions) =>
    portions % 1 == 0 ? portions.toStringAsFixed(0) : portions.toStringAsFixed(1);

/// Why no number is suggested, or null when one can be.
CarbAdviceBlock? carbAdviceBlock(
  DiabetesSettings settings, {
  BodyProfile? profile,
  bool kidneyDisease = false,
  bool fasting = false,
  DateTime? now,
}) {
  if (settings.type == DiabetesType.type1) return CarbAdviceBlock.type1;
  if (settings.usesInsulin) return CarbAdviceBlock.insulin;
  if (profile?.pregnantOrBreastfeeding ?? false) return CarbAdviceBlock.pregnancy;
  if (profile != null && profile.ageOn(now ?? DateTime.now()) < 18) return CarbAdviceBlock.underAge;
  if (kidneyDisease) return CarbAdviceBlock.kidney;
  if (fasting) return CarbAdviceBlock.fasting;
  return null;
}

/// The common starting point taught in diabetes education: 45 g a meal for women, 60 g for men,
/// 15 g a snack. Without a body profile the lower number is used.
({double meal, double snack}) suggestedCarbs(BodyProfile? profile) =>
    (meal: profile?.sex == BodySex.male ? 60 : 45, snack: 15);

/// Average carbs at each meal type, over the days that had that meal. [dayOf] gives a meal's diary
/// day, so Ramadan's noon-to-noon day can be passed in. Meals with unknown carbs are left out.
Map<String, double> averageCarbsByMealType(Iterable<MealEntry> meals, DateTime Function(DateTime) dayOf) {
  final perDay = <String, Map<DateTime, double>>{};
  for (final meal in meals) {
    if (meal.nutrients.isMissing('carbohydrate_g')) continue;
    final days = perDay.putIfAbsent(meal.mealType, () => {});
    final day = dayOf(meal.eatenAt);
    days[day] = (days[day] ?? 0) + meal.nutrients.carbohydrates;
  }
  return {
    for (final entry in perDay.entries)
      entry.key: entry.value.values.fold(0.0, (a, b) => a + b) / entry.value.length,
  };
}
