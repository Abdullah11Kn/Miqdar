import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../data/food_catalog.dart';
import '../models/nutrition.dart';
import 'api_service.dart';

/// Identifies food in a photo and estimates its nutrition per 100 g with Gemini.
///
/// The scale still measures the portion: every value is the estimate per 100 g
/// multiplied by the weighed grams. The catalog supplies dish names only, because
/// without them Gemini reads Saudi dishes as similar-looking foreign ones.
///
/// The key is compiled into the app with --dart-define, which can be extracted from
/// an installed build. That suits local testing only; a released app must call Gemini
/// through a server that holds the key.
class GeminiNutritionService {
  GeminiNutritionService({
    this.apiKey = const String.fromEnvironment('GEMINI_API_KEY'),
    this.models = _defaultModels,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const _defaultModels = [
    'gemini-3.1-flash-lite',
    'gemini-3.5-flash-lite',
    'gemini-flash-latest',
  ];
  static const _endpoint = 'https://generativelanguage.googleapis.com/v1beta/models';
  // Answers normally take 2-3 s, so a slow model is skipped instead of waited for.
  static const _perRequestTimeout = Duration(seconds: 8);
  static const _totalDeadline = Duration(seconds: 35);
  static const _retryableStatus = {400, 404, 429, 500, 502, 503, 504};
  static const _notFoodLabels = {'not food', 'no food', 'non-food'};

  final String apiKey;
  final List<String> models;
  final http.Client _client;

  bool get configured => apiKey.trim().isNotEmpty;

  Future<RecognitionResult> analyze({
    required Uint8List imageBytes,
    required double weightG,
    String? hint,
    String? eventId,
    PortionSource portionSource = PortionSource.scale,
  }) async {
    if (!configured) {
      throw const RecognitionException(
        'AI_KEY_MISSING',
        'This build of the app has no Gemini API key.',
      );
    }
    if (imageBytes.isEmpty) {
      throw const RecognitionException('INVALID_IMAGE', 'The photo is empty.');
    }
    final started = DateTime.now();
    final deadline = started.add(_totalDeadline);
    final payload = jsonEncode(_requestBody(imageBytes, weightG, hint));

    RecognitionException? lastError;
    for (final model in models) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining < const Duration(seconds: 1)) break;
      try {
        final response = await _client
            .post(
              Uri.parse('$_endpoint/$model:generateContent'),
              headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
              body: payload,
            )
            .timeout(model == models.last || remaining < _perRequestTimeout ? remaining : _perRequestTimeout);
        if (response.statusCode != 200) {
          lastError = RecognitionException(
            'AI_PROVIDER_UNAVAILABLE',
            'Gemini returned HTTP ${response.statusCode}.',
          );
          if (_retryableStatus.contains(response.statusCode)) continue;
          throw lastError;
        }
        return _parseResult(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
          model: model,
          weightG: weightG,
          hint: hint,
          eventId: eventId,
          portionSource: portionSource,
          imageBytes: imageBytes,
          recognitionMs: DateTime.now().difference(started).inMilliseconds,
        );
      } on RecognitionException catch (error) {
        if (error.code != 'AI_PROVIDER_UNAVAILABLE' || error == lastError) rethrow;
        lastError = error;
      } on TimeoutException {
        lastError = const RecognitionException('AI_PROVIDER_UNAVAILABLE', 'Gemini did not answer in time.');
      } catch (_) {
        lastError = const RecognitionException('AI_PROVIDER_UNAVAILABLE', 'Could not reach Gemini.');
      }
    }
    throw lastError ??
        const RecognitionException('AI_PROVIDER_UNAVAILABLE', 'Gemini did not answer in time.');
  }

  Map<String, dynamic> _requestBody(Uint8List imageBytes, double weightG, String? hint) {
    final trimmedHint = hint?.trim() ?? '';
    final knownDishes = MiqdarFoodCatalog.builtInFoods.map((food) => food.nameEn).join('; ');
    final prompt = 'You are the food analysis step of the Miqdar smart kitchen scale used in Saudi '
        'Arabia, so expect Saudi and Gulf home cooking first. Identify the primary food or dish '
        'in the photo and return up to three ranked candidates, with confidence between 0 and 1 '
        'reflecting real uncertainty. When a candidate is one of these dishes, use exactly this '
        'name: $knownDishes. Otherwise use a short common English name. For each, give '
        'its name in English and Arabic and your best estimate of its nutrition per 100 g of the '
        'item exactly as it sits on the scale, including typical oil, sauce and rice for that '
        'dish. If the photo shows parts people do not eat, such as peel, rind, shells, bones or '
        'pits, they are part of the weighed grams, so lower the values to match: half a '
        'pomegranate in its rind is about half edible, so it has about half the calories per '
        '100 g of the seeds alone. Give values per 100 g, not for the portion. The scale measured ${weightG.toStringAsFixed(0)} g on the '
        'plate; use this only to judge what the dish is. If the photo does not show food or '
        "drink, return a single candidate named 'not food' with all values 0."
        '${trimmedHint.isEmpty ? '' : ' The user added this note, as weak context only: "$trimmedHint".'}';
    const number = {'type': 'number', 'minimum': 0};
    return {
      'contents': [
        {
          'parts': [
            {
              'inline_data': {'mime_type': _mimeType(imageBytes), 'data': base64Encode(imageBytes)},
            },
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.1,
        'responseMimeType': 'application/json',
        'responseJsonSchema': {
          'type': 'object',
          'properties': {
            'candidates': {
              'type': 'array',
              'maxItems': 3,
              'items': {
                'type': 'object',
                'properties': {
                  'name_en': {'type': 'string'},
                  'name_ar': {'type': 'string'},
                  'confidence': {'type': 'number', 'minimum': 0, 'maximum': 1},
                  'per_100g': {
                    'type': 'object',
                    'properties': {
                      for (final key in _nutrientKeys) key: number,
                    },
                    'required': _nutrientKeys,
                  },
                },
                'required': ['name_en', 'name_ar', 'confidence', 'per_100g'],
              },
            },
          },
          'required': ['candidates'],
        },
      },
    };
  }

  static const _nutrientKeys = [
    'calories_kcal', 'protein_g', 'carbohydrate_g', 'fat_g',
    'sugar_g', 'fiber_g', 'sodium_mg', 'potassium_mg',
  ];

  RecognitionResult _parseResult(
    Map<String, dynamic> body, {
    required String model,
    required double weightG,
    required String? hint,
    required String? eventId,
    required PortionSource portionSource,
    required Uint8List imageBytes,
    required int recognitionMs,
  }) {
    final List<dynamic> raw;
    try {
      final parts = (body['candidates'] as List<dynamic>)[0]['content']['parts'] as List<dynamic>;
      final text = parts.map((part) => (part as Map<String, dynamic>)['text'] ?? '').join();
      raw = (jsonDecode(text) as Map<String, dynamic>)['candidates'] as List<dynamic>;
    } catch (_) {
      throw const RecognitionException('AI_PROVIDER_UNAVAILABLE', 'Gemini returned an unreadable answer.');
    }

    final candidates = raw.whereType<Map<String, dynamic>>().toList();
    if (candidates.isEmpty) {
      throw const RecognitionException('AI_PROVIDER_UNAVAILABLE', 'Gemini returned no candidates.');
    }
    final firstName = (candidates.first['name_en'] as String? ?? '').trim().toLowerCase();
    if (_notFoodLabels.contains(firstName)) {
      throw const RecognitionException('NOT_FOOD', 'No food was detected in the photo.');
    }

    final usable = <({String name, String nameAr, double confidence, NutritionValues per100g})>[];
    for (final item in candidates) {
      final name = (item['name_en'] as String? ?? '').trim();
      final values = item['per_100g'];
      if (name.isEmpty || values is! Map<String, dynamic>) continue;
      if (!_nutrientKeys.every((key) => values[key] is num)) continue;
      final per100g = NutritionValues.fromJson(values);
      if (_plausible(per100g)) {
        usable.add((
          name: name,
          nameAr: (item['name_ar'] as String? ?? '').trim(),
          confidence: ((item['confidence'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
          per100g: per100g,
        ));
      }
    }
    if (usable.isEmpty) {
      throw const RecognitionException(
        'AI_PROVIDER_UNAVAILABLE',
        'Gemini returned nutrition values that cannot be right. Try again.',
      );
    }

    final best = usable.first;
    return RecognitionResult(
      eventId: eventId ?? 'gemini-${DateTime.now().microsecondsSinceEpoch}',
      foodId: _foodId(best.name),
      nameEn: best.name,
      nameAr: best.nameAr,
      weightG: weightG,
      confidence: best.confidence,
      verificationStatus: aiEstimateStatus,
      nutrients: best.per100g.forPortionGrams(weightG),
      basisPer100g: best.per100g,
      alertEvaluationMs: 0,
      alertSloMet: true,
      isMock: false,
      provider: 'gemini',
      model: model,
      candidates: [
        for (var i = 0; i < usable.length; i++)
          RecognitionCandidate(
            rank: i + 1,
            label: usable[i].name.toLowerCase(),
            confidence: usable[i].confidence,
            selected: i == 0,
            foodId: _foodId(usable[i].name),
            nameEn: usable[i].name,
            nameAr: usable[i].nameAr,
            verificationStatus: aiEstimateStatus,
            nutrients: usable[i].per100g.forPortionGrams(weightG),
          ),
      ],
      recognitionMs: recognitionMs,
      hintUsed: hint,
      portionSource: portionSource,
      imageBytes: imageBytes,
    );
  }

  /// Rejects physically impossible answers: nothing has more energy than pure fat, and
  /// 100 g of food cannot hold more than 100 g of macronutrients.
  static bool _plausible(NutritionValues per100g) =>
      per100g.calories > 0 &&
      per100g.calories <= 950 &&
      per100g.protein + per100g.carbohydrates + per100g.fat <= 105;

  static String _foodId(String name) =>
      aiFoodIdPrefix + name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  static String _mimeType(Uint8List bytes) {
    if (bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50) return 'image/png';
    if (bytes.length > 11 && bytes[0] == 0x52 && bytes[8] == 0x57) return 'image/webp';
    if (bytes.length > 11 && bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79) return 'image/heic';
    return 'image/jpeg';
  }
}
