class NutritionValues {
  const NutritionValues({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.sugar,
    required this.fiber,
    required this.sodium,
    required this.potassium,
  });

  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double sugar;
  final double fiber;
  final double sodium;
  final double potassium;

  factory NutritionValues.zero() => const NutritionValues(
        calories: 0,
        protein: 0,
        carbohydrates: 0,
        fat: 0,
        sugar: 0,
        fiber: 0,
        sodium: 0,
        potassium: 0,
      );

  factory NutritionValues.fromJson(Map<String, dynamic> json) => NutritionValues(
        calories: (json['calories_kcal'] as num?)?.toDouble() ?? 0,
        protein: (json['protein_g'] as num?)?.toDouble() ?? 0,
        carbohydrates: (json['carbohydrate_g'] as num?)?.toDouble() ?? 0,
        fat: (json['fat_g'] as num?)?.toDouble() ?? 0,
        sugar: (json['sugar_g'] as num?)?.toDouble() ?? 0,
        fiber: (json['fiber_g'] as num?)?.toDouble() ?? 0,
        sodium: (json['sodium_mg'] as num?)?.toDouble() ?? 0,
        potassium: (json['potassium_mg'] as num?)?.toDouble() ?? 0,
      );

  Map<String, double> toDatabase() => {
        'calories_kcal': calories,
        'protein_g': protein,
        'carbohydrate_g': carbohydrates,
        'fat_g': fat,
        'sugar_g': sugar,
        'fiber_g': fiber,
        'sodium_mg': sodium,
        'potassium_mg': potassium,
      };

  NutritionValues operator +(NutritionValues other) => NutritionValues(
        calories: calories + other.calories,
        protein: protein + other.protein,
        carbohydrates: carbohydrates + other.carbohydrates,
        fat: fat + other.fat,
        sugar: sugar + other.sugar,
        fiber: fiber + other.fiber,
        sodium: sodium + other.sodium,
        potassium: potassium + other.potassium,
      );

  NutritionValues scaledBy(double factor) => NutritionValues(
        calories: calories * factor,
        protein: protein * factor,
        carbohydrates: carbohydrates * factor,
        fat: fat * factor,
        sugar: sugar * factor,
        fiber: fiber * factor,
        sodium: sodium * factor,
        potassium: potassium * factor,
      );
}

class RecognitionCandidate {
  const RecognitionCandidate({
    required this.rank,
    required this.label,
    required this.confidence,
    required this.selected,
    this.foodId,
    this.nameEn,
    this.nameAr,
    this.verificationStatus,
    this.nutrients,
  });

  final int rank;
  final String label;
  final double confidence;
  final bool selected;
  final String? foodId;
  final String? nameEn;
  final String? nameAr;
  final String? verificationStatus;
  final NutritionValues? nutrients;

  /// True when this AI label resolved to a record in the nutrition database.
  bool get inDatabase => foodId != null && nutrients != null;

  factory RecognitionCandidate.fromJson(Map<String, dynamic> json, int fallbackRank) {
    final food = json['food'] as Map<String, dynamic>?;
    final nutrients = json['nutrients'] as Map<String, dynamic>?;
    return RecognitionCandidate(
      rank: (json['rank'] as num?)?.toInt() ?? fallbackRank,
      label: json['label'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      selected: json['selected'] as bool? ?? false,
      foodId: food?['food_id'] as String?,
      nameEn: food?['name_en'] as String?,
      nameAr: food?['name_ar'] as String?,
      verificationStatus: food?['verification_status'] as String?,
      nutrients: nutrients == null ? null : NutritionValues.fromJson(nutrients),
    );
  }
}

class RecognitionResult {
  const RecognitionResult({
    required this.eventId,
    required this.foodId,
    required this.nameEn,
    required this.nameAr,
    required this.weightG,
    required this.confidence,
    required this.verificationStatus,
    required this.nutrients,
    required this.alertEvaluationMs,
    required this.alertSloMet,
    required this.isMock,
    required this.provider,
    this.model,
    this.candidates = const [],
    this.cached = false,
    this.recognitionMs = 0,
    this.hintUsed,
    this.userCorrected = false,
  });

  final String eventId;
  final String foodId;
  final String nameEn;
  final String nameAr;
  final double weightG;
  final double confidence;
  final String verificationStatus;
  final NutritionValues nutrients;
  final int alertEvaluationMs;
  final bool alertSloMet;
  final bool isMock;
  final String provider;
  final String? model;
  final List<RecognitionCandidate> candidates;
  final bool cached;
  final int recognitionMs;
  final String? hintUsed;
  final bool userCorrected;

  /// Returns a copy that uses [candidate] instead of the AI's first choice.
  RecognitionResult withCandidate(RecognitionCandidate candidate) {
    if (!candidate.inDatabase) return this;
    return RecognitionResult(
      eventId: eventId,
      foodId: candidate.foodId!,
      nameEn: candidate.nameEn ?? candidate.label,
      nameAr: candidate.nameAr ?? '',
      weightG: weightG,
      confidence: candidate.confidence,
      verificationStatus: candidate.verificationStatus ?? verificationStatus,
      nutrients: candidate.nutrients!,
      alertEvaluationMs: alertEvaluationMs,
      alertSloMet: alertSloMet,
      isMock: isMock,
      provider: provider,
      model: model,
      candidates: candidates,
      cached: cached,
      recognitionMs: recognitionMs,
      hintUsed: hintUsed,
      userCorrected: candidate.foodId != candidates.where((c) => c.selected).map((c) => c.foodId).firstOrNull,
    );
  }

  factory RecognitionResult.fromJson(Map<String, dynamic> json) {
    final food = json['food'] as Map<String, dynamic>? ?? {};
    final timing = json['timing'] as Map<String, dynamic>? ?? {};
    final rawCandidates = json['candidates'] as List<dynamic>? ?? const [];
    return RecognitionResult(
      eventId: json['event_id'] as String? ?? 'local-event',
      foodId: food['food_id'] as String? ?? 'unknown',
      nameEn: food['name_en'] as String? ?? 'Unknown food',
      nameAr: food['name_ar'] as String? ?? '',
      weightG: (json['weight_g'] as num?)?.toDouble() ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      verificationStatus: food['verification_status'] as String? ?? 'unknown',
      nutrients: NutritionValues.fromJson(
        json['nutrients'] as Map<String, dynamic>? ?? {},
      ),
      alertEvaluationMs: (timing['alert_evaluation_ms'] as num?)?.toInt() ?? 0,
      alertSloMet: timing['alert_slo_met'] as bool? ?? false,
      isMock: false,
      provider: json['recognition_provider'] as String? ?? 'api',
      model: json['recognition_model'] as String?,
      candidates: [
        for (var i = 0; i < rawCandidates.length; i++)
          if (rawCandidates[i] is Map<String, dynamic>)
            RecognitionCandidate.fromJson(rawCandidates[i] as Map<String, dynamic>, i + 1),
      ],
      cached: json['recognition_cached'] as bool? ?? false,
      recognitionMs: (timing['recognition_ms'] as num?)?.toInt() ?? 0,
      hintUsed: json['hint_used'] as String?,
    );
  }
}

class MealEntry {
  const MealEntry({
    required this.id,
    required this.foodId,
    required this.nameEn,
    required this.nameAr,
    required this.eatenAt,
    required this.mealType,
    required this.weightG,
    required this.confidence,
    required this.nutrients,
  });

  final String id;
  final String foodId;
  final String nameEn;
  final String nameAr;
  final DateTime eatenAt;
  final String mealType;
  final double weightG;
  final double confidence;
  final NutritionValues nutrients;

  MealEntry copyWith({
    String? mealType,
    DateTime? eatenAt,
    double? weightG,
    NutritionValues? nutrients,
  }) =>
      MealEntry(
        id: id,
        foodId: foodId,
        nameEn: nameEn,
        nameAr: nameAr,
        eatenAt: eatenAt ?? this.eatenAt,
        mealType: mealType ?? this.mealType,
        weightG: weightG ?? this.weightG,
        confidence: confidence,
        nutrients: nutrients ?? this.nutrients,
      );
}

class NutritionGoals {
  const NutritionGoals({
    required this.calories,
    required this.sugar,
    required this.sodium,
    required this.potassium,
    required this.carbohydrates,
    required this.protein,
  });

  final double calories;
  final double sugar;
  final double sodium;
  final double potassium;
  final double carbohydrates;
  final double protein;

  NutritionGoals copyWith({
    double? calories,
    double? sugar,
    double? sodium,
    double? potassium,
    double? carbohydrates,
    double? protein,
  }) =>
      NutritionGoals(
        calories: calories ?? this.calories,
        sugar: sugar ?? this.sugar,
        sodium: sodium ?? this.sodium,
        potassium: potassium ?? this.potassium,
        carbohydrates: carbohydrates ?? this.carbohydrates,
        protein: protein ?? this.protein,
      );
}

class HealthAlert {
  const HealthAlert({
    required this.id,
    required this.nutrientKey,
    required this.severity,
    required this.currentValue,
    required this.thresholdValue,
    required this.message,
    required this.createdAt,
    required this.evaluationMs,
  });

  final String id;
  final String nutrientKey;
  final String severity;
  final double currentValue;
  final double thresholdValue;
  final String message;
  final DateTime createdAt;
  final int evaluationMs;
}

class HealthProfile {
  const HealthProfile({
    this.conditions = const [],
    this.dietaryPreferences = const [],
    this.allergens = const [],
    this.dislikedFoods = const [],
  });

  final List<String> conditions;
  final List<String> dietaryPreferences;
  final List<String> allergens;
  final List<String> dislikedFoods;

  factory HealthProfile.fromJson(Map<String, dynamic> json) => HealthProfile(
        conditions: _stringList(json['conditions']),
        dietaryPreferences: _stringList(json['dietary_preferences']),
        allergens: _stringList(json['allergens']),
        dislikedFoods: _stringList(json['disliked_foods']),
      );

  Map<String, dynamic> toJson() => {
        'conditions': conditions,
        'dietary_preferences': dietaryPreferences,
        'allergens': allergens,
        'disliked_foods': dislikedFoods,
      };

  HealthProfile copyWith({
    List<String>? conditions,
    List<String>? dietaryPreferences,
    List<String>? allergens,
    List<String>? dislikedFoods,
  }) =>
      HealthProfile(
        conditions: conditions ?? this.conditions,
        dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
        allergens: allergens ?? this.allergens,
        dislikedFoods: dislikedFoods ?? this.dislikedFoods,
      );

  static List<String> _stringList(dynamic value) => value is List
      ? value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList()
      : <String>[];
}

class MealSuggestion {
  const MealSuggestion({
    required this.foodId,
    required this.nameEn,
    required this.nameAr,
    required this.portionG,
    required this.score,
    required this.nutrients,
    required this.why,
    required this.recentOccurrences,
    required this.verificationStatus,
  });

  final String foodId;
  final String nameEn;
  final String nameAr;
  final double portionG;
  final double score;
  final NutritionValues nutrients;
  final List<String> why;
  final int recentOccurrences;
  final String verificationStatus;

  factory MealSuggestion.fromJson(Map<String, dynamic> json) => MealSuggestion(
        foodId: json['food_id'] as String? ?? 'unknown',
        nameEn: json['name_en'] as String? ?? 'Meal suggestion',
        nameAr: json['name_ar'] as String? ?? '',
        portionG: (json['portion_g'] as num?)?.toDouble() ?? 0,
        score: (json['score'] as num?)?.toDouble() ?? 0,
        nutrients: NutritionValues.fromJson(
          json['nutrients'] as Map<String, dynamic>? ?? {},
        ),
        why: HealthProfile._stringList(json['why']),
        recentOccurrences: (json['recent_occurrences_14d'] as num?)?.toInt() ?? 0,
        verificationStatus: json['verification_status'] as String? ?? 'unknown',
      );
}

class RecommendationResponse {
  const RecommendationResponse({
    required this.suggestions,
    required this.disclaimer,
    required this.method,
    required this.offline,
  });

  final List<MealSuggestion> suggestions;
  final String disclaimer;
  final String method;
  final bool offline;

  factory RecommendationResponse.fromJson(Map<String, dynamic> json) =>
      RecommendationResponse(
        suggestions: (json['suggestions'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(MealSuggestion.fromJson)
            .toList(),
        disclaimer: json['disclaimer'] as String? ?? '',
        method: json['method'] as String? ?? 'unknown',
        offline: false,
      );
}
