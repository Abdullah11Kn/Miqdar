import 'nutrition.dart';

enum BodySex { male, female }

enum ActivityLevel {
  sedentary(1.2),
  light(1.375),
  moderate(1.55),
  active(1.725),
  veryActive(1.9);

  const ActivityLevel(this.multiplier);
  final double multiplier;
}

enum WeightGoal { lose, maintain, gain }

enum BodyProfileProblem { age, height, weight, target, targetUnderweight, pace }

/// Why the app gives no calculated goal. The formula is not meant for these people.
enum GoalBlock { underAge, pregnancy }

/// Answers to the body profile. Stays on the phone and never goes to Gemini.
class BodyProfile {
  const BodyProfile({
    required this.sex,
    required this.birthYear,
    required this.heightCm,
    required this.weightKg,
    required this.activity,
    required this.goal,
    this.targetWeightKg,
    this.weeklyPaceKg,
    this.pregnantOrBreastfeeding = false,
  });

  static const minAge = 5;
  static const maxAge = 110;
  static const maxWeeklyPaceKg = 0.5;
  static const underweightBmi = 18.5;

  final BodySex sex;
  final int birthYear;
  final double heightCm;
  final double weightKg;
  final ActivityLevel activity;
  final WeightGoal goal;
  final double? targetWeightKg;
  final double? weeklyPaceKg;
  final bool pregnantOrBreastfeeding;

  int ageOn(DateTime now) => now.year - birthYear;

  /// The same person, once a target has been reached or no longer applies.
  BodyProfile get maintaining => BodyProfile(
        sex: sex,
        birthYear: birthYear,
        heightCm: heightCm,
        weightKg: weightKg,
        activity: activity,
        goal: WeightGoal.maintain,
        pregnantOrBreastfeeding: pregnantOrBreastfeeding,
      );

  BodyProfile withWeight(double kg) => BodyProfile(
        sex: sex,
        birthYear: birthYear,
        heightCm: heightCm,
        weightKg: kg,
        activity: activity,
        goal: goal,
        targetWeightKg: targetWeightKg,
        weeklyPaceKg: weeklyPaceKg,
        pregnantOrBreastfeeding: pregnantOrBreastfeeding,
      );

  /// What must be corrected before a goal can be calculated. Empty means valid.
  List<BodyProfileProblem> problems(DateTime now) {
    final age = ageOn(now);
    final found = <BodyProfileProblem>[
      if (age < minAge || age > maxAge) BodyProfileProblem.age,
      if (heightCm < 100 || heightCm > 250) BodyProfileProblem.height,
      if (weightKg < 20 || weightKg > 300) BodyProfileProblem.weight,
    ];
    if (goal == WeightGoal.maintain) return found;

    final target = targetWeightKg;
    final wrongWay = target == null ||
        target < 20 ||
        target > 300 ||
        (goal == WeightGoal.lose ? target >= weightKg : target <= weightKg);
    if (wrongWay) {
      found.add(BodyProfileProblem.target);
    } else if (goal == WeightGoal.lose && _bmi(target) < underweightBmi) {
      found.add(BodyProfileProblem.targetUnderweight);
    }
    final pace = weeklyPaceKg;
    if (pace == null || pace <= 0 || pace > maxWeeklyPaceKg) found.add(BodyProfileProblem.pace);
    return found;
  }

  double _bmi(double kg) => kg / ((heightCm / 100) * (heightCm / 100));

  Map<String, Object?> toRow() => {
        'id': 1,
        'sex': sex.name,
        'birth_year': birthYear,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'activity': activity.name,
        'goal': goal.name,
        'target_weight_kg': targetWeightKg,
        'weekly_pace_kg': weeklyPaceKg,
        'pregnant_or_breastfeeding': pregnantOrBreastfeeding ? 1 : 0,
      };

  factory BodyProfile.fromRow(Map<String, Object?> row) => BodyProfile(
        sex: BodySex.values.byName(row['sex'] as String),
        birthYear: row['birth_year'] as int,
        heightCm: (row['height_cm'] as num).toDouble(),
        weightKg: (row['weight_kg'] as num).toDouble(),
        activity: ActivityLevel.values.byName(row['activity'] as String),
        goal: WeightGoal.values.byName(row['goal'] as String),
        targetWeightKg: (row['target_weight_kg'] as num?)?.toDouble(),
        weeklyPaceKg: (row['weekly_pace_kg'] as num?)?.toDouble(),
        pregnantOrBreastfeeding: row['pregnant_or_breastfeeding'] == 1,
      );
}

class GoalSuggestion {
  const GoalSuggestion({this.goals, this.block, this.limitedToMinimum = false});

  /// Null when [block] says no goal can be calculated.
  final NutritionGoals? goals;
  final GoalBlock? block;

  /// The plan asked for fewer calories than the safe minimum, so the minimum is used.
  final bool limitedToMinimum;
}

/// Mifflin-St Jeor, adjusted for the weekly pace. Expects a profile with no [BodyProfile.problems].
/// Nutrients the profile says nothing about (sugar, sodium and so on) keep their values from [base].
GoalSuggestion suggestGoals(BodyProfile profile, NutritionGoals base, DateTime now) {
  final age = profile.ageOn(now);
  if (age < 18) return const GoalSuggestion(block: GoalBlock.underAge);
  final isFemale = profile.sex == BodySex.female;
  if (isFemale && profile.pregnantOrBreastfeeding) {
    return const GoalSuggestion(block: GoalBlock.pregnancy);
  }

  final restingKcal = 10 * profile.weightKg + 6.25 * profile.heightCm - 5 * age + (isFemale ? -161 : 5);
  final pace = (profile.weeklyPaceKg ?? 0).clamp(0.0, BodyProfile.maxWeeklyPaceKg);
  const kcalPerDayPerKgPerWeek = 7700 / 7;
  final change = switch (profile.goal) {
    WeightGoal.lose => -pace * kcalPerDayPerKgPerWeek,
    WeightGoal.gain => pace * kcalPerDayPerKgPerWeek,
    WeightGoal.maintain => 0.0,
  };
  final planned = restingKcal * profile.activity.multiplier + change;

  final minimum = isFemale ? 1200.0 : 1500.0;
  final calories = _roundTo(planned.clamp(minimum, 4500.0), 50);
  final protein = _roundTo((1.6 * profile.weightKg).clamp(20.0, 300.0), 5);
  final fat = _roundTo((calories * 0.3 / 9).clamp(20.0, 200.0), 5);
  final carbs = _roundTo(((calories - protein * 4 - fat * 9) / 4).clamp(30.0, 500.0), 10);

  return GoalSuggestion(
    goals: base.copyWith(
      calories: calories,
      protein: protein,
      fat: fat,
      carbohydrates: carbs,
      trackingOnly: false,
    ),
    limitedToMinimum: planned < minimum,
  );
}

double _roundTo(double value, int step) => (value / step).round() * step.toDouble();

/// A body weight the user typed in. The kitchen scale cannot weigh a person.
class BodyWeightEntry {
  const BodyWeightEntry({required this.id, required this.measuredOn, required this.weightKg});

  final String id;
  final DateTime measuredOn;
  final double weightKg;

  Map<String, Object?> toRow() => {
        'id': id,
        'measured_on': measuredOn.toIso8601String(),
        'weight_kg': weightKg,
      };

  factory BodyWeightEntry.fromRow(Map<String, Object?> row) => BodyWeightEntry(
        id: row['id'] as String,
        measuredOn: DateTime.parse(row['measured_on'] as String),
        weightKg: (row['weight_kg'] as num).toDouble(),
      );
}
