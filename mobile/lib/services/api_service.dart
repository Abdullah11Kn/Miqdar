import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../data/food_catalog.dart';
import '../models/nutrition.dart';
import 'gemini_service.dart';

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
  const RecognitionException(
    this.code,
    this.message, {
    this.candidates = const [],
    this.eventId,
  });

  /// Stable code from the backend (e.g. NOT_FOOD, FOOD_NOT_IN_DATABASE,
  /// AI_PROVIDER_UNAVAILABLE) or SERVER_UNREACHABLE when the API is down.
  final String code;
  final String message;

  /// Raw AI labels, when the server returned them (e.g. food not in database).
  final List<String> candidates;

  /// Set when the scale published this failure as a capture event (with its photo).
  final String? eventId;

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
        'AI_KEY_MISSING' => isAr ? 'مفتاح Gemini غير مضبوط' : 'Gemini API key not set',
        'AI_QUOTA_EXCEEDED' => isAr ? 'تم بلوغ حد استخدام Gemini' : 'Gemini usage limit reached',
        'SERVER_UNREACHABLE' => isAr
            ? 'تعذّر الاتصال بخادم مقدار'
            : 'Cannot reach the Miqdar server',
        'CAMERA_UNAVAILABLE' => isAr ? 'كاميرا الميزان لا تستجيب' : 'Scale camera not responding',
        'EMPTY_SCALE' => isAr ? 'لا يوجد طعام على الميزان' : 'Nothing on the scale',
        'WEIGHT_NOT_STEADY' => isAr ? 'الوزن غير مستقر' : 'The weight is still moving',
        'CAPTURE_IN_PROGRESS' => isAr ? 'الميزان يلتقط صورة الآن' : 'Scale is already capturing',
        'CAPTURE_STILL_RUNNING' => isAr ? 'التحليل مستمر' : 'Still analyzing',
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
        'AI_QUOTA_EXCEEDED' => isAr
            ? 'انتظر دقيقة ثم حاول مرة أخرى. إذا استمرت المشكلة فقد انتهى الحد اليومي لمفتاحك.'
            : 'Wait a minute and try again. If it continues, your key has used its daily limit.',
        'AI_KEY_MISSING' => isAr
            ? 'شغّل التطبيق باستخدام ./run_simulator.sh لقراءة المفتاح من ملف .env.'
            : 'Start the app with ./run_simulator.sh so it reads the key from your .env file.',
        'CAMERA_UNAVAILABLE' => isAr
            ? 'تحقق من توصيل كابل الكاميرا بالراسبيري باي ثم حاول مرة أخرى.'
            : 'Check the camera ribbon cable on the Raspberry Pi, then try again.',
        'WEIGHT_NOT_STEADY' => isAr
            ? 'ارفع يدك عن الطبق وانتظر ثانية ثم أعد الالتقاط.'
            : 'Take your hand off the plate, wait a second, then capture again.',
        'EMPTY_SCALE' => isAr
            ? 'ضع الطعام على الطبق ثم أعد الالتقاط.'
            : 'Put the food on the plate, then capture again.',
        _ => isAr
            ? 'تم حفظ الوزن والصورة في المسودة. يمكنك المحاولة مرة أخرى أو اختيار الطعام يدوياً.'
            : 'Your portion weight and photo are preserved. Retry or select the food manually.',
      };

  @override
  String toString() => 'RecognitionException($code): $message';
}

/// Turns what a person types ("foodscale.local", "192.168.1.20", a tunnel link) into a full URL.
String normalizeScaleAddress(String input) {
  var address = input.trim();
  while (address.endsWith('/')) {
    address = address.substring(0, address.length - 1);
  }
  if (address.isEmpty || address.contains('://')) return address;
  final host = address.split(':').first;
  final isLocal = host == 'localhost' ||
      host.endsWith('.local') ||
      RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host);
  if (!isLocal) return 'https://$address';
  return address.contains(':') ? 'http://$address' : 'http://$address:8080';
}

class ApiService {
  ApiService({
    String? baseUrl,
    this.apiToken = const String.fromEnvironment('MIQDAR_API_TOKEN'),
    http.Client? client,
    GeminiNutritionService? gemini,
  })  : baseUrl = baseUrl ?? _defaultBaseUrl(),
        _client = client ?? http.Client(),
        gemini = gemini ?? GeminiNutritionService(client: client);

  String baseUrl;
  final String apiToken;
  final http.Client _client;

  /// Identifies food and estimates nutrition. Used whenever the app has a Gemini key.
  final GeminiNutritionService gemini;
  static const requestTimeout = Duration(seconds: 25);

  /// Settling + autofocus + the Gemini fallback chain (35 s deadline on the scale).
  static const captureTimeout = Duration(seconds: 60);
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
    if (gemini.configured) {
      return gemini.analyze(
        imageBytes: imageBytes,
        weightG: weightG,
        hint: hint,
        portionSource: portionSource,
      );
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
      throw ApiException(_describeScaleHttpFailure(response));
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  /// The full last capture, photo included. /scale/live only carries its summary.
  Future<Map<String, dynamic>> getLatestScaleCapture() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/scale/capture/latest'), headers: _jsonHeaders)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw ApiException(_describeScaleHttpFailure(response));
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  String _describeScaleHttpFailure(http.Response response) {
    final status = response.statusCode;
    final body = response.body;
    if (status == 530 || body.contains('1033')) {
      return 'This tunnel URL is no longer active. Read the current one from the scale screen.';
    }
    if (status == 502 || status == 504) {
      return 'The tunnel is up but the scale app is not running on the Raspberry Pi.';
    }
    if (status == 401) {
      return 'The scale requires an API token (MIQDAR_API_TOKEN).';
    }
    if (body.contains('<!DOCTYPE') || body.contains('<html')) {
      return 'Server returned HTTP $status. Check the scale address.';
    }
    return 'The scale returned HTTP $status.';
  }

  /// Sends a remote Tare command to the physical scale (/scale/tare).
  Future<bool> remoteScaleTare() async {
    try {
      final response = await _client
          .post(Uri.parse('$baseUrl/scale/tare'), headers: _jsonHeaders, body: jsonEncode({}))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return body['success'] as bool? ?? true;
      }
    } catch (_) {}
    return false;
  }

  /// Tells the scale what the phone found, so its touchscreen can show the calories too.
  Future<void> postScaleResult(RecognitionResult result) async {
    try {
      await _client
          .post(
            Uri.parse('$baseUrl/scale/capture/result'),
            headers: _jsonHeaders,
            body: jsonEncode({
              'event_id': result.eventId,
              'food': {'name_en': result.nameEn},
              'nutrients': {
                'calories_kcal': result.nutrients.calories,
                'carbohydrate_g': result.nutrients.carbohydrates,
                'protein_g': result.nutrients.protein,
                'fat_g': result.nutrients.fat,
                'sugar_g': result.nutrients.sugar,
              },
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // The scale's own screen is a convenience; the phone already has the result.
    }
  }

  /// Triggers physical scale photo capture and load-cell measurement. Returns the capture
  /// event: a weighed photo to analyse, or a finished draft from --analyze-on-scale.
  /// Either way the meal is logged only when the user saves it on the review screen.
  Future<Map<String, dynamic>> captureFromScale({String? hint}) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/scale/capture'),
            headers: _jsonHeaders,
            body: jsonEncode({'save': false, if (hint != null) 'hint': hint}),
          )
          .timeout(captureTimeout);
    } on TimeoutException {
      throw const RecognitionException(
        'CAPTURE_STILL_RUNNING',
        'The scale is taking longer than usual. The result will open here as soon as it is ready.',
      );
    } catch (error) {
      throw RecognitionException('SERVER_UNREACHABLE', 'Cannot connect to $baseUrl ($error).');
    }
    Map<String, dynamic>? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {}
    if (response.statusCode == 200 && body != null) {
      return body;
    }
    if (body == null) {
      throw RecognitionException('SERVER_UNREACHABLE', _describeScaleHttpFailure(response));
    }
    throw recognitionExceptionFromJson(body, fallbackStatus: response.statusCode);
  }

  /// Builds the exception for a failed capture, from an API error or a capture event.
  static RecognitionException recognitionExceptionFromJson(
    Map<String, dynamic> json, {
    int? fallbackStatus,
  }) =>
      RecognitionException(
        json['error'] as String? ?? 'HTTP_$fallbackStatus',
        json['message'] as String? ?? 'The scale could not finish the capture.',
        candidates: (json['candidates'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((item) => item['label'] as String? ?? '')
            .where((label) => label.isNotEmpty)
            .toList(),
        eventId: json['event_id'] as String?,
      );

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
    bool isAr = false,
  }) async {
    if (offlineOnly) return _offlineRecommendations(profile, recentMeals, limit, isAr);
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
      return _offlineRecommendations(profile, recentMeals, limit, isAr);
    }
  }

  RecommendationResponse _offlineRecommendations(
    HealthProfile profile,
    List<MealEntry> recentMeals,
    int limit,
    bool isAr,
  ) {
    String tr(String en, String ar) => isAr ? ar : en;
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
        why.add(tr('Something different from your last two weeks', 'مختلف عما تناولته في آخر أسبوعين'));
      }
      if (conditions.contains('diabetes')) {
        score += nutrients.sugar <= 8 ? 12 : -nutrients.sugar * 0.6;
        if (nutrients.sugar <= 8) why.add(tr('Lower in sugar (${nutrients.sugar.toStringAsFixed(1)} g)', 'سكر أقل (${nutrients.sugar.toStringAsFixed(1)} غ)'));
      }
      if (conditions.contains('hypertension')) {
        score += nutrients.sodium <= 220 ? 12 : -nutrients.sodium / 35;
        if (nutrients.sodium <= 220) why.add(tr('Lower in sodium (${nutrients.sodium.toStringAsFixed(0)} mg)', 'صوديوم أقل (${nutrients.sodium.toStringAsFixed(0)} ملغ)'));
      }
      if (conditions.contains('weight_management') && item.per100g.calories <= 175) {
        score += 9;
        why.add(tr('Lighter choice (${item.per100g.calories.toStringAsFixed(0)} kcal per 100 g)', 'خيار أخف (${item.per100g.calories.toStringAsFixed(0)} سعرة لكل 100 غ)'));
      }
      if (conditions.contains('high_cholesterol') && nutrients.fat <= 8) {
        score += 8;
        why.add(tr('Lower in fat (${nutrients.fat.toStringAsFixed(1)} g)', 'دهون أقل (${nutrients.fat.toStringAsFixed(1)} غ)'));
      }
      if (conditions.contains('kidney_disease')) {
        score -= nutrients.potassium > 260 ? 14 : 0;
        why.add(tr('Check against the sodium and potassium limits from your clinician', 'قارنه بحدود الصوديوم والبوتاسيوم من مختصك الصحي'));
      }
      if (nutrients.protein >= 15) {
        score += 5;
        why.add(tr('${nutrients.protein.toStringAsFixed(1)} g protein per serving', '${nutrients.protein.toStringAsFixed(1)} غ بروتين في الحصة'));
      }
      if (why.isEmpty) {
        why.add(tr('Fits your goals and adds variety', 'يناسب أهدافك ويضيف تنوعاً'));
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
      disclaimer: tr(
        'General ideas based on your preferences and recent meals. Not medical advice, and not a guarantee that a food is free of an allergen.',
        'أفكار عامة مبنية على تفضيلاتك ووجباتك الأخيرة. ليست نصيحة طبية ولا ضماناً لخلو الطعام من مسببات الحساسية.',
      ),
      method: 'transparent_catalog_scoring_v3',
      offline: true,
    );
  }
}
