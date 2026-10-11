import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/nutrition.dart';

class ApiService {
  ApiService({
    this.baseUrl = const String.fromEnvironment(
      'MIQDAR_API_URL',
      defaultValue: 'http://10.0.2.2:8080',
    ),
    this.apiToken = const String.fromEnvironment('MIQDAR_API_TOKEN'),
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String apiToken;
  final http.Client _client;
  static const requestTimeout = Duration(seconds: 25);

  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        if (apiToken.isNotEmpty) 'Authorization': 'Bearer $apiToken',
      };

  Future<RecognitionResult> recognize({
    required XFile? image,
    required double weightG,
    required String hint,
  }) async {
    try {
      final imageBytes = image == null ? <int>[] : await File(image.path).readAsBytes();
      final response = await _client
          .post(
            Uri.parse('$baseUrl/recognize'),
            headers: _jsonHeaders,
            body: jsonEncode({
              'user_id': 'demo-user',
              'image_base64': base64Encode(imageBytes),
              'weight_g': weightG,
              'hint': hint,
            }),
          )
          .timeout(requestTimeout);
      if (response.statusCode != 200) {
        throw HttpException('Recognition failed: ${response.body}');
      }
      return RecognitionResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      return _offlineResult(hint, weightG);
    }
  }

  Future<Map<String, dynamic>> health() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/health'), headers: _jsonHeaders)
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      throw HttpException('Server health check failed: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> saveHealthProfile(HealthProfile profile) async {
    final response = await _client
        .put(
          Uri.parse('$baseUrl/health-profile'),
          headers: _jsonHeaders,
          body: jsonEncode({'user_id': 'demo-user', ...profile.toJson()}),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw HttpException('Health profile could not be saved: ${response.body}');
    }
  }

  Future<RecommendationResponse> recommendMeals({
    required HealthProfile profile,
    required List<MealEntry> recentMeals,
    int limit = 5,
    bool offlineOnly = false,
  }) async {
    if (offlineOnly) return _offlineRecommendations(profile, recentMeals, limit);
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/recommendations'),
            headers: _jsonHeaders,
            body: jsonEncode({
              'user_id': 'demo-user',
              'profile': profile.toJson(),
              'limit': limit,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw HttpException('Recommendations failed: ${response.body}');
      }
      return RecommendationResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      return _offlineRecommendations(profile, recentMeals, limit);
    }
  }

  RecognitionResult _offlineResult(String hint, double weightG) {
    const profiles = <String, (String, String, String, List<double>)>{
      'medjool dates': ('food_dates_medjool', 'Medjool dates', 'تمر مجدول', [277, 1.81, 74.97, .15, 66.47, 6.7, 1, 696]),
      'white rice': ('food_rice_white_cooked', 'White rice', 'أرز أبيض', [130, 2.69, 28.17, .28, .05, .4, 1, 35]),
      'chicken breast': ('food_chicken_breast_roasted', 'Chicken breast', 'صدر دجاج', [165, 31.02, 0, 3.57, 0, 0, 74, 256]),
      'hummus': ('food_hummus_prepared', 'Hummus', 'حمص', [166, 7.9, 14.3, 9.6, .3, 6, 379, 228]),
      'banana': ('food_banana_raw', 'Banana', 'موز', [89, 1.09, 22.84, .33, 12.23, 2.6, 1, 358]),
    };
    final profile = profiles[hint] ?? profiles['medjool dates']!;
    final n = profile.$4;
    final factor = weightG / 100;
    double scaled(int index) => n[index] * factor;
    return RecognitionResult(
      eventId: 'offline-${DateTime.now().microsecondsSinceEpoch}',
      foodId: profile.$1,
      nameEn: profile.$2,
      nameAr: profile.$3,
      weightG: weightG,
      confidence: .92,
      verificationStatus: hint == 'medjool dates' ? 'verified_official_record' : 'reference_seed',
      nutrients: NutritionValues(
        calories: scaled(0), protein: scaled(1), carbohydrates: scaled(2),
        fat: scaled(3), sugar: scaled(4), fiber: scaled(5),
        sodium: scaled(6), potassium: scaled(7),
      ),
      alertEvaluationMs: 0,
      alertSloMet: true,
      isMock: true,
      provider: 'mock-offline',
    );
  }

  RecommendationResponse _offlineRecommendations(
    HealthProfile profile,
    List<MealEntry> recentMeals,
    int limit,
  ) {
    const raw = <(String, String, String, double, List<double>)>[
      ('food_chicken_breast_roasted', 'Chicken breast', 'صدر دجاج', 140, [165, 31.02, 0, 3.57, 0, 0, 74, 256]),
      ('food_hummus_prepared', 'Hummus', 'حمص', 150, [166, 7.9, 14.3, 9.6, .3, 6, 379, 228]),
      ('food_cucumber_raw', 'Cucumber', 'خيار', 150, [15, .65, 3.63, .11, 1.67, .5, 2, 147]),
      ('food_tomato_raw', 'Tomato', 'طماطم', 150, [18, .88, 3.89, .2, 2.63, 1.2, 5, 237]),
      ('food_egg_boiled', 'Boiled egg', 'بيض مسلوق', 100, [155, 12.58, 1.12, 10.61, 1.12, 0, 124, 126]),
      ('food_salmon_cooked', 'Cooked salmon', 'سلمون مطبوخ', 140, [206, 22.1, 0, 12.35, 0, 0, 59, 384]),
      ('food_apple_raw', 'Apple', 'تفاح', 120, [52, .26, 13.81, .17, 10.39, 2.4, 1, 107]),
    ];
    final recentCounts = <String, int>{};
    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    for (final meal in recentMeals.where((meal) => meal.eatenAt.isAfter(cutoff))) {
      recentCounts[meal.foodId] = (recentCounts[meal.foodId] ?? 0) + 1;
    }
    final exclusions = {
      ...profile.allergens.map((item) => item.toLowerCase()),
      ...profile.dislikedFoods.map((item) => item.toLowerCase()),
    };
    final conditions = profile.conditions.toSet();
    final preferences = profile.dietaryPreferences.toSet();
    final suggestions = <MealSuggestion>[];
    for (final item in raw) {
      final name = item.$2.toLowerCase();
      if (exclusions.any((value) => name.contains(value))) continue;
      if (exclusions.contains('nuts') && name.contains('almond')) continue;
      if (preferences.contains('vegetarian') && (name.contains('chicken') || name.contains('salmon'))) continue;
      if (preferences.contains('vegan') && (name.contains('chicken') || name.contains('salmon') || name.contains('egg'))) continue;
      final factor = item.$4 / 100;
      final values = item.$5;
      final nutrients = NutritionValues(
        calories: values[0] * factor,
        protein: values[1] * factor,
        carbohydrates: values[2] * factor,
        fat: values[3] * factor,
        sugar: values[4] * factor,
        fiber: values[5] * factor,
        sodium: values[6] * factor,
        potassium: values[7] * factor,
      );
      var score = 70.0 - (recentCounts[item.$1] ?? 0) * 5;
      final why = <String>[];
      if ((recentCounts[item.$1] ?? 0) == 0) why.add('Adds variety compared with the last 14 days');
      if (conditions.contains('diabetes')) {
        score += nutrients.sugar <= 8 ? 10 : -nutrients.sugar;
        if (nutrients.sugar <= 8) why.add('Lower-sugar option in the local food set');
      }
      if (conditions.contains('hypertension')) {
        score += nutrients.sodium <= 200 ? 10 : -nutrients.sodium / 30;
        if (nutrients.sodium <= 200) why.add('Lower sodium for the suggested portion');
      }
      if (conditions.contains('weight_management') && values[0] <= 170) {
        score += 8;
        why.add('Lower energy density among available foods');
      }
      if (conditions.contains('kidney_disease')) {
        score -= nutrients.potassium > 250 ? 12 : 0;
        why.add('Use only with clinician-approved sodium and potassium targets');
      }
      if (why.isEmpty) why.add('Balances variety with the configured nutrition profile');
      suggestions.add(MealSuggestion(
        foodId: item.$1,
        nameEn: item.$2,
        nameAr: item.$3,
        portionG: item.$4,
        score: score.clamp(0, 100).toDouble(),
        nutrients: nutrients,
        why: why.take(3).toList(),
        recentOccurrences: recentCounts[item.$1] ?? 0,
        verificationStatus: 'offline_reference',
      ));
    }
    suggestions.sort((a, b) => b.score.compareTo(a.score));
    return RecommendationResponse(
      suggestions: suggestions.take(limit).toList(),
      disclaimer: 'Offline suggestions use local reference data and general configured preferences. They are not medical advice.',
      method: 'offline_transparent_scoring_v1',
      offline: true,
    );
  }
}
