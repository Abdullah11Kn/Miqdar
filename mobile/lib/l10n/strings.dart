import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Normalizes Arabic-Indic (`٠-٩`) and Eastern Arabic-Indic (`۰-۹`) digits
/// into standard Western ASCII digits (`0-9`), and converts Arabic decimal
/// separators (`٫` or `,`) to `.` so numeric parsing works in both locales.
String normalizeDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(0x30 + (rune - 0x0660));
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(0x30 + (rune - 0x06F0));
    } else if (rune == 0x066B || rune == 0x002C) {
      buffer.write('.');
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// Bilingual strings helper for Miqdar V3 (English & Arabic).
class S {
  const S(this.isAr);
  final bool isAr;

  static S of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return S(locale?.languageCode == 'ar');
  }

  String tr(String en, String ar) => isAr ? ar : en;

  /// Formats a date in the app's language, e.g. `date(day, 'EEE, d MMM')`.
  String date(DateTime value, String pattern) {
    try {
      final text = DateFormat(pattern, isAr ? 'ar' : 'en').format(value);
      return isAr ? text.replaceAll(',', '،') : text;
    } catch (_) {
      return DateFormat(pattern).format(value); // date data not loaded, as in unit tests
    }
  }

  // Brand & Core
  String get appNameDual => isAr ? 'مقدار • Miqdar' : 'Miqdar • مقدار';
  String get tagline => isAr
      ? 'زِن طعامك، صوّره، واعرف ما تأكله'
      : 'Weigh it. Snap it. Know what you ate.';
  String get demoBanner => isAr
      ? 'عرض تجريبي ببيانات نموذجية. لن يُحفظ شيء هنا.'
      : 'Demo with sample data. Nothing here is saved.';

  // Navigation
  String get navHome => isAr ? 'الرئيسية' : 'Home';
  String get navDiary => isAr ? 'السجل' : 'Diary';
  String get navAdd => isAr ? 'إضافة وجبة' : 'Add Meal';
  String get navInsights => isAr ? 'التحليلات' : 'Insights';
  String get navProfile => isAr ? 'حسابي' : 'Profile';
  String get navNotices => isAr ? 'التنبيهات' : 'Notices';
  String get navDevices => isAr ? 'الميزان' : 'Scale';

  // Welcome & Auth
  String get exploreDemo => isAr ? 'جرّب ببيانات نموذجية' : 'Try with Sample Data';

  // Home Dashboard
  String get greetingMorning => isAr ? 'صباح الخير،' : 'Good morning,';
  String get greetingAfternoon => isAr ? 'مساء الخير،' : 'Good afternoon,';
  String get greetingEvening => isAr ? 'مساء النور،' : 'Good evening,';
  String get dailyIntakeTitle => isAr ? 'تغذية اليوم' : 'Nutrition';
  String get startCapture => isAr ? 'إضافة وجبة' : 'Add Meal';
  String get searchFoodBtn => isAr ? 'بحث غذائي' : 'Search Food';
  String get customFoodBtn => isAr ? 'إدخال يدوي' : 'Enter by Hand';
  String get mealIdeasTitle => isAr ? 'أفكار للوجبات' : 'Meal Ideas';
  String get recentMealsTitle => isAr ? 'وجبات اليوم' : "Today's Meals";
  String get seeAll => isAr ? 'عرض الكل' : 'See all';
  String get noMealsToday => isAr
      ? 'لم تسجل شيئاً بعد.'
      : 'Nothing logged yet.';

  // Nutrients
  String get calories => isAr ? 'السعرات' : 'Calories';
  String get protein => isAr ? 'البروتين' : 'Protein';
  String get carbs => isAr ? 'الكربوهيدرات' : 'Carbs';
  String get fat => isAr ? 'الدهون' : 'Fat';
  String get sugar => isAr ? 'السكريات' : 'Sugar';
  String get fiber => isAr ? 'الألياف' : 'Fiber';
  String get sodium => isAr ? 'الصوديوم' : 'Sodium';
  String get potassium => isAr ? 'البوتاسيوم' : 'Potassium';

  String get unitKcal => isAr ? 'سعرة' : 'kcal';
  String get unitG => isAr ? 'غ' : 'g';
  String get unitMg => isAr ? 'ملغ' : 'mg';

  String nutrientLabel(String key) => switch (key) {
        'calories_kcal' || 'calories' => calories,
        'protein_g' || 'protein' => protein,
        'carbohydrate_g' || 'carbohydrates' || 'carbs' => carbs,
        'fat_g' || 'fat' => fat,
        'sugar_g' || 'sugar' => sugar,
        'fiber_g' || 'fiber' => fiber,
        'sodium_mg' || 'sodium' => sodium,
        'potassium_mg' || 'potassium' => potassium,
        _ => key,
      };

  String mealTypeLabel(String type) => switch (type) {
        'Breakfast' => isAr ? 'الإفطار' : 'Breakfast',
        'Lunch' => isAr ? 'الغداء' : 'Lunch',
        'Dinner' => isAr ? 'العشاء' : 'Dinner',
        'Snack' => isAr ? 'وجبة خفيفة' : 'Snack',
        _ => isAr ? 'وجبة' : 'Meal',
      };

  // Capture & Scale
  String get tareScale => isAr ? 'تصفير الميزان' : 'Zero the Scale';
  String get recognizingFood => isAr ? 'جارٍ تحليل الصورة ومطابقة الغذاء…' : 'Analyzing photo & matching nutrition…';

  // Review & Provenance
  String get verifiedOfficialRecord => isAr
      ? 'من قاعدة بيانات غذائية رسمية'
      : 'From an official food database';
  String get referenceSeedRecord => isAr
      ? 'قيم تقريبية من قائمة الأطعمة'
      : 'Typical values from the food list';
  String get aiEstimateRecord => isAr ? 'تقدير من Gemini' : 'Estimated by Gemini';
  String get userEnteredRecord => isAr ? 'أدخلته بنفسك' : 'Entered by you';
  String get offlineDemoRecord => isAr ? 'بيانات تجريبية' : 'Demo data';
  String get saveMealToDiary => isAr ? 'حفظ في السجل' : 'Save to Diary';
}
