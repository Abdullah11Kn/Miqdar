import 'dart:convert';

import '../l10n/strings.dart';
import '../models/diabetes.dart';
import '../models/doctor_report.dart';
import '../models/nutrition.dart';

const _mealOrder = ['Breakfast', 'Lunch', 'Dinner', 'Iftar', 'Suhoor', 'Snack', 'Meal'];

String _esc(String text) => const HtmlEscape().convert(text);

/// The doctor's report as one HTML page, which the phone's own web engine turns into a PDF. This
/// keeps Arabic shaping correct and lets Thmanyah be embedded as the app embeds it.
String doctorReportHtml(DoctorReport r, S s, {String? fontRegular, String? fontBold}) {
  final b = StringBuffer();
  String n0(double v) => v.toStringAsFixed(0);
  final unknown = s.tr('Unknown', 'غير معروف');
  // A value missing from any meal is unknown for that day, never shown as 0.
  String known(NutritionValues v, String key, double value, [String unit = '']) =>
      v.isMissing(key) ? unknown : '${n0(value)}${unit.isEmpty ? '' : ' $unit'}';
  String n1(double v) => v.toStringAsFixed(1);
  String day(DateTime d) => s.date(d, 'EEE d MMM');
  final range = '${s.date(r.from, 'd MMM yyyy')} – ${s.date(r.to, 'd MMM yyyy')}';

  b.write('<!doctype html><html lang="${s.isAr ? 'ar' : 'en'}" dir="${s.isAr ? 'rtl' : 'ltr'}"><head><meta charset="utf-8"><style>');
  if (fontRegular != null) {
    b.write("@font-face{font-family:'Thmanyah';font-weight:400;src:url(data:font/otf;base64,$fontRegular) format('opentype');}");
  }
  if (fontBold != null) {
    b.write("@font-face{font-family:'Thmanyah';font-weight:700;src:url(data:font/otf;base64,$fontBold) format('opentype');}");
  }
  b.write('''
@page{size:A4;margin:16mm 14mm}
body{font-family:'Thmanyah',-apple-system,'Helvetica Neue',Arial,sans-serif;color:#111;font-size:11pt;line-height:1.45}
h1{font-size:20pt;margin:0 0 2px}
h2{font-size:13pt;margin:20px 0 6px;border-bottom:1.5px solid #111;padding-bottom:3px}
.muted{color:#555}.small{font-size:9pt}
table{width:100%;border-collapse:collapse;margin-top:4px}
th,td{padding:4px 6px;border-bottom:1px solid #ddd;text-align:start;font-variant-numeric:tabular-nums}
th{font-weight:700;background:#f2f2f2}
td.num,th.num{text-align:end}
.grid{display:flex;gap:10px;flex-wrap:wrap}
.tile{border:1px solid #ccc;border-radius:8px;padding:6px 10px;min-width:96px}
.tile b{display:block;font-size:14pt}
ul{margin:4px 0;padding-inline-start:18px}
tr{page-break-inside:avoid}
</style></head><body>''');

  b.write('<h1>${s.tr('Food and nutrition report', 'تقرير الطعام والتغذية')}</h1>');
  b.write('<div class="muted">');
  if (r.name.trim().isNotEmpty) b.write('${_esc(r.name.trim())} · ');
  b.write('$range · ${s.tr('${r.days.length} days', '${r.days.length} يوماً')}</div>');
  b.write('<p class="small muted">${s.tr(
    'Made on the phone with Miqdar from the meals this person logged. Food values are estimates, from food photos analysed by Gemini or entered by hand; weights marked as weighed come from the Miqdar kitchen scale. This report is not a diagnosis.',
    'أُعدّ على الهاتف بتطبيق مقدار من الوجبات التي سجلها هذا الشخص. القيم الغذائية تقديرية، من صور طعام حللها Gemini أو أُدخلت يدوياً، والأوزان الموسومة بأنها موزونة من ميزان مقدار. هذا التقرير ليس تشخيصاً.',
  )}</p>');
  b.write('<p class="small">${s.tr(
    '${r.mealCount} meals: ${r.weighedMeals} weighed on the scale, ${r.estimatedMeals} with an estimated amount, ${r.enteredMeals} entered by hand.',
    '${r.mealCount} وجبة: ${r.weighedMeals} موزونة بالميزان، و${r.estimatedMeals} بكمية تقديرية، و${r.enteredMeals} أُدخلت يدوياً.',
  )}${r.leftoverMeals > 0 ? ' ${s.tr('Leftovers were weighed and taken off in ${r.leftoverMeals} ${r.leftoverMeals == 1 ? 'meal' : 'meals'}.', 'وُزن المتبقي وخُصم في ${r.leftoverMeals} وجبة.')}' : ''}</p>');

  void carbs() {
    b.write('<h2>${s.tr('Carbs by meal', 'الكربوهيدرات حسب الوجبة')}</h2>');
    final types = [..._mealOrder.where(r.carbsByMeal.containsKey), ...r.carbsByMeal.keys.where((t) => !_mealOrder.contains(t))];
    if (types.isEmpty) {
      b.write('<p class="muted">${s.tr('No carbs recorded.', 'لا توجد كربوهيدرات مسجلة.')}</p>');
      return;
    }
    b.write('<table><tr><th>${s.tr('Meal', 'الوجبة')}</th><th class="num">${s.tr('Average carbs', 'متوسط الكربوهيدرات')}</th><th class="num">${s.tr('Portions of 15 g', 'حصص 15 غ')}</th></tr>');
    for (final t in types) {
      final g = r.carbsByMeal[t]!;
      b.write('<tr><td>${_esc(s.mealTypeLabel(t))}</td><td class="num">${n0(g)} ${s.unitG}</td><td class="num">${formatPortions(carbPortions(g))}</td></tr>');
    }
    b.write('</table><p class="small muted">${s.tr('Average for each meal on the days it was logged. Total carbohydrate.', 'متوسط كل وجبة في الأيام التي سُجلت فيها. إجمالي الكربوهيدرات.')}</p>');
  }

  void overview() {
    final a = r.dailyAverage;
    b.write('<h2>${s.tr('Overview', 'نظرة عامة')}</h2><div class="grid">');
    void tile(String label, String value) => b.write('<div class="tile"><span class="small muted">$label</span><b>$value</b></div>');
    tile(s.tr('Days logged', 'الأيام المسجلة'), '${r.loggedDays} / ${r.days.length}');
    tile(s.tr('Calories a day', 'السعرات في اليوم'), known(a, 'calories_kcal', a.calories, s.unitKcal));
    tile(s.tr('Carbs a day', 'الكربوهيدرات في اليوم'), known(a, 'carbohydrate_g', a.carbohydrates, s.unitG));
    tile(s.tr('Sugar a day', 'السكر في اليوم'), known(a, 'sugar_g', a.sugar, s.unitG));
    tile(s.tr('Salt (sodium) a day', 'الملح (الصوديوم) في اليوم'), known(a, 'sodium_mg', a.sodium, s.unitMg));
    tile(s.tr('Protein a day', 'البروتين في اليوم'), known(a, 'protein_g', a.protein, s.unitG));
    b.write('</div><p class="small muted">${s.tr('Averages over logged days only.', 'المتوسطات على الأيام المسجلة فقط.')}</p>');
  }

  if (r.carbsFirst) carbs();
  overview();
  if (!r.carbsFirst) carbs();

  if (r.goalDays.isNotEmpty) {
    b.write('<h2>${s.tr('Days within goals', 'الأيام ضمن الأهداف')}</h2><table><tr><th>${s.tr('Goal', 'الهدف')}</th><th class="num">${s.tr('Within', 'ضمن')}</th><th class="num">${s.tr('Over', 'أعلى')}</th><th class="num">${s.tr('Under', 'أقل')}</th></tr>');
    for (final g in r.goalDays) {
      final (name, unit) = switch (g.goal) {
        ReportGoal.calories => (s.calories, s.unitKcal),
        ReportGoal.protein => (s.protein, s.unitG),
        ReportGoal.carbohydrates => (s.carbs, s.unitG),
        ReportGoal.fat => (s.fat, s.unitG),
        ReportGoal.fiber => (s.fiber, s.unitG),
        ReportGoal.sugar => (s.sugar, s.unitG),
        ReportGoal.sodium => (s.sodium, s.unitMg),
      };
      final label = g.goal.isLimit
          ? '$name (${s.tr('up to', 'حتى')} ${n0(g.target)} $unit)'
          : '$name (${n0(g.target)} $unit)';
      b.write('<tr><td>$label</td><td class="num">${g.within}</td><td class="num">${g.over}</td><td class="num">${g.goal.isLimit ? '–' : g.under}</td></tr>');
    }
    b.write('</table><p class="small muted">${s.tr('Within means within 10% of the goal. Sugar and salt are limits.', 'ضمن تعني في حدود 10% من الهدف. السكر والملح حدود عليا.')}</p>');
  }

  if (r.patterns.isNotEmpty) {
    b.write('<h2>${s.tr('Patterns', 'أنماط')}</h2><ul>');
    for (final p in r.patterns) {
      final line = switch (p.kind) {
        ReportPatternKind.loggedDays => s.tr('Meals were logged on ${p.count} of ${p.ofDays} days.', 'سُجلت وجبات في ${p.count} من ${p.ofDays} يوماً.'),
        ReportPatternKind.highestCarbMeal => s.tr(
            '${s.mealTypeLabel(p.mealType!)} was the highest-carb meal on ${p.count} of ${p.ofDays} days with more than one meal.',
            '${s.mealTypeLabel(p.mealType!)}: الأعلى كربوهيدرات في ${p.count} من ${p.ofDays} يوماً فيها أكثر من وجبة.'),
        ReportPatternKind.daysOverSugar => s.tr('Sugar was over the goal on ${p.count} of ${p.ofDays} logged days.', 'تجاوز السكر الهدف في ${p.count} من ${p.ofDays} يوماً مسجلاً.'),
        ReportPatternKind.daysOverSalt => s.tr('Salt was over the goal on ${p.count} of ${p.ofDays} logged days.', 'تجاوز الملح الهدف في ${p.count} من ${p.ofDays} يوماً مسجلاً.'),
        ReportPatternKind.weekendCalories => p.percent > 0
            ? s.tr('Calories on Fridays and Saturdays averaged ${p.percent}% higher than on other days.', 'كانت السعرات يومي الجمعة والسبت أعلى بمتوسط ${p.percent}% من بقية الأيام.')
            : s.tr('Calories on Fridays and Saturdays averaged ${-p.percent}% lower than on other days.', 'كانت السعرات يومي الجمعة والسبت أقل بمتوسط ${-p.percent}% من بقية الأيام.'),
      };
      b.write('<li>${_esc(line)}</li>');
    }
    b.write('</ul>');
  }

  if (r.weightStart != null) {
    b.write('<h2>${s.tr('Body weight', 'وزن الجسم')}</h2><p>');
    final start = r.weightStart!;
    final end = r.weightEnd;
    if (end == null) {
      b.write(s.tr('${n1(start.weightKg)} kg on ${day(start.measuredOn)}.', '${n1(start.weightKg)} كغ في ${day(start.measuredOn)}.'));
    } else {
      final change = end.weightKg - start.weightKg;
      final sign = change > 0 ? '+' : '';
      b.write(s.tr(
        '${n1(start.weightKg)} kg on ${day(start.measuredOn)} to ${n1(end.weightKg)} kg on ${day(end.measuredOn)} ($sign${n1(change)} kg).',
        'من ${n1(start.weightKg)} كغ في ${day(start.measuredOn)} إلى ${n1(end.weightKg)} كغ في ${day(end.measuredOn)} ($sign${n1(change)} كغ).',
      ));
    }
    b.write('</p>');
  }

  if (r.readings.isNotEmpty) {
    // As typed or read from Apple Health, beside the meal they belong to. No averages or ranges.
    b.write('<h2>${s.tr('Blood sugar readings', 'قراءات سكر الدم')}</h2><table><tr>'
        '<th>${s.tr('When', 'الوقت')}</th><th class="num">${s.tr('Reading', 'القراءة')}</th>'
        '<th>${s.tr('Timing', 'التوقيت')}</th><th>${s.tr('Meal', 'الوجبة')}</th>'
        '<th class="num">${s.tr('Meal carbs', 'كربوهيدرات الوجبة')}</th></tr>');
    for (final reading in r.readings) {
      b.write('<tr><td>${_esc(s.date(reading.at.toLocal(), 'EEE d MMM, HH:mm'))}</td>'
          '<td class="num">${n0(reading.mgdl)} ${s.tr('mg/dL', 'ملغ/دسل')} (${(reading.mgdl / 18).toStringAsFixed(1)} ${s.tr('mmol/L', 'مليمول/لتر')})</td>'
          '<td>${_esc(reading.tag.label(s.isAr))}</td>'
          '<td>${_esc(reading.mealName ?? '—')}</td>'
          '<td class="num">${reading.mealCarbsG == null ? '—' : '${n0(reading.mealCarbsG!)} ${s.unitG}'}</td></tr>');
    }
    b.write('</table><p class="small muted">${s.tr('As entered by the user. Miqdar does not interpret readings.', 'كما أدخلها المستخدم. لا يفسّر مقدار القراءات.')}</p>');
  }

  b.write('<h2>${s.tr('Daily totals', 'المجاميع اليومية')}</h2><table><tr>'
      '<th>${s.tr('Day', 'اليوم')}</th><th class="num">${s.tr('Meals', 'الوجبات')}</th>'
      '<th class="num">${s.calories} (${s.unitKcal})</th><th class="num">${s.carbs} (${s.unitG})</th>'
      '<th class="num">${s.sugar} (${s.unitG})</th><th class="num">${s.sodium} (${s.unitMg})</th>'
      '<th class="num">${s.protein} (${s.unitG})</th></tr>');
  for (final d in r.days) {
    final t = d.totals;
    if (t == null) {
      b.write('<tr><td>${day(d.day)}</td><td class="num muted" colspan="6">${s.tr('Not logged', 'غير مسجل')}</td></tr>');
    } else {
      b.write('<tr><td>${day(d.day)}</td><td class="num">${d.meals}</td><td class="num">${known(t, 'calories_kcal', t.calories)}</td>'
          '<td class="num">${known(t, 'carbohydrate_g', t.carbohydrates)}</td><td class="num">${known(t, 'sugar_g', t.sugar)}</td>'
          '<td class="num">${known(t, 'sodium_mg', t.sodium)}</td><td class="num">${known(t, 'protein_g', t.protein)}</td></tr>');
    }
  }
  b.write('</table>');
  b.write('<p class="small muted">${s.tr('Made on ${s.date(DateTime.now(), 'd MMM yyyy')}.', 'أُعدّ في ${s.date(DateTime.now(), 'd MMM yyyy')}.')}</p>');
  b.write('</body></html>');
  return b.toString();
}
