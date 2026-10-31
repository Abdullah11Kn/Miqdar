import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../data/food_catalog.dart';
import '../models/nutrition.dart';

String _defaultBaseUrl() {
  const envUrl = String.fromEnvironment('MIQDAR_API_URL');
  if (envUrl.isNotEmpty) return envUrl;
  if (kIsWeb) {
    if (Uri.base.hasAuthority && Uri.base.scheme.startsWith('http')) {
      return Uri.base.origin;
    }
    return 'http://127.0.0.1:8080';
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8080';
  }
  return 'http://127.0.0.1:8080';
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A recognition failure that should be shown to the user, never hidden.
class RecognitionException implements Exception {
  const RecognitionException(this.code, this.message, {this.candidates = const []});

  /// Stable code from the backend (e.g. NOT_FOOD, FOOD_NOT_IN_DATABASE,
  /// AI_PROVIDER_UNAVAILABLE) or SERVER_UNREACHABLE when the API is down.
  final String code;
  final String message;

  /// Raw AI labels, when the server returned them (e.g. food not in database).
  final List<String> candidates;

  bool get serverUnreachable => code == 'SERVER_UNREACHABLE';

  String get title => localizedTitle(false);

  String localizedTitle(bool isAr) => switch (code) {
        'NOT_FOOD' => isAr ? 'لم يتم اكتشاف طعام في الصورة' : 'No food detected in photo',
        'FOOD_NOT_IN_DATABASE' => isAr
            ? 'الطعام غير موجود في قاعدة بيانات مقدار'
            : 'Food not in the Miqdar database',
        'INVALID_IMAGE' => isAr ? 'تعذّر قراءة ملف الصورة' : 'Photo could not be read',
        'AI_PROVIDER_UNAVAILABLE' => isAr
            ? 'خدمة الذكاء الاصطناعي غير متاحة حالياً'
            : 'AI recognition service unavailable',
        'SERVER_UNREACHABLE' => isAr
            ? 'تعذّر الاتصال بخادم مقدار'
            : 'Cannot reach the Miqdar server',
        _ => isAr ? 'تعذّر إتمام التعرّف' : 'Recognition could not complete',
      };

  String recoveryAdvice(bool isAr) => switch (code) {
        'NOT_FOOD' => isAr
            ? 'التقط صورة واضحة للطبق مع إضاءة جيدة، أو اختر الطعام يدوياً من الدليل الغذائي.'
            : 'Retake a clear photo centered on the dish, or choose the food from the catalog.',
        'FOOD_NOT_IN_DATABASE' => isAr
            ? 'تعرّف الذكاء الاصطناعي على الطبق ولكنه غير مسجل بعد. يمكنك اختيار أقرب صنف من الدليل أو إضافة طعام مخصص.'
            : 'The AI identified labels not yet mapped in the catalog. Search the food catalog or create a custom entry.',
        'SERVER_UNREACHABLE' => isAr
            ? 'تحقق من تشغيل الخادم المحلي، أو استخدم وضع المعاينة التجريبية أو البحث في الدليل المحلي.'
            : 'Ensure the backend server is running, or continue with the Offline Demo or local Food Catalog.',
        _ => isAr
            ? 'تم حفظ الوزن والصورة في المسودة. يمكنك المحاولة مرة أخرى أو اختيار الطعام يدوياً.'
            : 'Your portion weight and photo are preserved. Retry or select the food manually.',
      };

  @override
  String toString() => 'RecognitionException($code): $message';
}

class ApiService {
  ApiService({
    String? baseUrl,
    this.apiToken = const String.fromEnvironment('MIQDAR_API_TOKEN'),
    http.Client? client,
  })  : baseUrl = baseUrl ?? _defaultBaseUrl(),
        _client = client ?? http.Client();

  String baseUrl;
  final String apiToken;
  final http.Client _client;
  static const requestTimeout = Duration(seconds: 25);
  static const demoImageAsset = 'assets/demo/kabsa.jpg';

  void updateBaseUrl(String newUrl) {
    var cleaned = newUrl.trim();
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    baseUrl = cleaned;
  }

  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        if (apiToken.isNotEmpty) 'Authorization': 'Bearer $apiToken',
      };

  /// Sends the photo + scale weight to the backend AI pipeline.
  Future<RecognitionResult> recognize({
    required XFile? image,
    Uint8List? customImageBytes,
    String? assetPath,
    required double weightG,
    String? hint,
    PortionSource portionSource = PortionSource.scale,
  }) async {
    final Uint8List imageBytes;
    if (customImageBytes != null) {
      imageBytes = customImageBytes;
    } else if (image != null) {
      imageBytes = await image.readAsBytes();
    } else {
      imageBytes = (await rootBundle.load(assetPath ?? demoImageAsset)).buffer.asUint8List();
    }
    final trimmedHint = hint?.trim();
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/recognize'),
            headers: _jsonHeaders,
            body: jsonEncode({
              'user_id': 'demo-user',
              'image_base64': base64Encode(imageBytes),
              'weight_g': weightG,
              if (trimmedHint != null && trimmedHint.isNotEmpty) 'hint': trimmedHint,
            }),
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw RecognitionException(
        'SERVER_UNREACHABLE',
        'The server at $baseUrl did not answer within ${requestTimeout.inSeconds} s.',
      );
    } catch (error) {
      if (error is RecognitionException) rethrow;
      throw RecognitionException('SERVER_UNREACHABLE', 'Cannot connect to $baseUrl ($error).');
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw RecognitionException(
        'BAD_RESPONSE',
        'The server returned HTTP ${response.statusCode} with an unreadable body.',
      );
    }
    if (response.statusCode != 200) {
      final candidates = (body['candidates'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => item['label'] as String? ?? '')
          .where((label) => label.isNotEmpty)
          .toList();
      throw RecognitionException(
        body['error'] as String? ?? 'HTTP_${response.statusCode}',
        body['message'] as String? ?? 'The server returned HTTP ${response.statusCode}.',
        candidates: candidates,
      );
    }
    final parsed = RecognitionResult.fromJson(body);
    return RecognitionResult(
      eventId: parsed.eventId,
      foodId: parsed.foodId,
      nameEn: parsed.nameEn,
      nameAr: parsed.nameAr,
      weightG: parsed.weightG,
      confidence: parsed.confidence,
      verificationStatus: parsed.verificationStatus,
      nutrients: parsed.nutrients,
      alertEvaluationMs: parsed.alertEvaluationMs,
      alertSloMet: parsed.alertSloMet,
      isMock: parsed.isMock,
      provider: parsed.provider,
      model: parsed.model,
      candidates: parsed.candidates,
      cached: parsed.cached,
      recognitionMs: parsed.recognitionMs,
      hintUsed: parsed.hintUsed,
      userCorrected: parsed.userCorrected,
      portionSource: portionSource,
      basisPer100g: parsed.resolvedBasisPer100g,
      imageBytes: imageBytes,
    );
  }

  /// Clearly-labelled offline demonstration result. Only used when the user
  /// explicitly chooses it after the server could not be reached or in Demo Workspace.
  RecognitionResult offlineDemoResult({
    required String? hint,
    required double weightG,
    PortionSource portionSource = PortionSource.scale,
    Uint8List? imageBytes,
  }) {
    final primary = MiqdarFoodCatalog.findByIdOrLabel(hint ?? 'chicken kabsa') ??
        MiqdarFoodCatalog.findByIdOrLabel('medjool dates')!;

    // Pick 2 related alternatives so Top-3 candidate switching can be demonstrated offline.
    final sameCategory = MiqdarFoodCatalog.builtInFoods
        .where((f) => f.foodId != primary.foodId && f.category == primary.category)
        .take(2)
        .toList();
    final fallbackAlts = MiqdarFoodCatalog.builtInFoods
        .where((f) => f.foodId != primary.foodId && !sameCategory.contains(f))
        .take(2 - sameCategory.length)
        .toList();
    final alts = [...sameCategory, ...fallbackAlts];

    final candidates = <RecognitionCandidate>[
      RecognitionCandidate(
        rank: 1,
        label: primary.nameEn.toLowerCase(),
        confidence: 0.93,
        selected: true,
        foodId: primary.foodId,
        nameEn: primary.nameEn,
        nameAr: primary.nameAr,
        verificationStatus: primary.verificationStatus,
        nutrients: primary.per100g.forPortionGrams(weightG),
      ),
      for (var i = 0; i < alts.length; i++)
        RecognitionCandidate(
          rank: i + 2,
          label: alts[i].nameEn.toLowerCase(),
          confidence: i == 0 ? 0.78 : 0.64,
          selected: false,
          foodId: alts[i].foodId,
          nameEn: alts[i].nameEn,
          nameAr: alts[i].nameAr,
          verificationStatus: alts[i].verificationStatus,
          nutrients: alts[i].per100g.forPortionGrams(weightG),
        ),
    ];

    return RecognitionResult(
      eventId: 'offline-${DateTime.now().microsecondsSinceEpoch}',
      foodId: primary.foodId,
      nameEn: primary.nameEn,
      nameAr: primary.nameAr,
      weightG: weightG,
      confidence: 0.93,
      verificationStatus: primary.verificationStatus,
      nutrients: primary.per100g.forPortionGrams(weightG),
      basisPer100g: primary.per100g,
      alertEvaluationMs: 1,
      alertSloMet: true,
      isMock: true,
      provider: 'offline-demo',
      model: 'demo-catalog-v3',
      candidates: candidates,
      recognitionMs: 42,
      hintUsed: hint,
      portionSource: portionSource,
      imageBytes: imageBytes,
    );
  }

  Future<Map<String, dynamic>> health() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/health'), headers: _jsonHeaders)
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      throw ApiException('Server health check failed: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Fetches real-time telemetry from physical scale (/scale/live).
  Future<Map<String, dynamic>> getScaleLive() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/scale/live'), headers: _jsonHeaders)
        .timeout(const Duration(seconds: 4));
    if (response.statusCode != 200) {
      throw ApiException('Failed to read live scale: ${response.body}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  /// Sends a remote Tare command to the physical scale (/scale/tare).
  Future<bool> remoteScaleTare() async {
    try {
      final response = await _client
          .post(Uri.parse('$baseUrl/scale/tare'), headers: _jsonHeaders, body: jsonEncode({}))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return body['success'] as bool? ?? true;
      }
    } catch (_) {}
    return false;
  }

  /// Triggers physical scale photo capture and load-cell measurement.
  Future<RecognitionResult> captureFromScale({String? hint}) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/scale/capture'),
          headers: _jsonHeaders,
          body: jsonEncode({if (hint != null) 'hint': hint}),
        )
        .timeout(requestTimeout);
    if (response.statusCode != 200) {
      final bodyStr = response.body;
      if (bodyStr.contains('1033') || response.statusCode == 530) {
        throw const ApiException(
          'Cloudflare Tunnel is unreachable (Error 1033). Please check that ./start_cloudflare_tunnel.sh and python3 app.py are running on your Raspberry Pi and the current URL matches.',
        );
      }
      if (bodyStr.contains('<!DOCTYPE') || bodyStr.contains('<html')) {
        throw ApiException('Server returned HTTP ${response.statusCode}. Check your Scale API URL.');
      }
      throw ApiException(bodyStr);
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return RecognitionResult.fromJson(body);
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
      throw ApiException('Health profile could not be saved: ${response.body}');
    }
  }

  Future<void> saveGoalsOnServer(NutritionGoals goals) async {
    final response = await _client
        .put(
          Uri.parse('$baseUrl/goals'),
          headers: _jsonHeaders,
          body: jsonEncode({
            'user_id': 'demo-user',
            'calories_kcal': goals.calories,
            'sugar_g': goals.sugar,
            'sodium_mg': goals.sodium,
            'potassium_mg': goals.potassium,
            'carbohydrate_g': goals.carbohydrates,
            'protein_g': goals.protein,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw ApiException('Goals could not be saved: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> logMeal({
    required String foodId,
    required double weightG,
    double confidence = 1.0,
    String mealType = 'Meal',
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/meals'),
          headers: _jsonHeaders,
          body: jsonEncode({
            'user_id': 'demo-user',
            'food_id': foodId,
            'weight_g': weightG,
            'confidence': confidence,
            'meal_type': mealType,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 201) {
      throw ApiException('Meal could not be logged on server: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<RecommendationResponse> recommendMeals({
    required HealthProfile profile,
    required List<MealEntry> recentMeals,
    int limit = 6,
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
        throw ApiException('Recommendations failed: ${response.body}');
      }
      return RecommendationResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      return _offlineRecommendations(profile, recentMeals, limit);
    }
  }

  RecommendationResponse _offlineRecommendations(
    HealthProfile profile,
    List<MealEntry> recentMeals,
    int limit,
  ) {
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

    for (final item in MiqdarFoodCatalog.builtInFoods) {
      final name = item.nameEn.toLowerCase();
      final nameAr = item.nameAr;
      if (exclusions.any((value) => name.contains(value) || nameAr.contains(value))) continue;
      if (exclusions.contains('nuts') && name.contains('almond')) continue;
      if ((exclusions.contains('dairy') || exclusions.contains('milk')) && item.category == 'Dairy') continue;
      if ((exclusions.contains('fish') || exclusions.contains('seafood')) &&
          (name.contains('salmon') || name.contains('tuna') || name.contains('fish'))) {
        continue;
      }
      final isMeatOrFish = name.contains('chicken') ||
          name.contains('lamb') ||
          name.contains('beef') ||
          name.contains('salmon') ||
          name.contains('tuna') ||
          name.contains('fish') ||
          name.contains('haneeth') ||
          name.contains('shawarma') ||
          name.contains('kabsa') ||
          name.contains('mandi');
      if (preferences.contains('vegetarian') && isMeatOrFish) continue;
      if (preferences.contains('vegan') &&
          (isMeatOrFish || item.category == 'Dairy' || name.contains('egg') || name.contains('honey'))) {
        continue;
      }

      final portionG = item.servings.isNotEmpty ? item.servings.first.grams : 150.0;
      final nutrients = item.per100g.forPortionGrams(portionG);
      var score = 74.0 - (recentCounts[item.foodId] ?? 0) * 5;
      final why = <String>[];

      if ((recentCounts[item.foodId] ?? 0) == 0) {
        why.add('Adds variety compared with the last 14 days');
      }
      if (conditions.contains('diabetes')) {
        score += nutrients.sugar <= 8 ? 12 : -nutrients.sugar * 0.6;
        if (nutrients.sugar <= 8) why.add('Lower-sugar option (${nutrients.sugar.toStringAsFixed(1)} g sugar)');
      }
      if (conditions.contains('hypertension')) {
        score += nutrients.sodium <= 220 ? 12 : -nutrients.sodium / 35;
        if (nutrients.sodium <= 220) why.add('Moderate/low sodium (${nutrients.sodium.toStringAsFixed(0)} mg)');
      }
      if (conditions.contains('weight_management') && item.per100g.calories <= 175) {
        score += 9;
        why.add('Balanced energy density (${item.per100g.calories.toStringAsFixed(0)} kcal/100g)');
      }
      if (conditions.contains('high_cholesterol') && nutrients.fat <= 8) {
        score += 8;
        why.add('Lower total fat per portion (${nutrients.fat.toStringAsFixed(1)} g)');
      }
      if (conditions.contains('kidney_disease')) {
        score -= nutrients.potassium > 260 ? 14 : 0;
        why.add('Compare against clinician-supplied sodium & potassium targets');
      }
      if (nutrients.protein >= 15) {
        score += 5;
        why.add('Provides ${nutrients.protein.toStringAsFixed(1)} g protein per serving');
      }
      if (why.isEmpty) {
        why.add('Balances variety with your configured nutrition targets');
      }

      suggestions.add(MealSuggestion(
        foodId: item.foodId,
        nameEn: item.nameEn,
        nameAr: item.nameAr,
        portionG: portionG,
        score: score.clamp(10, 99).toDouble(),
        nutrients: nutrients,
        why: why.take(3).toList(),
        recentOccurrences: recentCounts[item.foodId] ?? 0,
        verificationStatus: item.verificationStatus,
      ));
    }
    suggestions.sort((a, b) => b.score.compareTo(a.score));
    return RecommendationResponse(
      suggestions: suggestions.take(limit).toList(),
      disclaimer:
          'General planning ideas based on your configured exclusions, targets, and 14-day meal history. Not a medical prescription or allergy guarantee.',
      method: 'transparent_catalog_scoring_v3',
      offline: true,
    );
  }
}
