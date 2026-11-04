import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miqdar_mobile/app_controller.dart';
import 'package:miqdar_mobile/data/local_database.dart';
import 'package:miqdar_mobile/models/body_profile.dart';
import 'package:miqdar_mobile/models/nutrition.dart';
import 'package:miqdar_mobile/services/alert_service.dart';
import 'package:miqdar_mobile/services/api_service.dart';
import 'package:miqdar_mobile/services/gemini_service.dart';

final _now = DateTime(2026, 11, 4);

BodyProfile _profile({
  BodySex sex = BodySex.male,
  int age = 30,
  double height = 180,
  double weight = 80,
  ActivityLevel activity = ActivityLevel.moderate,
  WeightGoal goal = WeightGoal.maintain,
  double? target,
  double? pace,
  bool pregnant = false,
}) =>
    BodyProfile(
      sex: sex,
      birthYear: _now.year - age,
      heightCm: height,
      weightKg: weight,
      activity: activity,
      goal: goal,
      targetWeightKg: target,
      weeklyPaceKg: pace,
      pregnantOrBreastfeeding: pregnant,
    );

GoalSuggestion _suggest(BodyProfile profile) => suggestGoals(profile, LocalDatabase.defaultGoals, _now);

MiqdarController _controller(http.Client client) => MiqdarController(
      localDatabase: LocalDatabase(),
      apiService: ApiService(
        baseUrl: 'http://scale.test',
        client: client,
        gemini: GeminiNutritionService(apiKey: 'test-key', models: const ['m'], client: client),
      ),
      alertService: AlertService(),
    );

void main() {
  group('calculated goal', () {
    test('follows Mifflin-St Jeor with the activity multiplier', () {
      // 10*80 + 6.25*180 - 5*30 + 5 = 1780, and 1780 * 1.55 = 2759
      expect(_suggest(_profile()).goals!.calories, 2750);
      // 10*60 + 6.25*165 - 5*30 - 161 = 1320.25, and * 1.2 = 1584.3
      final woman = _profile(sex: BodySex.female, height: 165, weight: 60, activity: ActivityLevel.sedentary);
      expect(_suggest(woman).goals!.calories, 1600);
    });

    test('losing or gaining changes the calories by the weekly pace', () {
      final lose = _profile(goal: WeightGoal.lose, target: 70, pace: 0.5);
      final gain = _profile(goal: WeightGoal.gain, target: 90, pace: 0.25);
      expect(_suggest(lose).goals!.calories, 2200); // 2759 - 550
      expect(_suggest(gain).goals!.calories, 3050); // 2759 + 275
    });

    test('macros add up close to the calories and other nutrients keep their values', () {
      final goals = _suggest(_profile()).goals!;
      expect(goals.protein, 130); // 1.6 g per kg, to the nearest 5
      expect(goals.fat, 90); // 30% of calories
      final macroKcal = goals.protein * 4 + goals.carbohydrates * 4 + goals.fat * 9;
      expect((macroKcal - goals.calories).abs(), lessThan(50));
      expect(goals.sodium, LocalDatabase.defaultGoals.sodium);
      expect(goals.trackingOnly, isFalse);
    });

    test('never falls below the safe minimum, and says so', () {
      final woman = _suggest(_profile(
        sex: BodySex.female,
        height: 150,
        weight: 50,
        activity: ActivityLevel.sedentary,
        goal: WeightGoal.lose,
        target: 45,
        pace: 0.5,
      ));
      expect(woman.goals!.calories, 1200);
      expect(woman.limitedToMinimum, isTrue);

      final man = _suggest(_profile(
        height: 160,
        weight: 55,
        age: 60,
        activity: ActivityLevel.sedentary,
        goal: WeightGoal.lose,
        target: 50,
        pace: 0.5,
      ));
      expect(man.goals!.calories, 1500);
      expect(man.limitedToMinimum, isTrue);
      expect(_suggest(_profile()).limitedToMinimum, isFalse);
    });

    test('is withheld under 18 and during pregnancy or breastfeeding', () {
      final teen = _suggest(_profile(age: 17));
      expect(teen.goals, isNull);
      expect(teen.block, GoalBlock.underAge);
      expect(_suggest(_profile(age: 18)).goals, isNotNull);

      final pregnant = _suggest(_profile(sex: BodySex.female, pregnant: true));
      expect(pregnant.goals, isNull);
      expect(pregnant.block, GoalBlock.pregnancy);
    });
  });

  group('impossible answers', () {
    test('age, height and weight outside their ranges are refused', () {
      expect(_profile(age: 4).problems(_now), contains(BodyProfileProblem.age));
      expect(_profile(height: 40).problems(_now), contains(BodyProfileProblem.height));
      expect(_profile(weight: 500).problems(_now), contains(BodyProfileProblem.weight));
      expect(_profile().problems(_now), isEmpty);
    });

    test('a target must match the goal', () {
      final wrongWay = _profile(goal: WeightGoal.lose, target: 90, pace: 0.5);
      expect(wrongWay.problems(_now), contains(BodyProfileProblem.target));
      final gainDown = _profile(goal: WeightGoal.gain, target: 70, pace: 0.5);
      expect(gainDown.problems(_now), contains(BodyProfileProblem.target));
      final missing = _profile(goal: WeightGoal.lose, pace: 0.5);
      expect(missing.problems(_now), contains(BodyProfileProblem.target));
    });

    test('weight loss is not offered to an underweight target', () {
      final thin = _profile(goal: WeightGoal.lose, height: 180, weight: 58, target: 55, pace: 0.25);
      expect(thin.problems(_now), contains(BodyProfileProblem.targetUnderweight));
    });

    test('the pace is limited to 0.5 kg a week', () {
      final fast = _profile(goal: WeightGoal.lose, target: 70, pace: 1);
      expect(fast.problems(_now), contains(BodyProfileProblem.pace));
      final none = _profile(goal: WeightGoal.lose, target: 70);
      expect(none.problems(_now), contains(BodyProfileProblem.pace));
    });
  });

  test('a profile survives being written to a row and read back', () {
    final saved = _profile(goal: WeightGoal.lose, target: 70, pace: 0.25, sex: BodySex.female);
    final read = BodyProfile.fromRow(saved.toRow());
    expect(read.sex, BodySex.female);
    expect(read.ageOn(_now), 30);
    expect(read.goal, WeightGoal.lose);
    expect(read.targetWeightKg, 70);
    expect(read.weeklyPaceKg, 0.25);
  });

  group('the required gate', () {
    MiqdarController controller() => _controller(MockClient((_) async => http.Response('{}', 200)));

    test('asks every real user until they answer', () async {
      final c = controller();
      c.signIn(email: '');
      expect(c.needsBodyProfile, isTrue);
      await c.saveBodyProfile(_profile());
      expect(c.needsBodyProfile, isFalse);
    });

    test('is not shown in the demo, which saves nothing', () async {
      final c = controller();
      c.signIn(email: '', displayName: 'Demo', isDemo: true);
      expect(c.needsBodyProfile, isFalse);
      await c.saveBodyProfile(_profile());
      expect(await c.localDatabase.loadBodyProfile(), isNull);
    });

    test('saving a profile leaves the current goals alone until new ones are accepted', () async {
      final c = controller();
      c.signIn(email: '');
      c.goals = c.goals.copyWith(calories: 1900);
      await c.saveBodyProfile(_profile());
      expect(c.goals.calories, 1900);
    });

    test('a test build can skip it', () {
      final c = controller();
      c.signIn(email: '');
      c.skipBodyProfile();
      expect(c.needsBodyProfile, isFalse);
    });
  });

  test('the body profile never reaches Gemini', () async {
    final bodies = <String>[];
    final client = MockClient((request) async {
      bodies.add(request.body);
      return http.Response.bytes(
        utf8.encode(jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({
                      'foods': [
                        {
                          'name_en': 'Jareesh',
                          'name_ar': 'جريش',
                          'confidence': 0.9,
                          'edible_fraction': 1,
                          'per_100g_edible': {
                            'calories_kcal': 140.0, 'protein_g': 4.0, 'carbohydrate_g': 25.0, 'fat_g': 3.0,
                            'sugar_g': 1.0, 'fiber_g': 2.0, 'sodium_mg': 300.0, 'potassium_mg': 100.0,
                          },
                        },
                      ],
                    }),
                  },
                ],
              },
            },
          ],
        })),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final c = _controller(client);
    c.signIn(email: '');
    await c.saveBodyProfile(_profile(height: 173.5, weight: 81.5, goal: WeightGoal.lose, target: 72.5, pace: 0.25));
    try {
      await c.apiService.gemini.analyze(imageBytes: Uint8List.fromList([1, 2, 3]), weightG: 240);
    } on Object {
      // The answer's shape does not matter here, only what was sent.
    }
    expect(bodies, isNotEmpty);
    for (final body in bodies) {
      expect(body, isNot(contains('173.5')));
      expect(body, isNot(contains('81.5')));
      expect(body, isNot(contains('72.5')));
      expect(body.toLowerCase(), isNot(contains('height')));
    }
  });

  test('goal types still treat an accepted goal as a real target', () {
    final NutritionGoals goals = _suggest(_profile()).goals!;
    expect(goals.typeFor('calories_kcal'), GoalType.target);
  });
}
