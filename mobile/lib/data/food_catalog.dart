import '../l10n/strings.dart';
import '../models/nutrition.dart';

/// Complete bilingual catalog of the 38 Miqdar database foods (from `database/seed/foods.csv`)
/// with verified serving conversions, preparation states, and aliases.
class MiqdarFoodCatalog {
  static NutritionValues _n(
    double kcal,
    double p,
    double c,
    double f,
    double s,
    double fib,
    double na,
    double k,
  ) =>
      NutritionValues(
        calories: kcal,
        protein: p,
        carbohydrates: c,
        fat: f,
        sugar: s,
        fiber: fib,
        sodium: na,
        potassium: k,
      );

  static final List<FoodCatalogItem> builtInFoods = [
    FoodCatalogItem(
      foodId: 'food_dates_medjool',
      nameEn: 'Dates - Medjool',
      nameAr: 'تمر مجدول',
      category: 'Fruit',
      preparation: 'Raw, pitted',
      verificationStatus: 'verified_official_record',
      sourceId: 'USDA_FDC',
      sourceRecordId: '168191',
      sourceUrl: 'https://fdc.nal.usda.gov/',
      notes: 'USDA SR Legacy official record; values per 100 g.',
      per100g: _n(277, 1.81, 74.97, 0.15, 66.47, 6.7, 1, 696),
      aliases: ['medjool dates', 'date', 'dates', 'تمر', 'تمر مجدول'],
      servings: const [
        ServingOption(id: 'date_1', labelEn: '1 Medjool date', labelAr: 'حبة تمر مجدول', grams: 24),
        ServingOption(id: 'date_3', labelEn: '3 Medjool dates', labelAr: '3 حبات تمر مجدول', grams: 72),
        ServingOption(id: 'g_100', labelEn: '100 g reference', labelAr: '100 غرام مرجعي', grams: 100),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_dates_ajwa',
      nameEn: 'Dates - Ajwa',
      nameAr: 'تمر عجوة',
      category: 'Fruit',
      preparation: 'Raw',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      notes: 'Traditional Madinah Ajwa dates reference composition per 100 g.',
      per100g: _n(282, 2.45, 75.03, 0.39, 63.35, 8.0, 2, 656),
      aliases: ['ajwa', 'ajwa dates', 'عجوة', 'تمر عجوة'],
      servings: const [
        ServingOption(id: 'ajwa_3', labelEn: '3 Ajwa dates', labelAr: '3 تمرات عجوة', grams: 30),
        ServingOption(id: 'ajwa_7', labelEn: '7 Ajwa dates', labelAr: '7 تمرات عجوة', grams: 70),
        ServingOption(id: 'g_100', labelEn: '100 g reference', labelAr: '100 غرام مرجعي', grams: 100),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_dates_sukari',
      nameEn: 'Sukari Dates',
      nameAr: 'تمر سكري',
      category: 'Fruit',
      preparation: 'Raw',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      notes: 'Reference Qassim Sukari date variety composition per 100 g.',
      per100g: _n(280, 2.1, 75.0, 0.2, 68.0, 7.0, 2, 650),
      aliases: ['sukari', 'sukkari', 'sukari dates', 'سكري', 'تمر سكري'],
      servings: const [
        ServingOption(id: 'suk_3', labelEn: '3 Sukari dates', labelAr: '3 تمرات سكري', grams: 45),
        ServingOption(id: 'g_100', labelEn: '100 g reference', labelAr: '100 غرام مرجعي', grams: 100),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_chicken_kabsa',
      nameEn: 'Chicken Kabsa',
      nameAr: 'كبسة دجاج',
      category: 'Traditional Dish',
      preparation: 'Cooked spiced rice with roasted chicken',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      notes: 'Traditional Saudi spiced rice with chicken; recipe oils and meat-to-rice ratio vary.',
      per100g: _n(185, 12.5, 21.0, 5.5, 0.5, 1.2, 320, 210),
      aliases: ['kabsa', 'chicken kabsa', 'كبسة', 'كبسة دجاج', 'رز كبسة'],
      servings: const [
        ServingOption(id: 'kabsa_cup', labelEn: '1 cup serving', labelAr: 'كوب تقديم', grams: 200),
        ServingOption(id: 'kabsa_plate', labelEn: '1 medium plate', labelAr: 'طبق متوسط', grams: 320),
        ServingOption(id: 'g_100', labelEn: '100 g reference', labelAr: '100 غرام مرجعي', grams: 100),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_lamb_kabsa',
      nameEn: 'Lamb Kabsa',
      nameAr: 'كبسة لحم',
      category: 'Traditional Dish',
      preparation: 'Cooked spiced rice with tender lamb',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      notes: 'Traditional Saudi spiced rice with lamb.',
      per100g: _n(215, 13.8, 20.5, 8.5, 0.4, 1.1, 340, 230),
      aliases: ['lamb kabsa', 'mutton kabsa', 'كبسة لحم', 'رز كبسة لحم'],
      servings: const [
        ServingOption(id: 'lkabsa_plate', labelEn: '1 medium plate', labelAr: 'طبق متوسط', grams: 320),
        ServingOption(id: 'g_100', labelEn: '100 g reference', labelAr: '100 غرام مرجعي', grams: 100),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_chicken_mandi',
      nameEn: 'Chicken Mandi',
      nameAr: 'مندي دجاج',
      category: 'Traditional Dish',
      preparation: 'Pit-roasted chicken over fragrant basmati rice',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      notes: 'Smoky roasted chicken served over fragrant rice.',
      per100g: _n(175, 13.0, 19.5, 4.8, 0.3, 1.0, 290, 205),
      aliases: ['mandi', 'chicken mandi', 'مندي', 'مندي دجاج'],
      servings: const [
        ServingOption(id: 'mandi_plate', labelEn: '1 medium plate', labelAr: 'طبق متوسط', grams: 300),
        ServingOption(id: 'g_100', labelEn: '100 g reference', labelAr: '100 غرام مرجعي', grams: 100),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_lamb_mandi',
      nameEn: 'Lamb Mandi',
      nameAr: 'مندي لحم',
      category: 'Traditional Dish',
      preparation: 'Pit-cooked lamb over aromatic rice',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(210, 14.2, 19.0, 8.2, 0.3, 0.9, 310, 225),
      aliases: ['lamb mandi', 'مندي لحم'],
      servings: const [
        ServingOption(id: 'lmandi_plate', labelEn: '1 medium plate', labelAr: 'طبق متوسط', grams: 300),
        ServingOption(id: 'g_100', labelEn: '100 g reference', labelAr: '100 غرام مرجعي', grams: 100),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_bukhari_rice',
      nameEn: 'Bukhari Rice',
      nameAr: 'رز بخاري',
      category: 'Traditional Dish',
      preparation: 'Cooked spiced rice with carrots & raisins',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(160, 4.5, 26.0, 4.0, 1.8, 1.8, 280, 160),
      aliases: ['bukhari', 'bukhari rice', 'رز بخاري', 'أرز بخاري', 'بخاري'],
      servings: const [
        ServingOption(id: 'buk_cup', labelEn: '1 cup cooked', labelAr: 'كوب مطبوخ', grams: 195),
        ServingOption(id: 'g_100', labelEn: '100 g reference', labelAr: '100 غرام مرجعي', grams: 100),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_jareesh',
      nameEn: 'Jareesh',
      nameAr: 'جريش',
      category: 'Traditional Dish',
      preparation: 'Crushed wheat simmered with yogurt & broth',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(140, 6.2, 18.0, 4.8, 1.5, 2.8, 310, 180),
      aliases: ['jareesh', 'جريش', 'الجريش'],
      servings: const [
        ServingOption(id: 'jar_bowl', labelEn: '1 medium bowl', labelAr: 'زبدية متوسطة', grams: 240),
        ServingOption(id: 'g_100', labelEn: '100 g reference', labelAr: '100 غرام مرجعي', grams: 100),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_margoog',
      nameEn: 'Margoog',
      nameAr: 'مرقوق',
      category: 'Traditional Dish',
      preparation: 'Whole-wheat dough stewed in vegetable & meat broth',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(135, 7.5, 17.5, 3.8, 2.0, 2.5, 330, 220),
      aliases: ['margoog', 'marqooc', 'مرقوق', 'المرقوق'],
      servings: const [
        ServingOption(id: 'mar_bowl', labelEn: '1 medium bowl', labelAr: 'زبدية متوسطة', grams: 250),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_qursan',
      nameEn: 'Qursan',
      nameAr: 'قرصان',
      category: 'Traditional Dish',
      preparation: 'Thin wheat bread layers soaked in meat & vegetable gravy',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(130, 6.8, 18.5, 3.2, 2.2, 2.7, 320, 210),
      aliases: ['qursan', 'gursan', 'قرصان', 'القرصان'],
      servings: const [
        ServingOption(id: 'qur_bowl', labelEn: '1 medium bowl', labelAr: 'زبدية متوسطة', grams: 240),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_saleeg',
      nameEn: 'Saleeg',
      nameAr: 'سليق',
      category: 'Traditional Dish',
      preparation: 'Creamy milk-simmered rice with roasted chicken',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(155, 8.5, 19.0, 4.5, 2.1, 0.8, 270, 190),
      aliases: ['saleeg', 'sleeg', 'سليق', 'السليق', 'سليق طائفي'],
      servings: const [
        ServingOption(id: 'sal_plate', labelEn: '1 serving plate', labelAr: 'حصة طبق', grams: 250),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_lamb_haneeth',
      nameEn: 'Lamb Haneeth',
      nameAr: 'حنيذ لحم',
      category: 'Traditional Dish',
      preparation: 'Slow-roasted seasoned lamb',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(230, 18.0, 12.0, 12.5, 0.2, 0.5, 350, 240),
      aliases: ['haneeth', 'lamb haneeth', 'حنيذ', 'حنيذ لحم'],
      servings: const [
        ServingOption(id: 'han_portion', labelEn: '1 serving portion', labelAr: 'حصة تقديم', grams: 260),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_areeka_southern',
      nameEn: 'Southern Areeka',
      nameAr: 'عريكة جنوبية',
      category: 'Traditional Dish',
      preparation: 'Whole-wheat mashed dates with honey & ghee',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(265, 4.8, 48.0, 7.2, 28.0, 4.5, 180, 320),
      aliases: ['areeka', 'arika', 'southern areeka', 'عريكة', 'عريكة جنوبية'],
      servings: const [
        ServingOption(id: 'ar_bowl', labelEn: '1 small bowl', labelAr: 'حصة صغيرة', grams: 160),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_masoub',
      nameEn: 'Masoub',
      nameAr: 'معصوب',
      category: 'Traditional Dish',
      preparation: 'Mashed flatbread with ripe bananas, honey & cream',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(240, 5.2, 44.0, 5.8, 24.0, 4.0, 160, 310),
      aliases: ['masoub', 'masoob', 'معصوب', 'معصوب بالموز'],
      servings: const [
        ServingOption(id: 'mas_bowl', labelEn: '1 serving bowl', labelAr: 'علبة متوسطة', grams: 180),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_mutabbaq',
      nameEn: 'Mutabbaq',
      nameAr: 'مطبق',
      category: 'Traditional Dish',
      preparation: 'Pan-fried stuffed pastry with egg, leek & minced meat',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(225, 11.2, 22.0, 10.5, 1.2, 1.6, 390, 175),
      aliases: ['mutabbaq', 'motabbaq', 'مطبق', 'مطبق مالح'],
      servings: const [
        ServingOption(id: 'mut_piece', labelEn: '2 squares', labelAr: 'قطعتين مطبق', grams: 90),
        ServingOption(id: 'mut_plate', labelEn: 'Full plate (6 squares)', labelAr: 'صحن كامل', grams: 240),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_sayadieh',
      nameEn: 'Sayadieh Fish Rice',
      nameAr: 'صيادية سمك',
      category: 'Traditional Dish',
      preparation: 'Caramelized onion spiced rice with fish fillet',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(165, 11.8, 20.0, 4.2, 0.8, 1.1, 295, 230),
      aliases: ['sayadieh', 'fish sayadieh', 'صيادية', 'صيادية سمك'],
      servings: const [
        ServingOption(id: 'say_plate', labelEn: '1 medium plate', labelAr: 'طبق متوسط', grams: 280),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_rice_white_cooked',
      nameEn: 'White rice - cooked',
      nameAr: 'أرز أبيض مطبوخ',
      category: 'Grain',
      preparation: 'Boiled/steamed without added fat',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(130, 2.69, 28.17, 0.28, 0.05, 0.4, 1, 35),
      aliases: ['white rice', 'cooked rice', 'rice', 'basmati rice', 'أرز أبيض', 'رز أبيض', 'أرز', 'رز'],
      servings: const [
        ServingOption(id: 'rice_cup', labelEn: '1 cup cooked', labelAr: 'كوب أرز مطبوخ', grams: 158),
        ServingOption(id: 'rice_plate', labelEn: '1 side plate', labelAr: 'صحن جانبي', grams: 220),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_chicken_breast_roasted',
      nameEn: 'Chicken breast - roasted',
      nameAr: 'صدر دجاج مشوي',
      category: 'Protein',
      preparation: 'Roasted/grilled, skinless',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(165, 31.02, 0, 3.57, 0, 0, 74, 256),
      aliases: ['chicken breast', 'grilled chicken', 'chicken', 'صدر دجاج', 'دجاج مشوي', 'صدر دجاج مشوي'],
      servings: const [
        ServingOption(id: 'chk_fillet', labelEn: '1 medium breast fillet', labelAr: 'قطعة صدر متوسطة', grams: 145),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_salmon_cooked',
      nameEn: 'Salmon - cooked',
      nameAr: 'سلمون مطبوخ',
      category: 'Protein',
      preparation: 'Baked or grilled fillet',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(206, 22.1, 0, 12.35, 0, 0, 59, 384),
      aliases: ['salmon', 'cooked salmon', 'grilled salmon', 'سلمون', 'سلمون مشوي', 'سلمون مطبوخ'],
      servings: const [
        ServingOption(id: 'sal_fillet', labelEn: '1 fillet', labelAr: 'شريحة سلمون', grams: 140),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_egg_boiled',
      nameEn: 'Egg - hard boiled',
      nameAr: 'بيض مسلوق',
      category: 'Protein',
      preparation: 'Hard-boiled, peeled',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(155, 12.58, 1.12, 10.61, 1.12, 0, 124, 126),
      aliases: ['egg', 'boiled egg', 'eggs', 'بيض', 'بيض مسلوق'],
      servings: const [
        ServingOption(id: 'egg_1', labelEn: '1 large egg', labelAr: 'بيضة كبيرة', grams: 50),
        ServingOption(id: 'egg_2', labelEn: '2 large eggs', labelAr: 'بيضتان', grams: 100),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_almonds_raw',
      nameEn: 'Almonds - raw',
      nameAr: 'لوز',
      category: 'Protein',
      preparation: 'Raw, unroasted',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(579, 21.15, 21.55, 49.93, 4.35, 12.5, 1, 733),
      aliases: ['almonds', 'almond', 'raw almonds', 'لوز'],
      servings: const [
        ServingOption(id: 'alm_handful', labelEn: 'Small handful (~23 almonds)', labelAr: 'حفنة صغيرة', grams: 28),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_hummus_prepared',
      nameEn: 'Hummus - prepared',
      nameAr: 'حمص محضر',
      category: 'Legume',
      preparation: 'Prepared chickpea & tahini dip',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(166, 7.9, 14.3, 9.6, 0.3, 6.0, 379, 228),
      aliases: ['hummus', 'hummus dip', 'حمص', 'حمص بالطحينة'],
      servings: const [
        ServingOption(id: 'hum_2tbsp', labelEn: '2 tablespoons', labelAr: 'ملعقتين كبيرتين', grams: 30),
        ServingOption(id: 'hum_bowl', labelEn: '1 small plate', labelAr: 'صحن صغير', grams: 100),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_banana_raw',
      nameEn: 'Banana - raw',
      nameAr: 'موز',
      category: 'Fruit',
      preparation: 'Raw, peeled',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(89, 1.09, 22.84, 0.33, 12.23, 2.6, 1, 358),
      aliases: ['banana', 'fresh banana', 'موز', 'موز طازج'],
      servings: const [
        ServingOption(id: 'ban_med', labelEn: '1 medium banana', labelAr: 'حبة موز متوسطة', grams: 118),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_apple_raw',
      nameEn: 'Apple with skin - raw',
      nameAr: 'تفاح بالقشر',
      category: 'Fruit',
      preparation: 'Raw with skin',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(52, 0.26, 13.81, 0.17, 10.39, 2.4, 1, 107),
      aliases: ['apple', 'fresh apple', 'تفاح', 'تفاح بالقشر'],
      servings: const [
        ServingOption(id: 'app_med', labelEn: '1 medium apple', labelAr: 'تفاحة متوسطة', grams: 182),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_cucumber_raw',
      nameEn: 'Cucumber with peel - raw',
      nameAr: 'خيار بالقشر',
      category: 'Vegetable',
      preparation: 'Raw, sliced with peel',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(15, 0.65, 3.63, 0.11, 1.67, 0.5, 2, 147),
      aliases: ['cucumber', 'fresh cucumber', 'خيار', 'خيار بالقشر'],
      servings: const [
        ServingOption(id: 'cuc_1', labelEn: '1 medium cucumber', labelAr: 'حبة خيار متوسطة', grams: 150),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_tomato_raw',
      nameEn: 'Tomato - raw',
      nameAr: 'طماطم',
      category: 'Vegetable',
      preparation: 'Raw, ripe',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(18, 0.88, 3.89, 0.2, 2.63, 1.2, 5, 237),
      aliases: ['tomato', 'fresh tomato', 'طماطم'],
      servings: const [
        ServingOption(id: 'tom_1', labelEn: '1 medium tomato', labelAr: 'حبة طماطم متوسطة', grams: 123),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_milk_whole',
      nameEn: 'Whole milk',
      nameAr: 'حليب كامل الدسم',
      category: 'Dairy',
      preparation: 'Fluid whole milk (3.25% fat)',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(61, 3.15, 4.8, 3.25, 5.05, 0, 43, 132),
      aliases: ['milk', 'whole milk', 'fresh milk', 'حليب', 'حليب كامل الدسم'],
      servings: const [
        ServingOption(id: 'milk_cup', labelEn: '1 cup (240 ml)', labelAr: 'كوب (240 مل)', grams: 244),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_greek_yogurt',
      nameEn: 'Greek Yogurt',
      nameAr: 'زبادي يوناني',
      category: 'Dairy',
      preparation: 'Strained plain yogurt',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(97, 9.0, 4.0, 5.0, 4.0, 0.0, 45, 140),
      aliases: ['greek yogurt', 'yogurt', 'زبادي', 'زبادي يوناني'],
      servings: const [
        ServingOption(id: 'yog_cup', labelEn: '1 container (170 g)', labelAr: 'علبة زبادي (170 غ)', grams: 170),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_chicken_shawarma',
      nameEn: 'Chicken Shawarma Wrap',
      nameAr: 'شاورما دجاج',
      category: 'Sandwich',
      preparation: 'Roasted marinated chicken in pita with garlic sauce',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(215, 13.5, 21.0, 8.5, 1.5, 1.5, 450, 210),
      aliases: ['shawarma', 'chicken shawarma', 'شاورما', 'شاورما دجاج', 'صاروخ شاورما'],
      servings: const [
        ServingOption(id: 'shw_small', labelEn: '1 regular wrap', labelAr: 'ساندوتش عادي', grams: 160),
        ServingOption(id: 'shw_large', labelEn: '1 large saj wrap', labelAr: 'شاورما صاج كبير', grams: 260),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_beef_shawarma',
      nameEn: 'Beef Shawarma Wrap',
      nameAr: 'شاورما لحم',
      category: 'Sandwich',
      preparation: 'Shaved spiced beef in pita with tahini',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(235, 14.8, 20.0, 10.5, 1.2, 1.4, 480, 230),
      aliases: ['beef shawarma', 'meat shawarma', 'شاورما لحم'],
      servings: const [
        ServingOption(id: 'bshw_reg', labelEn: '1 regular wrap', labelAr: 'ساندوتش عادي', grams: 165),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_falafel_wrap',
      nameEn: 'Falafel Wrap',
      nameAr: 'ساندوتش فلافل',
      category: 'Sandwich',
      preparation: 'Fried chickpea patties in pita with tahini salad',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(220, 7.5, 29.0, 8.8, 2.0, 4.2, 420, 260),
      aliases: ['falafel', 'falafel wrap', 'فلافل', 'ساندوتش فلافل', 'طعمية'],
      servings: const [
        ServingOption(id: 'fal_wrap', labelEn: '1 regular sandwich', labelAr: 'ساندوتش فلافل', grams: 170),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_chicken_burger',
      nameEn: 'Crispy Chicken Burger',
      nameAr: 'برجر دجاج',
      category: 'Fast Food',
      preparation: 'Breaded chicken patty in bun with lettuce & sauce',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(250, 14.0, 24.0, 11.0, 3.2, 1.5, 520, 200),
      aliases: ['chicken burger', 'crispy chicken burger', 'برجر دجاج', 'برغر دجاج'],
      servings: const [
        ServingOption(id: 'cburg_1', labelEn: '1 burger', labelAr: 'ساندوتش برجر', grams: 185),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_beef_burger',
      nameEn: 'Beef Burger',
      nameAr: 'برجر لحم',
      category: 'Fast Food',
      preparation: 'Grilled beef patty in bun with condiments',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(270, 15.5, 23.0, 13.5, 3.5, 1.4, 490, 220),
      aliases: ['burger', 'beef burger', 'hamburger', 'cheeseburger', 'برجر لحم', 'تشيز برجر'],
      servings: const [
        ServingOption(id: 'bburg_1', labelEn: '1 burger', labelAr: 'ساندوتش برجر', grams: 190),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_pizza_pepperoni',
      nameEn: 'Pizza Pepperoni',
      nameAr: 'بيتزا ببروني',
      category: 'Fast Food',
      preparation: 'Oven-baked crust with mozzarella & beef pepperoni',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(275, 11.5, 28.0, 12.8, 2.5, 1.8, 580, 170),
      aliases: ['pepperoni pizza', 'pizza pepperoni', 'بيتزا ببروني', 'بيتزا بيبروني'],
      servings: const [
        ServingOption(id: 'piz_slice', labelEn: '1 large slice', labelAr: 'شريحة كبيرة', grams: 107),
        ServingOption(id: 'piz_2slice', labelEn: '2 large slices', labelAr: 'شريحتان', grams: 214),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_pizza_margherita',
      nameEn: 'Pizza Margherita',
      nameAr: 'بيتزا مارغريتا',
      category: 'Fast Food',
      preparation: 'Oven-baked crust with tomato sauce & mozzarella',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(245, 10.2, 29.5, 9.2, 2.8, 1.9, 460, 180),
      aliases: ['pizza', 'margherita pizza', 'cheese pizza', 'بيتزا', 'بيتزا مارغريتا', 'بيتزا جبن'],
      servings: const [
        ServingOption(id: 'mpiz_slice', labelEn: '1 large slice', labelAr: 'شريحة كبيرة', grams: 105),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_tuna_salad',
      nameEn: 'Tuna Salad',
      nameAr: 'سلطة تونة',
      category: 'Salad',
      preparation: 'Flaked tuna with fresh diced vegetables',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(120, 14.5, 3.5, 5.2, 1.5, 1.2, 340, 210),
      aliases: ['tuna salad', 'سلطة تونة'],
      servings: const [
        ServingOption(id: 'tuna_bowl', labelEn: '1 medium bowl', labelAr: 'طبق سلطة متوسط', grams: 200),
      ],
    ),
    FoodCatalogItem(
      foodId: 'food_garden_salad',
      nameEn: 'Green Garden Salad',
      nameAr: 'سلطة خضراء',
      category: 'Salad',
      preparation: 'Fresh greens, cucumber & tomatoes without heavy dressing',
      verificationStatus: 'reference_seed',
      sourceId: 'DEMO_REFERENCE',
      per100g: _n(25, 1.2, 4.5, 0.3, 2.0, 1.8, 25, 195),
      aliases: ['salad', 'garden salad', 'green salad', 'سلطة', 'سلطة خضراء', 'سلطة خضار'],
      servings: const [
        ServingOption(id: 'sal_bowl', labelEn: '1 side bowl', labelAr: 'طبق سلطة جانبي', grams: 150),
      ],
    ),
  ];

  static FoodCatalogItem? findByIdOrLabel(String query, [List<FoodCatalogItem> custom = const []]) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return null;
    final all = [...custom, ...builtInFoods];
    for (final item in all) {
      if (item.foodId.toLowerCase() == needle ||
          item.nameEn.toLowerCase() == needle ||
          item.nameAr == query.trim() ||
          item.aliases.any((a) => a.toLowerCase() == needle)) {
        return item;
      }
    }
    for (final item in all) {
      if (item.nameEn.toLowerCase().contains(needle) ||
          item.nameAr.contains(needle) ||
          item.aliases.any((a) => a.toLowerCase().contains(needle))) {
        return item;
      }
    }
    return null;
  }

  static List<FoodCatalogItem> search(
    String query, {
    String? category,
    List<FoodCatalogItem> custom = const [],
  }) {
    final normalized = normalizeDigits(query).trim().toLowerCase();
    // Normalize common Arabic hamza/aleph variants for forgiving Arabic search (LOC-07)
    String normAr(String s) => s
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .toLowerCase();
    final needleAr = normAr(normalized);

    final all = [...custom, ...builtInFoods];
    return all.where((item) {
      if (category != null && category != 'All' && item.category != category) {
        return false;
      }
      if (normalized.isEmpty) return true;
      return item.nameEn.toLowerCase().contains(normalized) ||
          normAr(item.nameAr).contains(needleAr) ||
          item.category.toLowerCase().contains(normalized) ||
          item.aliases.any((a) => normAr(a).contains(needleAr));
    }).toList();
  }
}
