import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:miqdar_mobile/data/local_database.dart';
import 'package:miqdar_mobile/l10n/strings.dart';
import 'package:miqdar_mobile/models/body_profile.dart';
import 'package:miqdar_mobile/models/doctor_report.dart';
import 'package:miqdar_mobile/models/nutrition.dart';
import 'package:miqdar_mobile/services/report_html.dart';

MealEntry _meal(String type, DateTime at, {double kcal = 500, double carbs = 50, double sugar = 10, double sodium = 500,
        PortionSource source = PortionSource.scale}) =>
    MealEntry(
      id: '$type$at', foodId: 'f', nameEn: type, nameAr: '', eatenAt: at, mealType: type, weightG: 200, confidence: 1,
      portionSource: source,
      nutrients: NutritionValues(calories: kcal, protein: 20, carbohydrates: carbs, fat: 10, sugar: sugar, fiber: 2, sodium: sodium, potassium: 100),
    );

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

void main() {
  setUpAll(() => initializeDateFormatting());

  // 14 days ending Saturday 14 November 2026. Lunch every weekday, dinner the biggest in carbs.
  final today = DateTime(2026, 11, 14);
  final meals = <MealEntry>[
    for (var i = 0; i < 10; i++) ...[
      _meal('Lunch', DateTime(2026, 11, 1 + i, 13), carbs: 40, sugar: i < 3 ? 70 : 10),
      _meal('Dinner', DateTime(2026, 11, 1 + i, 20), carbs: 90, sodium: 2000, source: i.isEven ? PortionSource.estimated : PortionSource.scale),
    ],
  ];
  final goals = LocalDatabase.defaultGoals;

  DoctorReport build({bool carbsFirst = false, List<MealEntry>? list, List<BodyWeightEntry> weights = const []}) => buildDoctorReport(
        meals: list ?? meals,
        goals: goals,
        weights: weights,
        today: today,
        periodDays: 14,
        dayOf: _day,
        name: 'Abdullah',
        carbsFirst: carbsFirst,
      );

  test('averages count logged days only, and empty days are not logged, not zero', () {
    final r = build();
    expect(r.days, hasLength(14));
    expect(r.loggedDays, 10);
    expect(r.days.last.logged, isFalse);
    expect(r.days.last.totals, isNull);
    expect(r.dailyAverage.calories, 1000);
    expect(r.dailyAverage.carbohydrates, 130);
  });

  test('carbs by meal, goal days and source counts', () {
    final r = build();
    expect(r.carbsByMeal['Dinner'], 90);
    expect(r.carbsByMeal['Lunch'], 40);
    final sugar = r.goalDays.firstWhere((g) => g.goal == ReportGoal.sugar);
    expect(sugar.over, 3);
    expect(sugar.within, 7);
    final sodium = r.goalDays.firstWhere((g) => g.goal == ReportGoal.sodium);
    expect(sodium.over, 10);
    expect(r.goalDays.map((g) => g.goal), containsAll(ReportGoal.values));
    expect(r.weighedMeals, 15);
    expect(r.estimatedMeals, 5);
    expect(r.enteredMeals, 0);
  });

  test('pattern lines follow fixed rules', () {
    final kinds = {for (final p in build().patterns) p.kind: p};
    expect(kinds[ReportPatternKind.loggedDays]!.count, 10);
    expect(kinds[ReportPatternKind.highestCarbMeal]!.mealType, 'Dinner');
    expect(kinds[ReportPatternKind.highestCarbMeal]!.count, 10);
    expect(kinds[ReportPatternKind.daysOverSugar]!.count, 3);
  });

  test('tracking without goals leaves out the goal table and goal lines', () {
    final r = buildDoctorReport(
      meals: meals, goals: goals.copyWith(trackingOnly: true), weights: const [], today: today, periodDays: 14, dayOf: _day);
    expect(r.goalDays, isEmpty);
    expect(r.patterns.any((p) => p.kind == ReportPatternKind.daysOverSugar), isFalse);
  });

  test('an unknown value reads Unknown, never 0', () {
    final m = MealEntry(
      id: 'u', foodId: 'f', nameEn: 'x', nameAr: '', eatenAt: DateTime(2026, 11, 3, 13), mealType: 'Lunch', weightG: 100, confidence: 1,
      nutrients: const NutritionValues(calories: 300, protein: 0, carbohydrates: 0, fat: 0, sugar: 0, fiber: 0, sodium: 0, potassium: 0,
          missingKeys: {'sugar_g'}),
    );
    final html = doctorReportHtml(build(list: [m]), const S(false));
    expect(html, contains('Unknown'));
    expect(build(list: [m]).goalDays.firstWhere((g) => g.goal == ReportGoal.sugar).within, 0);
  });

  test('a period with no meals is empty', () {
    expect(build(list: []).isEmpty, isTrue);
  });

  test('weight trend uses the first and last entries in the period', () {
    final r = build(weights: [
      BodyWeightEntry(id: 'a', measuredOn: DateTime(2026, 10, 1), weightKg: 90),
      BodyWeightEntry(id: 'b', measuredOn: DateTime(2026, 11, 2), weightKg: 82),
      BodyWeightEntry(id: 'c', measuredOn: DateTime(2026, 11, 12), weightKg: 81.2),
    ]);
    expect(r.weightStart!.weightKg, 82);
    expect(r.weightEnd!.weightKg, 81.2);
  });

  test('leftovers are already taken off', () {
    final m = _meal('Lunch', DateTime(2026, 11, 3, 13), kcal: 400)
        .copyWith(leftover: MealLeftover(grams: 100, weighedAt: DateTime(2026, 11, 3, 14)));
    final r = build(list: [m]);
    expect(r.dailyAverage.calories, 200);
    expect(r.leftoverMeals, 1);
  });

  group('the page', () {
    test('has every section, with carbs after the overview normally', () {
      final html = doctorReportHtml(build(), const S(false));
      for (final heading in ['Overview', 'Carbs by meal', 'Days within goals', 'Patterns', 'Daily totals']) {
        expect(html, contains(heading));
      }
      expect(html.indexOf('Overview'), lessThan(html.indexOf('Carbs by meal')));
      expect(html, contains('Not logged'));
      expect(html, contains('Abdullah'));
      expect(html, contains('Dinner was the highest-carb meal on 10 of 10 days'));
      expect(html, contains('estimates'));
      expect(html, isNot(contains('verified')));
    });

    test('puts carbs first in diabetes mode', () {
      final html = doctorReportHtml(build(carbsFirst: true), const S(false));
      expect(html.indexOf('Carbs by meal'), lessThan(html.indexOf('Overview')));
    });

    test('is right to left in Arabic', () {
      final html = doctorReportHtml(build(), const S(true));
      expect(html, contains('dir="rtl"'));
      expect(html, contains('تقرير الطعام والتغذية'));
      expect(html, contains('غير مسجل'));
    });

    test('escapes the name', () {
      final r = buildDoctorReport(
          meals: meals, goals: goals, weights: const [], today: today, periodDays: 14, dayOf: _day, name: '<b>x</b>');
      final html = doctorReportHtml(r, const S(false));
      expect(html, contains('&lt;b&gt;x'));
      expect(html, isNot(contains('<b>x')));
    });
  });
}
