import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';

enum PortionSource {
  scale,
  manual,
  serving,
  estimated;

  String label(bool isAr) => switch (this) {
        PortionSource.scale => isAr ? 'موزون بالميزان' : 'Weighed on scale',
        PortionSource.manual => isAr ? 'وزن مدخل يدوياً' : 'Entered by hand',
        PortionSource.serving => isAr ? 'حصة معيارية' : 'Standard serving',
        PortionSource.estimated => isAr ? 'وزن تقديري' : 'Estimated weight',
      };
}

enum GoalType {
  target,
  maximum,
  minimum,
  range,
  trackOnly;

  String label(bool isAr) => switch (this) {
        GoalType.target => isAr ? 'هدف يومي' : 'Daily Target',
        GoalType.maximum => isAr ? 'حد أقصى' : 'Maximum Limit',
        GoalType.minimum => isAr ? 'حد أدنى' : 'Minimum Target',
        GoalType.range => isAr ? 'نطاق متوازن' : 'Target Range',
        GoalType.trackOnly => isAr ? 'تتبّع فقط بدون حد' : 'Track Only',
      };
}

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
    this.missingKeys = const {},
  });

  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double sugar;
  final double fiber;
  final double sodium;
  final double potassium;

  /// Keys of nutrients that were null/unreported in a custom or partial record
  /// (NUT-01: missing values are distinct from known zero).
  final Set<String> missingKeys;

  bool isMissing(String key) => missingKeys.contains(key);

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

  factory NutritionValues.fromJson(Map<String, dynamic> json) {
    final missing = <String>{};
    double readField(String key) {
      final raw = json[key];
      if (raw == null) {
        missing.add(key);
        return 0;
      }
      return (raw as num).toDouble();
    }

    return NutritionValues(
      calories: readField('calories_kcal'),
      protein: readField('protein_g'),
      carbohydrates: readField('carbohydrate_g'),
      fat: readField('fat_g'),
      sugar: readField('sugar_g'),
      fiber: readField('fiber_g'),
      sodium: readField('sodium_mg'),
      potassium: readField('potassium_mg'),
      missingKeys: missing,
    );
  }

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
        missingKeys: {...missingKeys, ...other.missingKeys},
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
        missingKeys: missingKeys,
      );

  /// Deterministic per-100g scaling (CALC-01, CALC-04).
  NutritionValues forPortionGrams(double grams) => scaledBy(grams / 100.0);
}

class ServingOption {
  const ServingOption({
    required this.id,
    required this.labelEn,
    required this.labelAr,
    required this.grams,
  });

  final String id;
  final String labelEn;
  final String labelAr;
  final double grams;

  String label(bool isAr) => isAr ? '$labelAr (${grams.toStringAsFixed(0)} غ)' : '$labelEn (${grams.toStringAsFixed(0)} g)';
}

class FoodCatalogItem {
  const FoodCatalogItem({
    required this.foodId,
    required this.nameEn,
    required this.nameAr,
    required this.category,
    required this.preparation,
    required this.verificationStatus,
    required this.sourceId,
    required this.per100g,
    this.sourceRecordId = '',
    this.sourceUrl = '',
    this.notes = '',
    this.aliases = const [],
    this.servings = const [],
    this.isCustom = false,
  });

  final String foodId;
  final String nameEn;
  final String nameAr;
  final String category;
  final String preparation;
  final String verificationStatus;
  final String sourceId;
  final String sourceRecordId;
  final String sourceUrl;
  final String notes;
  final NutritionValues per100g;
  final List<String> aliases;
  final List<ServingOption> servings;
  final bool isCustom;

  String displayName(bool isAr) => isAr && nameAr.isNotEmpty ? nameAr : nameEn;
  String secondaryName(bool isAr) => isAr ? nameEn : nameAr;

  String categoryLabel(bool isAr) => switch (category) {
        'Traditional Dish' => isAr ? 'أطباق شعبية وتقليدية' : 'Traditional Dish',
        'Fruit' => isAr ? 'فواكه وتمور' : 'Fruit & Dates',
        'Protein' => isAr ? 'بروتينات ولحوم' : 'Protein & Poultry',
        'Grain' => isAr ? 'حبوب وأرز' : 'Grains & Rice',
        'Legume' => isAr ? 'بقوليات ومقبلات' : 'Legumes & Dips',
        'Vegetable' => isAr ? 'خضروات طازجة' : 'Vegetables',
        'Dairy' => isAr ? 'ألبان وأجبان' : 'Dairy',
        'Sandwich' => isAr ? 'ساندوتشات ولفائف' : 'Sandwiches & Wraps',
        'Fast Food' => isAr ? 'وجبات سريعة' : 'Fast Food',
        'Salad' => isAr ? 'سلطات' : 'Salads',
        'Custom' => isAr ? 'طعام مخصص' : 'Custom Food',
        _ => category,
      };
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
    this.basisPer100g,
    this.edibleFraction = 1,
    this.note = '',
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
  final NutritionValues? basisPer100g;
  final double edibleFraction;
  final String note;

  /// True when this candidate has nutrition values and can be selected.
  bool get inDatabase => foodId != null && nutrients != null;

  factory RecognitionCandidate.fromJson(
    Map<String, dynamic> json,
    int fallbackRank, {
    double weightG = 0,
  }) {
    final food = json['food'] as Map<String, dynamic>?;
    final nutrients = json['nutrients'] as Map<String, dynamic>?;
    final portion = nutrients == null ? null : NutritionValues.fromJson(nutrients);
    return RecognitionCandidate(
      rank: (json['rank'] as num?)?.toInt() ?? fallbackRank,
      label: json['label'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      selected: json['selected'] as bool? ?? false,
      foodId: food?['food_id'] as String?,
      nameEn: food?['name_en'] as String?,
      nameAr: food?['name_ar'] as String?,
      verificationStatus: food?['verification_status'] as String?,
      nutrients: portion,
      basisPer100g: portion != null && weightG > 0 ? portion.scaledBy(100.0 / weightG) : null,
    );
  }
}

/// Marks a food on a mixed plate that still has no name, so its calories are not known yet.
const unidentifiedFoodId = 'unidentified-plate-food';

class MealItemEntry {
  const MealItemEntry({
    required this.id,
    required this.foodId,
    required this.nameEn,
    required this.nameAr,
    required this.weightG,
    required this.nutrients,
    this.basisPer100g,
    this.portionSource = PortionSource.scale,
    this.verificationStatus = 'reference_seed',
    this.preparation = 'prepared',
  });

  final String id;
  final String foodId;
  final String nameEn;
  final String nameAr;
  final double weightG;
  final NutritionValues nutrients;
  final NutritionValues? basisPer100g;
  final PortionSource portionSource;
  final String verificationStatus;
  final String preparation;

  bool get isUnidentified => foodId == unidentifiedFoodId;

  NutritionValues get resolvedBasisPer100g =>
      basisPer100g ?? (weightG > 0 ? nutrients.scaledBy(100.0 / weightG) : nutrients);

  factory MealItemEntry.unidentified({required String id, required double weightG}) => MealItemEntry(
        id: id,
        foodId: unidentifiedFoodId,
        nameEn: 'Unnamed food',
        nameAr: 'طعام بلا اسم',
        weightG: weightG,
        // Nothing is known yet, so totals read Unknown rather than 0.
        nutrients: NutritionValues.fromJson(const {}),
        basisPer100g: NutritionValues.fromJson(const {}),
        verificationStatus: aiEstimateStatus,
      );

  Map<String, Object?> toRow(String mealId, int position) => {
        'id': id,
        'meal_id': mealId,
        'position': position,
        'food_id': foodId,
        'name_en': nameEn,
        'name_ar': nameAr,
        'weight_g': weightG,
        'portion_source': portionSource.name,
        'verification_status': verificationStatus,
        'preparation': preparation,
        'basis_json': jsonEncode(
          Map<String, double>.from(resolvedBasisPer100g.toDatabase())
            ..removeWhere((key, _) => resolvedBasisPer100g.isMissing(key)),
        ),
      };

  factory MealItemEntry.fromRow(Map<String, Object?> row) {
    final basis = NutritionValues.fromJson(jsonDecode(row['basis_json'] as String) as Map<String, dynamic>);
    final weight = (row['weight_g'] as num).toDouble();
    return MealItemEntry(
      id: row['id'] as String,
      foodId: row['food_id'] as String,
      nameEn: row['name_en'] as String,
      nameAr: row['name_ar'] as String,
      weightG: weight,
      nutrients: basis.forPortionGrams(weight),
      basisPer100g: basis,
      portionSource: PortionSource.values.asNameMap()[row['portion_source']] ?? PortionSource.scale,
      verificationStatus: row['verification_status'] as String,
      preparation: row['preparation'] as String,
    );
  }

  MealItemEntry withWeight(double newWeightG, {PortionSource? newSource}) {
    final basis = resolvedBasisPer100g;
    return MealItemEntry(
      id: id,
      foodId: foodId,
      nameEn: nameEn,
      nameAr: nameAr,
      weightG: newWeightG,
      nutrients: basis.forPortionGrams(newWeightG),
      basisPer100g: basis,
      portionSource: newSource ?? portionSource,
      verificationStatus: verificationStatus,
      preparation: preparation,
    );
  }
}

/// Marks nutrition estimated by Gemini rather than read from a reviewed record.
const aiEstimateStatus = 'ai_estimate';

/// Prefix of food ids that exist only as a Gemini estimate, not in any database.
const aiFoodIdPrefix = 'ai-';

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
    this.portionSource = PortionSource.scale,
    this.basisPer100g,
    this.additionalItems = const [],
    this.plateItems = const [],
    this.plateNameEn = '',
    this.plateNameAr = '',
    this.imageBytes,
    this.edibleFraction = 1,
    this.aiNote = '',
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
  final PortionSource portionSource;
  final NutritionValues? basisPer100g;
  final List<MealItemEntry> additionalItems;

  /// Every food on a mixed plate, in the order added. Empty for a one-food meal.
  final List<MealItemEntry> plateItems;
  final String plateNameEn;
  final String plateNameAr;
  final Uint8List? imageBytes;

  bool get isPlate => plateItems.isNotEmpty;

  /// A plate goes by the plate's name, or its first food if it has none yet.
  String displayName(bool isAr) {
    final plateName = isAr ? plateNameAr : plateNameEn;
    if (isPlate && plateName.isNotEmpty) return plateName;
    return isAr && nameAr.isNotEmpty ? nameAr : nameEn;
  }
  bool get plateNeedsNames => plateItems.any((item) => item.isUnidentified);

  /// One meal made of several foods: the first is the main item, the rest count as additional.
  factory RecognitionResult.forPlate({
    required String eventId,
    required List<MealItemEntry> items,
    required String nameEn,
    required String nameAr,
    required double confidence,
    required String provider,
    String? model,
    Uint8List? imageBytes,
    int recognitionMs = 0,
  }) {
    final first = items.first;
    // The meal row says one thing for the whole plate, so it takes the weakest claim on it.
    final anyEstimate = items.any((item) => item.verificationStatus == aiEstimateStatus);
    final portion = const [PortionSource.estimated, PortionSource.manual, PortionSource.serving]
            .where((source) => items.any((item) => item.portionSource == source))
            .firstOrNull ??
        PortionSource.scale;
    return RecognitionResult(
      eventId: eventId,
      foodId: first.foodId,
      nameEn: first.nameEn,
      nameAr: first.nameAr,
      weightG: first.weightG,
      confidence: confidence,
      verificationStatus: anyEstimate ? aiEstimateStatus : first.verificationStatus,
      nutrients: first.nutrients,
      basisPer100g: first.resolvedBasisPer100g,
      alertEvaluationMs: 0,
      alertSloMet: true,
      isMock: false,
      provider: provider,
      model: model,
      recognitionMs: recognitionMs,
      portionSource: portion,
      additionalItems: items.sublist(1),
      plateItems: items,
      plateNameEn: nameEn,
      plateNameAr: nameAr,
      imageBytes: imageBytes,
    );
  }

  /// Share of the weighed grams that is eaten, and what Gemini assumed to get there.
  final double edibleFraction;
  final String aiNote;

  /// Below this, Gemini is telling us to check its answer.
  static const lowConfidence = 0.6;

  bool get isUnsure => verificationStatus == aiEstimateStatus && confidence < lowConfidence;

  NutritionValues get resolvedBasisPer100g =>
      basisPer100g ?? (weightG > 0 ? nutrients.scaledBy(100.0 / weightG) : nutrients);

  NutritionValues get totalNutrients =>
      additionalItems.fold(nutrients, (sum, item) => sum + item.nutrients);

  double get totalWeightG =>
      additionalItems.fold(weightG, (sum, item) => sum + item.weightG);

  /// Returns a copy that uses [candidate] instead of the AI's first choice.
  RecognitionResult withCandidate(RecognitionCandidate candidate) {
    if (!candidate.inDatabase) return this;
    // Candidates were scaled when they arrived; the weight may have been edited since.
    final candidateBasis = candidate.basisPer100g ??
        (weightG > 0 ? candidate.nutrients!.scaledBy(100.0 / weightG) : candidate.nutrients!);
    return RecognitionResult(
      eventId: eventId,
      foodId: candidate.foodId!,
      nameEn: candidate.nameEn ?? candidate.label,
      nameAr: candidate.nameAr ?? '',
      weightG: weightG,
      confidence: candidate.confidence,
      verificationStatus: candidate.verificationStatus ?? verificationStatus,
      nutrients: candidateBasis.forPortionGrams(weightG),
      edibleFraction: candidate.edibleFraction,
      aiNote: candidate.note,
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
      portionSource: portionSource,
      basisPer100g: candidateBasis,
      additionalItems: additionalItems,
      plateItems: plateItems,
      plateNameEn: plateNameEn,
      plateNameAr: plateNameAr,
      imageBytes: imageBytes,
    );
  }

  /// Lossless rescaling from immutable per-100g source basis (CALC-01, CALC-04).
  RecognitionResult withWeight(double newWeightG, {PortionSource? newSource}) {
    final basis = resolvedBasisPer100g;
    return RecognitionResult(
      eventId: eventId,
      foodId: foodId,
      nameEn: nameEn,
      nameAr: nameAr,
      weightG: newWeightG,
      confidence: confidence,
      verificationStatus: verificationStatus,
      nutrients: basis.forPortionGrams(newWeightG),
      alertEvaluationMs: alertEvaluationMs,
      alertSloMet: alertSloMet,
      isMock: isMock,
      provider: provider,
      model: model,
      candidates: candidates,
      cached: cached,
      recognitionMs: recognitionMs,
      hintUsed: hintUsed,
      userCorrected: userCorrected,
      portionSource: newSource ?? portionSource,
      basisPer100g: basis,
      additionalItems: additionalItems,
      plateItems: plateItems,
      plateNameEn: plateNameEn,
      plateNameAr: plateNameAr,
      imageBytes: imageBytes,
      edibleFraction: edibleFraction,
      aiNote: aiNote,
    );
  }

  RecognitionResult withAdditionalItems(List<MealItemEntry> items) => RecognitionResult(
        eventId: eventId,
        foodId: foodId,
        nameEn: nameEn,
        nameAr: nameAr,
        weightG: weightG,
        confidence: confidence,
        verificationStatus: verificationStatus,
        nutrients: nutrients,
        alertEvaluationMs: alertEvaluationMs,
        alertSloMet: alertSloMet,
        isMock: isMock,
        provider: provider,
        model: model,
        candidates: candidates,
        cached: cached,
        recognitionMs: recognitionMs,
        hintUsed: hintUsed,
        userCorrected: userCorrected,
        portionSource: portionSource,
        basisPer100g: basisPer100g,
        additionalItems: items,
        plateItems: plateItems,
        plateNameEn: plateNameEn,
        plateNameAr: plateNameAr,
        edibleFraction: edibleFraction,
        aiNote: aiNote,
        imageBytes: imageBytes,
      );

  factory RecognitionResult.fromJson(Map<String, dynamic> json) {
    final food = json['food'] as Map<String, dynamic>? ?? {};
    final timing = json['timing'] as Map<String, dynamic>? ?? {};
    final rawCandidates = json['candidates'] as List<dynamic>? ?? const [];
    final weightG = (json['weight_g'] as num?)?.toDouble() ?? 0;
    final nutrients = NutritionValues.fromJson(
      json['nutrients'] as Map<String, dynamic>? ?? {},
    );
    return RecognitionResult(
      eventId: json['event_id'] as String? ?? 'local-event',
      foodId: food['food_id'] as String? ?? 'unknown',
      nameEn: food['name_en'] as String? ?? 'Unknown food',
      nameAr: food['name_ar'] as String? ?? '',
      weightG: weightG,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      verificationStatus: food['verification_status'] as String? ?? 'unknown',
      nutrients: nutrients,
      basisPer100g: weightG > 0 ? nutrients.scaledBy(100.0 / weightG) : nutrients,
      alertEvaluationMs: (timing['alert_evaluation_ms'] as num?)?.toInt() ?? 0,
      alertSloMet: timing['alert_slo_met'] as bool? ?? false,
      isMock: json['simulated'] as bool? ?? false,
      provider: json['recognition_provider'] as String? ?? 'api',
      model: json['recognition_model'] as String?,
      candidates: [
        for (var i = 0; i < rawCandidates.length; i++)
          if (rawCandidates[i] is Map<String, dynamic>)
            RecognitionCandidate.fromJson(rawCandidates[i] as Map<String, dynamic>, i + 1, weightG: weightG),
      ],
      cached: json['recognition_cached'] as bool? ?? false,
      recognitionMs: (timing['recognition_ms'] as num?)?.toInt() ?? 0,
      hintUsed: json['hint_used'] as String?,
      imageBytes: json['image_base64'] != null && (json['image_base64'] as String).isNotEmpty
          ? base64Decode(json['image_base64'] as String)
          : null,
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
    required NutritionValues nutrients,
    this.portionSource = PortionSource.scale,
    this.verificationStatus = 'reference_seed',
    this.syncStatus = 'synced',
    this.notes = '',
    this.basisPer100g,
    this.items = const [],
    this.leftover,
  }) : servedNutrients = nutrients;

  final String id;
  final String foodId;
  final String nameEn;
  final String nameAr;
  final DateTime eatenAt;
  final String mealType;
  final double weightG;
  final double confidence;

  /// What was served: the values stored for the meal. Leftovers never change these.
  final NutritionValues servedNutrients;
  final PortionSource portionSource;
  final String verificationStatus;
  final String syncStatus; // 'synced' | 'pending_sync' | 'saved_locally'
  final String notes;
  final NutritionValues? basisPer100g;
  final List<MealItemEntry> items;

  /// Food weighed after eating, if any. Everything the app totals uses [nutrients], what was eaten.
  final MealLeftover? leftover;

  /// What was eaten: served values less the leftovers.
  NutritionValues get nutrients => eatenNutrients(this);

  double get eatenWeightG => max(0.0, weightG - (leftover?.grams ?? 0));

  String displayName(bool isAr) => isAr && nameAr.isNotEmpty ? nameAr : nameEn;
  String secondaryName(bool isAr) => isAr ? nameEn : nameAr;

  /// Immutable per-100g basis so repeated weight edits never accumulate rounding drift (CALC-04).
  NutritionValues get resolvedBasisPer100g =>
      basisPer100g ?? (weightG > 0 ? servedNutrients.scaledBy(100.0 / weightG) : servedNutrients);

  MealEntry copyWith({
    String? mealType,
    DateTime? eatenAt,
    double? weightG,
    NutritionValues? nutrients,
    PortionSource? portionSource,
    String? verificationStatus,
    String? syncStatus,
    String? notes,
    NutritionValues? basisPer100g,
    List<MealItemEntry>? items,
    MealLeftover? leftover,
    bool clearLeftover = false,
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
        nutrients: nutrients ?? servedNutrients,
        portionSource: portionSource ?? this.portionSource,
        verificationStatus: verificationStatus ?? this.verificationStatus,
        syncStatus: syncStatus ?? this.syncStatus,
        notes: notes ?? this.notes,
        basisPer100g: basisPer100g ?? this.basisPer100g,
        items: items ?? this.items,
        leftover: clearLeftover ? null : (leftover ?? this.leftover),
      );

  /// Recalculates nutrients from the immutable source basis for [newWeightG].
  MealEntry rescaledToWeight(double newWeightG, {PortionSource? newSource}) {
    final basis = resolvedBasisPer100g;
    return copyWith(
      weightG: newWeightG,
      nutrients: basis.forPortionGrams(newWeightG),
      basisPer100g: basis,
      portionSource: newSource ?? portionSource,
    );
  }
}

/// A mixed plate in progress, as the scale reports it. The scale alone sets the grams.
class ScalePlate {
  const ScalePlate({required this.plateId, required this.finished, required this.steps});

  final String plateId;
  final bool finished;
  final List<ScalePlateStep> steps;

  bool get isOpen => !finished;
  double get totalG => steps.fold(0.0, (sum, step) => sum + step.grams);

  factory ScalePlate.fromJson(Map<String, dynamic> json) => ScalePlate(
        plateId: json['plate_id'] as String,
        finished: json['state'] == 'finished',
        steps: (json['steps'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((step) => ScalePlateStep(
                  index: step['index'] as int,
                  grams: (step['grams'] as num).toDouble(),
                  readingG: (step['reading_g'] as num).toDouble(),
                  stepId: step['step_id'] as String?,
                ))
            .toList(),
      );
}

class ScalePlateStep {
  const ScalePlateStep({required this.index, required this.grams, required this.readingG, this.stepId});

  final int index;
  final double grams;
  final double readingG;
  final String? stepId;

  /// Undo and adding again reuse an index, and can even land on the same reading.
  String photoKey(String plateId) => '$plateId/${stepId ?? '$index/$readingG'}';
}

class NutritionGoals {
  const NutritionGoals({
    required this.calories,
    required this.sugar,
    required this.sodium,
    required this.potassium,
    required this.carbohydrates,
    required this.protein,
    this.fat = 70,
    this.fiber = 28,
    this.goalTypes = const {},
    this.source = 'user',
    this.trackingOnly = false,
  });

  final double calories;
  final double sugar;
  final double sodium;
  final double potassium;
  final double carbohydrates;
  final double protein;
  final double fat;
  final double fiber;
  final Map<String, GoalType> goalTypes;
  final String source; // 'user' | 'clinician_entered'
  final bool trackingOnly;

  GoalType typeFor(String key) {
    if (trackingOnly) return GoalType.trackOnly;
    if (goalTypes.containsKey(key)) return goalTypes[key]!;
    return switch (key) {
      'sugar_g' || 'sodium_mg' => GoalType.maximum,
      'fiber_g' || 'protein_g' => GoalType.minimum,
      _ => GoalType.target,
    };
  }

  NutritionGoals copyWith({
    double? calories,
    double? sugar,
    double? sodium,
    double? potassium,
    double? carbohydrates,
    double? protein,
    double? fat,
    double? fiber,
    Map<String, GoalType>? goalTypes,
    String? source,
    bool? trackingOnly,
  }) =>
      NutritionGoals(
        calories: calories ?? this.calories,
        sugar: sugar ?? this.sugar,
        sodium: sodium ?? this.sodium,
        potassium: potassium ?? this.potassium,
        carbohydrates: carbohydrates ?? this.carbohydrates,
        protein: protein ?? this.protein,
        fat: fat ?? this.fat,
        fiber: fiber ?? this.fiber,
        goalTypes: goalTypes ?? this.goalTypes,
        source: source ?? this.source,
        trackingOnly: trackingOnly ?? this.trackingOnly,
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
    this.messageAr = '',
    this.read = false,
    this.acknowledged = false,
    this.superseded = false,
  });

  final String id;
  final String nutrientKey;
  final String severity;
  final double currentValue;
  final double thresholdValue;
  final String message;
  final String messageAr;
  final DateTime createdAt;
  final int evaluationMs;
  final bool read;
  final bool acknowledged;
  final bool superseded;

  String localizedMessage(bool isAr) => isAr && messageAr.isNotEmpty ? messageAr : message;

  HealthAlert copyWith({
    bool? read,
    bool? acknowledged,
    bool? superseded,
  }) =>
      HealthAlert(
        id: id,
        nutrientKey: nutrientKey,
        severity: severity,
        currentValue: currentValue,
        thresholdValue: thresholdValue,
        message: message,
        messageAr: messageAr,
        createdAt: createdAt,
        evaluationMs: evaluationMs,
        read: read ?? this.read,
        acknowledged: acknowledged ?? this.acknowledged,
        superseded: superseded ?? this.superseded,
      );
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

  String displayName(bool isAr) => isAr && nameAr.isNotEmpty ? nameAr : nameEn;

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

class ScaleDeviceState {
  const ScaleDeviceState({
    this.paired = true,
    this.online = false,
    this.capacityG = 5000,
    this.liveWeightG = 0.0,
    this.lockedWeightG,
    this.tareOffsetG = 0.0,
    this.isStable = true,
    this.lastSeen,
    this.simulated = false,
    this.autoCapture = false,
    this.captureState = 'idle',
    this.sensorError,
  });

  final bool paired;
  final bool online;
  final double capacityG;
  final double liveWeightG;
  final double? lockedWeightG;
  final double tareOffsetG;
  final bool isStable;
  final DateTime? lastSeen;
  final bool simulated;
  final bool autoCapture;
  final String captureState;
  final String? sensorError;

  bool get isCapturing => captureState != 'idle';
  bool get isLocked => lockedWeightG != null;
  double get effectiveWeightG => lockedWeightG ?? liveWeightG;

  ScaleDeviceState copyWith({
    bool? paired,
    bool? online,
    double? capacityG,
    double? liveWeightG,
    double? lockedWeightG,
    bool clearLockedWeight = false,
    double? tareOffsetG,
    bool? isStable,
    DateTime? lastSeen,
    bool? simulated,
    bool? autoCapture,
    String? captureState,
    String? sensorError,
    bool clearSensorError = false,
  }) =>
      ScaleDeviceState(
        paired: paired ?? this.paired,
        online: online ?? this.online,
        capacityG: capacityG ?? this.capacityG,
        liveWeightG: liveWeightG ?? this.liveWeightG,
        lockedWeightG: clearLockedWeight ? null : (lockedWeightG ?? this.lockedWeightG),
        tareOffsetG: tareOffsetG ?? this.tareOffsetG,
        isStable: isStable ?? this.isStable,
        lastSeen: lastSeen ?? this.lastSeen,
        simulated: simulated ?? this.simulated,
        autoCapture: autoCapture ?? this.autoCapture,
        captureState: captureState ?? this.captureState,
        sensorError: clearSensorError ? null : (sensorError ?? this.sensorError),
      );
}

class UserAccount {
  static const defaultName = 'Miqdar User';
  static const defaultNameAr = 'مستخدم مقدار';

  bool get hasPersonalName => displayName != defaultName;

  const UserAccount({
    this.userId = 'user-local',
    this.displayName = defaultName,
    this.displayNameAr = defaultNameAr,
    this.email = '',
    this.trackingIntention = 'balanced',
    this.isDemo = false,
    this.authenticated = true,
  });

  final String userId;
  final String displayName;
  final String displayNameAr;
  final String email;
  final String trackingIntention; // 'track_only' | 'balanced' | 'clinician'
  final bool isDemo;
  final bool authenticated;

  String localizedName(bool isAr) => isAr && displayNameAr.isNotEmpty ? displayNameAr : displayName;

  UserAccount copyWith({
    String? userId,
    String? displayName,
    String? displayNameAr,
    String? email,
    String? trackingIntention,
    bool? isDemo,
    bool? authenticated,
  }) =>
      UserAccount(
        userId: userId ?? this.userId,
        displayName: displayName ?? this.displayName,
        displayNameAr: displayNameAr ?? this.displayNameAr,
        email: email ?? this.email,
        trackingIntention: trackingIntention ?? this.trackingIntention,
        isDemo: isDemo ?? this.isDemo,
        authenticated: authenticated ?? this.authenticated,
      );
}


/// Food weighed after a meal. [itemIndex] names the plate food that was left; null means the
/// whole meal, or Mixed on a plate, where the leftovers come off each food by its share.
class MealLeftover {
  const MealLeftover({required this.grams, required this.weighedAt, this.itemIndex});

  final double grams;
  final int? itemIndex;
  final DateTime weighedAt;
}

/// Why a leftover weight cannot be applied, or null when it can.
String? leftoverProblem(MealEntry meal, double grams, {int? itemIndex}) {
  if (grams <= 0) return 'empty';
  if (itemIndex != null) {
    if (itemIndex < 0 || itemIndex >= meal.items.length) return 'no_food';
    if (grams > meal.items[itemIndex].weightG) return 'too_heavy';
    return null;
  }
  if (grams > meal.weightG) return 'too_heavy';
  return null;
}

/// Served values less the leftovers. A chosen plate food loses its own share; otherwise the whole
/// meal is scaled by what was eaten. Missing values stay missing.
NutritionValues eatenNutrients(MealEntry meal) {
  final left = meal.leftover;
  final served = meal.servedNutrients;
  if (left == null || left.grams <= 0) return served;
  final index = left.itemIndex;
  if (index != null && index >= 0 && index < meal.items.length) {
    final item = meal.items[index];
    if (item.weightG <= 0) return served;
    final share = min(1.0, left.grams / item.weightG);
    return served + item.nutrients.scaledBy(-share);
  }
  if (meal.weightG <= 0) return served;
  return served.scaledBy(max(0.0, (meal.weightG - left.grams) / meal.weightG));
}

/// The leftover values themselves, for the "food not eaten" total.
NutritionValues leftoverNutrients(MealEntry meal) => meal.servedNutrients + meal.nutrients.scaledBy(-1);
