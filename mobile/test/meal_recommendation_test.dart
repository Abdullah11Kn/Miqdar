import 'package:flutter_test/flutter_test.dart';
import 'package:miqdar_mobile/models/nutrition.dart';

void main() {
  test('health profile round-trips through API JSON', () {
    const profile = HealthProfile(
      conditions: ['diabetes', 'hypertension'],
      dietaryPreferences: ['vegetarian'],
      allergens: ['nuts'],
      dislikedFoods: ['tomato'],
    );
    final decoded = HealthProfile.fromJson(profile.toJson());
    expect(decoded.conditions, profile.conditions);
    expect(decoded.dietaryPreferences, profile.dietaryPreferences);
    expect(decoded.allergens, profile.allergens);
    expect(decoded.dislikedFoods, profile.dislikedFoods);
  });

  test('recommendation response parses nutrition and explanation', () {
    final response = RecommendationResponse.fromJson({
      'method': 'transparent_database_scoring_v1',
      'disclaimer': 'General guidance only.',
      'suggestions': [
        {
          'food_id': 'food_cucumber_raw',
          'name_en': 'Cucumber',
          'name_ar': 'خيار',
          'portion_g': 150,
          'score': 91.5,
          'recent_occurrences_14d': 0,
          'verification_status': 'reference_seed',
          'why': ['Lower sodium', 'Adds variety'],
          'nutrients': {
            'calories_kcal': 22.5,
            'protein_g': .98,
            'carbohydrate_g': 5.45,
            'fat_g': .17,
            'sugar_g': 2.5,
            'fiber_g': .75,
            'sodium_mg': 3,
            'potassium_mg': 220.5,
          },
        },
      ],
    });
    expect(response.suggestions, hasLength(1));
    expect(response.suggestions.first.nameEn, 'Cucumber');
    expect(response.suggestions.first.why, contains('Adds variety'));
    expect(response.suggestions.first.nutrients.sodium, 3);
    expect(response.offline, isFalse);
  });
}
