import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/nutrition.dart';

/// A packaged product found by its barcode in Open Food Facts.
class BarcodeProduct {
  const BarcodeProduct({
    required this.code,
    required this.nameEn,
    required this.nameAr,
    required this.per100g,
    this.servingG,
  });

  final String code;
  final String nameEn;
  final String nameAr;

  /// Values per 100 g or ml, from the pack; anything the pack does not give reads Unknown.
  final NutritionValues per100g;

  /// The pack's serving in grams, if it gives one.
  final double? servingG;
}

/// Looks products up in Open Food Facts, the free public food database. No account is used.
class OpenFoodFactsService {
  OpenFoodFactsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _fields = 'product_name,product_name_en,product_name_ar,brands,serving_quantity,nutriments';

  /// Null when the product is unknown, has no calories, or the lookup fails.
  Future<BarcodeProduct?> lookup(String code) async {
    final digits = code.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 6) return null;
    try {
      final response = await _client.get(
        Uri.parse('https://world.openfoodfacts.org/api/v2/product/$digits.json?fields=$_fields'),
        headers: {'User-Agent': 'Miqdar/1.0 (student project, smart kitchen scale)'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic> || body['status'] != 1) return null;
      final product = body['product'];
      if (product is! Map<String, dynamic>) return null;
      return _parse(digits, product);
    } catch (_) {
      return null;
    }
  }

  static BarcodeProduct? _parse(String code, Map<String, dynamic> product) {
    final n = product['nutriments'];
    if (n is! Map<String, dynamic>) return null;
    double? read(String key) {
      final v = n[key];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final kcal = read('energy-kcal_100g') ?? (read('energy_100g') == null ? null : read('energy_100g')! / 4.184);
    if (kcal == null || kcal <= 0) return null;
    final sodiumG = read('sodium_100g') ?? (read('salt_100g') == null ? null : read('salt_100g')! / 2.5);
    final potassiumG = read('potassium_100g');
    final added = read('added-sugars_100g');
    final values = <String, dynamic>{
      'calories_kcal': kcal,
      'protein_g': read('proteins_100g'),
      'carbohydrate_g': read('carbohydrates_100g'),
      'fat_g': read('fat_100g'),
      'sugar_g': read('sugars_100g'),
      'fiber_g': read('fiber_100g'),
      'sodium_mg': sodiumG == null ? null : sodiumG * 1000,
      'potassium_mg': potassiumG == null ? null : potassiumG * 1000,
      if (added != null) 'free_sugar_g': added,
    };
    String text(String key) => (product[key] as String? ?? '').trim();
    final nameEn = [text('product_name_en'), text('product_name')].firstWhere((s) => s.isNotEmpty, orElse: () => '');
    final brand = text('brands').split(',').first.trim();
    final name = nameEn.isEmpty ? (brand.isEmpty ? 'Packaged food' : brand) : nameEn;
    final serving = product['serving_quantity'];
    final servingG = serving is num ? serving.toDouble() : (serving is String ? double.tryParse(serving) : null);
    return BarcodeProduct(
      code: code,
      nameEn: name,
      nameAr: text('product_name_ar'),
      per100g: NutritionValues.fromJson(values),
      servingG: servingG != null && servingG > 0 ? servingG : null,
    );
  }
}
