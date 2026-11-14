import 'package:flutter_test/flutter_test.dart';
import 'package:miqdar_mobile/models/adaptive_goal.dart';
import 'package:miqdar_mobile/models/body_profile.dart';
import 'package:miqdar_mobile/models/nutrition.dart';

final _today = DateTime(2026, 11, 14);
DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

MealEntry _meal(int daysAgo, double kcal) => MealEntry(
      id: 'm$daysAgo-$kcal',
      foodId: 'f',
      nameEn: 'Meal',
      nameAr: '',
      eatenAt: DateTime(_today.year, _today.month, _today.day - daysAgo, 13),
      mealType: 'Lunch',
      weightG: 100,
      confidence: 1,
      nutrients: NutritionValues(
        calories: kcal, protein: 0, carbohydrates: 0, fat: 0, sugar: 0, fiber: 0, sodium: 0, potassium: 0),
    );

BodyWeightEntry _weight(int daysAgo, double kg) => BodyWeightEntry(
      id: 'w$daysAgo',
      measuredOn: DateTime(_today.year, _today.month, _today.day - daysAgo),
      weightKg: kg,
    );

AdaptiveGoal? _suggest(List<MealEntry> meals, List<BodyWeightEntry> weights,
        {WeightGoal goal = WeightGoal.maintain, double? pace, double current = 2000, BodySex sex = BodySex.male}) =>
    suggestAdaptiveGoal(
      meals: meals,
      weights: weights,
      today: _today,
      dayOf: _dayOf,
      goal: goal,
      weeklyPaceKg: pace,
      sex: sex,
      currentGoalKcal: current,
    );

void main() {
  // Worked example: 2,200 kcal every day for the 21 days before today, while weight falls
  // steadily from 80.0 to 79.4 kg over 20 days (0.03 kg a day). Burn = 2,200 + 0.03 x 7,700 = 2,431.
  final threeWeeks = [for (var d = 1; d <= 21; d++) _meal(d, 2200)];
  final falling = [_weight(21, 80.0), _weight(11, 79.7), _weight(1, 79.4)];

  test('works out the daily burn from intake and the weight trend', () {
    final s = _suggest(threeWeeks, falling)!;
    expect(s.dailyBurnKcal, closeTo(2431, 1));
    expect(s.suggestedKcal, 2450); // maintain: the burn, rounded to 50
    expect(s.loggedDays, 21);
  });

  test('to lose 0.5 kg a week it takes off 550 kcal a day', () {
    final s = _suggest(threeWeeks, falling, goal: WeightGoal.lose, pace: 0.5)!;
    expect(s.suggestedKcal, 1900); // 2,431 - 550 = 1,881, rounded to 50
  });

  test('never below the safe minimum', () {
    final s = _suggest(threeWeeks, falling, goal: WeightGoal.lose, pace: 1.0, sex: BodySex.female)!;
    expect(s.suggestedKcal, greaterThanOrEqualTo(1300));
  });

  test('needs 14 days with meals on 10 of them', () {
    final fewDays = [for (var d = 1; d <= 9; d++) _meal(d, 2200)];
    expect(_suggest(fewDays, falling), isNull);
  });

  test('needs 3 weight entries', () {
    expect(_suggest(threeWeeks, falling.take(2).toList()), isNull);
  });

  test('stays quiet when the suggestion is within 100 kcal of the current goal', () {
    expect(_suggest(threeWeeks, falling, current: 2400), isNull);
  });

  test("today's meals do not count, because the day is not over", () {
    final withToday = [...threeWeeks, _meal(0, 5000)];
    expect(_suggest(withToday, falling)!.dailyBurnKcal, closeTo(2431, 1));
  });
}
