import 'package:flutter/material.dart';

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

  // Brand & Core
  String get appName => isAr ? 'مقدار' : 'Miqdar';
  String get appNameDual => isAr ? 'مقدار • Miqdar' : 'Miqdar • مقدار';
  String get tagline => isAr
      ? 'قياس دقيق للوزن • تعرّف ذكي • تغذية موثوقة'
      : 'Precision Weight • AI Recognition • Traceable Nutrition';
  String get demoBanner => isAr
      ? 'وضع العرض التجريبي — بيانات وعينات توضيحية'
      : 'Demo Workspace — Sample Data & Hardware Simulation';

  // Navigation
  String get navHome => isAr ? 'الرئيسية' : 'Home';
  String get navDiary => isAr ? 'السجل' : 'Diary';
  String get navAdd => isAr ? 'إضافة وجبة' : 'Add Meal';
  String get navInsights => isAr ? 'التحليلات' : 'Insights';
  String get navProfile => isAr ? 'حسابي' : 'Profile';
  String get navNotices => isAr ? 'التنبيهات' : 'Notices';
  String get navDevices => isAr ? 'الميزان' : 'Scale';

  // Welcome & Auth
  String get welcomeTitle => isAr
      ? 'تتبّع تغذيتك بدقة الميزان وذكاء الكاميرا'
      : 'Track nutrition with scale precision & AI vision';
  String get welcomeSubtitle => isAr
      ? 'زِن وجبتك، التقط صورة أو ابحث في الدليل الغذائي، وراجع القيم الغذائية الموثقة قبل الحفظ.'
      : 'Weigh your portion, snap a photo or search the catalog, and review traceable nutrient estimates before saving.';
  String get signIn => isAr ? 'تسجيل الدخول' : 'Sign In';
  String get createAccount => isAr ? 'إنشاء حساب جديد' : 'Create Account';
  String get exploreDemo => isAr ? 'استكشاف العرض التجريبي' : 'Explore Demo Workspace';
  String get emailLabel => isAr ? 'البريد الإلكتروني' : 'Email address';
  String get passwordLabel => isAr ? 'كلمة المرور' : 'Password';
  String get fullNameLabel => isAr ? 'الاسم الكامل' : 'Display name';
  String get forgotPassword => isAr ? 'نسيت كلمة المرور؟' : 'Forgot password?';
  String get resetPasswordTitle => isAr ? 'استعادة كلمة المرور' : 'Password Recovery';
  String get resetPasswordDesc => isAr
      ? 'أدخل بريدك الإلكتروني وسنرسل رابط إعادة تعيين كلمة المرور إذا كان الحساب مسجلاً.'
      : 'Enter your email address. If an account exists, we will send a secure password reset link.';
  String get sendResetLink => isAr ? 'إرسال رابط الاستعادة' : 'Send Reset Link';
  String get continueWithoutScale => isAr
      ? 'يمكنك استخدام التطبيق كاملاً بالبحث والإدخال اليدوي بدون ميزان.'
      : 'Full search and manual portion logging work anytime without a scale.';

  // Home Dashboard
  String get greetingMorning => isAr ? 'صباح الخير،' : 'Good morning,';
  String get greetingAfternoon => isAr ? 'مساء الخير،' : 'Good afternoon,';
  String get greetingEvening => isAr ? 'مساء النور،' : 'Good evening,';
  String get dailyIntakeTitle => isAr ? 'ملخص التغذية اليومي' : 'Daily Nutrition Summary';
  String get caloriesRemaining => isAr ? 'متبقي من الهدف' : 'Remaining of target';
  String get caloriesAboveTarget => isAr ? 'أعلى من الهدف المحدد' : 'Above configured target';
  String get caloriesTracked => isAr ? 'سعرة مسجلة اليوم' : 'kcal recorded today';
  String get quickCaptureTitle => isAr ? 'جاهز لتسجيل وجبتك؟' : 'Ready to log a meal?';
  String get quickCaptureSubtitle => isAr
      ? 'ضع الطبق على الميزان والتقط صورة، أو ابحث في قاعدة البيانات.'
      : 'Place food on the scale and capture a photo, or search verified records.';
  String get startCapture => isAr ? 'مسح وتوزين وجبة' : 'Weigh & Scan Meal';
  String get searchFoodBtn => isAr ? 'بحث غذائي' : 'Search Food';
  String get customFoodBtn => isAr ? 'إدخال مخصص' : 'Custom Entry';
  String get mealIdeasTitle => isAr ? 'اقتراحات وجبات ذكية' : 'Smart Meal Ideas';
  String get recentMealsTitle => isAr ? 'وجبات اليوم والسجل الأخير' : 'Today & Recent Meals';
  String get seeAll => isAr ? 'عرض الكل' : 'See all';
  String get noMealsToday => isAr
      ? 'لم يتم تسجيل وجبات لهذا اليوم بعد. ابدأ بمسح وجبة أو البحث.'
      : 'No meals logged for this date yet. Start by scanning or searching.';

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
  String get tabCameraScale => isAr ? 'كاميرا + ميزان' : 'Camera + Scale';
  String get tabSearchCatalog => isAr ? 'دليل الأطعمة' : 'Food Catalog';
  String get tabCustomEntry => isAr ? 'طعام مخصص' : 'Custom Food';
  String get scaleLiveReading => isAr ? 'قراءة الميزان المباشرة' : 'Live Scale Reading';
  String get manualPortionEntry => isAr ? 'وزن يدوي بالجرام' : 'Manual Portion Weight';
  String get tareScale => isAr ? 'تصفير الميزان (Tare)' : 'Zero / Tare Scale';
  String get lockWeight => isAr ? 'تثبيت الوزن' : 'Lock Weight';
  String get unlockWeight => isAr ? 'تحديث الوزن' : 'Unlock Weight';
  String get stableReading => isAr ? 'قراءة مستقرة' : 'Stable Reading';
  String get weightLocked => isAr ? 'تم تثبيت القراءة' : 'Snapshot Locked';
  String get recognizeFood => isAr ? 'تحليل وتعرّف بالذكاء الاصطناعي' : 'Identify Food with AI';
  String get recognizingFood => isAr ? 'جارٍ تحليل الصورة ومطابقة الغذاء…' : 'Analyzing photo & matching nutrition…';

  // Review & Provenance
  String get reviewBeforeSaving => isAr ? 'مراجعة الوجبة قبل الحفظ' : 'Review Meal Before Saving';
  String get suggestedMatchConfirm => isAr
      ? 'تطابق مقترح — يرجى التأكيد أو التعديل قبل الحفظ'
      : 'Suggested match — please confirm or adjust before saving';
  String get verifiedOfficialRecord => isAr
      ? 'سجل غذائي رسمي موثّق (USDA / SFDA)'
      : 'Verified Official Record (USDA / SFDA)';
  String get referenceSeedRecord => isAr
      ? 'سجل مرجعي معياري — قيم تقديرية لكل 100 غ'
      : 'Reference Seed Record — Estimated per 100 g';
  String get aiEstimateRecord => isAr
      ? 'تقدير من Gemini AI — ليس سجلاً غذائياً موثقاً'
      : 'Gemini AI Estimate — Not a Verified Record';
  String get userEnteredRecord => isAr
      ? 'قيمة مدخلة يدوياً من المستخدم'
      : 'User-Entered Custom Nutrition Record';
  String get offlineDemoRecord => isAr
      ? 'بيانات عرض تجريبي (غير متصل بالخادم)'
      : 'Offline Demonstration Record';
  String get saveMealToDiary => isAr ? 'تأكيد وحفظ الوجبة في السجل' : 'Confirm & Save Meal to Diary';
}
