import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n/strings.dart';
import '../models/diabetes.dart';
import '../models/glucose.dart';
import '../models/nutrition.dart';
import '../theme.dart';
import 'widgets/charts_and_gauges.dart';

/// The diabetes question. The Body Profile and Food Preferences both show it; it saves at once,
/// to the one setting, so the two never disagree.
class DiabetesQuestion extends StatelessWidget {
  const DiabetesQuestion({super.key, required this.controller});

  final MiqdarController controller;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = controller.diabetes;
    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(text, style: MiqdarType.bodyStrong.copyWith(color: context.mq.ink)),
        );
    Widget chips<T>(List<(T, String)> options, T selected, ValueChanged<T> onSelected) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (value, text) in options)
              ChoiceChip(label: Text(text), selected: selected == value, onSelected: (_) => onSelected(value)),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label(s.tr('Do you have diabetes?', 'هل لديك سكري؟')),
        chips<bool>(
          [(false, s.tr('No', 'لا')), (true, s.tr('Yes', 'نعم'))],
          d.hasDiabetes,
          (v) => controller.updateDiabetes(d.copyWith(hasDiabetes: v)),
        ),
        if (d.hasDiabetes) ...[
          const SizedBox(height: 16),
          label(s.tr('Which type?', 'أي نوع؟')),
          chips<DiabetesType>(
            [
              (DiabetesType.type1, s.tr('Type 1', 'النوع الأول')),
              (DiabetesType.type2, s.tr('Type 2', 'النوع الثاني')),
              (DiabetesType.other, s.tr('Other', 'نوع آخر')),
              (DiabetesType.notSure, s.tr('Not sure', 'لست متأكداً')),
            ],
            d.type,
            (v) => controller.updateDiabetes(d.copyWith(type: v)),
          ),
          const SizedBox(height: 16),
          label(s.tr('Do you take insulin?', 'هل تستخدم الإنسولين؟')),
          chips<bool>(
            [(false, s.tr('No', 'لا')), (true, s.tr('Yes', 'نعم'))],
            d.usesInsulin,
            (v) => controller.updateDiabetes(d.copyWith(usesInsulin: v)),
          ),
          const SizedBox(height: 8),
          Text(
            s.tr(
              'Carbs will come first on your meals, in grams and in carb portions of 15 g. These answers stay on this phone.',
              'ستظهر الكربوهيدرات أولاً في وجباتك، بالغرام وبحصص الكربوهيدرات (15 غ للحصة). تبقى هذه الإجابات على هذا الهاتف.',
            ),
            style: MiqdarType.caption.copyWith(color: context.mq.inkMuted),
          ),
        ],
      ],
    );
  }
}

/// The carb numbers per meal and snack: the suggested starting point, the doctor's numbers, or
/// a note that the care team should set them.
class CarbPlanCard extends StatelessWidget {
  const CarbPlanCard({super.key, required this.controller});

  final MiqdarController controller;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = controller.diabetes;
    if (!d.hasDiabetes) return const SizedBox.shrink();
    final muted = MiqdarType.body.copyWith(color: context.mq.inkMuted);
    final strong = MiqdarType.bodyStrong.copyWith(color: context.mq.ink);
    final suggestion = controller.suggestedCarbPlan;
    final block = controller.carbBlock;
    final applies = controller.carbTargetFor('Lunch') != null;

    final children = <Widget>[
      Text(s.tr('Carbs per meal', 'الكربوهيدرات لكل وجبة'), style: MiqdarType.titleCard.copyWith(color: context.mq.ink)),
      const SizedBox(height: 8),
    ];

    if (applies) {
      final meal = d.mealCarbsG!;
      final snack = d.snackCarbsG ?? meal;
      children.addAll([
        Text(
          s.tr(
            '${meal.toStringAsFixed(0)} g a meal (${formatPortions(carbPortions(meal))} portions) · ${snack.toStringAsFixed(0)} g a snack',
            '${meal.toStringAsFixed(0)} غ للوجبة (${formatPortions(carbPortions(meal))} حصص) · ${snack.toStringAsFixed(0)} غ للوجبة الخفيفة',
          ),
          style: strong,
        ),
        const SizedBox(height: 4),
        Text(
          switch (d.source) {
            CarbPlanSource.doctor => s.tr('From your doctor', 'من طبيبك'),
            CarbPlanSource.chosenAnyway => s.tr(
                "Miqdar's general number, chosen although your care team should set it. Not medical advice.",
                'رقم مقدار العام، اخترته مع أن فريقك الطبي يجب أن يحدده. ليس نصيحة طبية.',
              ),
            _ => s.tr('General starting point, not your personal target', 'نقطة بداية عامة، وليست هدفك الشخصي'),
          },
          style: muted,
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          TextButton(onPressed: () => _enterDoctorNumbers(context), child: Text(s.tr('Change', 'تغيير'))),
          TextButton(onPressed: controller.clearCarbPlan, child: Text(s.tr('Clear', 'مسح'))),
        ]),
      ]);
    } else if (block != null) {
      children.addAll([
        Text(_blockText(s, block), style: muted),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _enterDoctorNumbers(context),
          child: Text(s.tr("Enter My Doctor's Numbers", 'إدخال أرقام طبيبي')),
        ),
        TextButton(
          onPressed: () async {
            final reason = _blockText(s, block).split(',').first;
            if (await confirmMiqdarNumber(context, strongerReason: reason)) await controller.useSuggestedCarbsAnyway();
          },
          child: Text(s.tr("Use Miqdar's Number Anyway", 'استخدام رقم مقدار على أي حال')),
        ),
      ]);
    } else if (d.source == CarbPlanSource.waiting) {
      children.addAll([
        Text(s.tr('Waiting for your doctor. Carbs are still shown on every meal.',
            'بانتظار طبيبك. ما زالت الكربوهيدرات تظهر في كل وجبة.'), style: muted),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          OutlinedButton(
            onPressed: () => _enterDoctorNumbers(context),
            child: Text(s.tr("Enter My Doctor's Numbers", 'إدخال أرقام طبيبي')),
          ),
          TextButton(onPressed: controller.clearCarbPlan, child: Text(s.tr('Show the Starting Point', 'عرض نقطة البداية'))),
        ]),
      ]);
    } else if (suggestion != null) {
      children.addAll([
        Text(
          s.tr(
            'Suggested: ${suggestion.meal.toStringAsFixed(0)} g a meal (${formatPortions(carbPortions(suggestion.meal))} portions) and ${suggestion.snack.toStringAsFixed(0)} g a snack',
            'المقترح: ${suggestion.meal.toStringAsFixed(0)} غ للوجبة (${formatPortions(carbPortions(suggestion.meal))} حصص) و${suggestion.snack.toStringAsFixed(0)} غ للوجبة الخفيفة',
          ),
          style: strong,
        ),
        const SizedBox(height: 6),
        Text(
          s.tr(
            'A common starting point used in diabetes education. It is not your personal target. Your doctor or dietitian can set the right number for you. Counted as total carbohydrate, the number on food labels.',
            'نقطة بداية شائعة في التثقيف السكري، وليست هدفك الشخصي. يمكن لطبيبك أو أخصائي التغذية تحديد الرقم المناسب لك. تُحسب كإجمالي الكربوهيدرات، وهو الرقم المكتوب على ملصقات الأطعمة.',
          ),
          style: muted,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: FilledButton(
              onPressed: () async {
                if (await confirmMiqdarNumber(context)) await controller.useSuggestedCarbs();
              },
              child: Text(s.tr('Use This', 'استخدمه')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(onPressed: controller.waitForDoctor, child: Text(s.tr('Wait for My Doctor', 'سأنتظر طبيبي'))),
          ),
        ]),
        TextButton(
          onPressed: () => _enterDoctorNumbers(context),
          child: Text(s.tr("Enter My Doctor's Numbers", 'إدخال أرقام طبيبي')),
        ),
      ]);
    }

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  static String _blockText(S s, CarbAdviceBlock block) {
    final reason = switch (block) {
      CarbAdviceBlock.type1 => s.tr('With type 1 diabetes', 'مع سكري النوع الأول'),
      CarbAdviceBlock.insulin => s.tr('When you take insulin', 'عند استخدام الإنسولين'),
      CarbAdviceBlock.pregnancy => s.tr('In pregnancy or breastfeeding', 'أثناء الحمل أو الرضاعة'),
      CarbAdviceBlock.underAge => s.tr('Under 18', 'لمن هم دون 18 عاماً'),
      CarbAdviceBlock.kidney => s.tr('With a kidney diet', 'مع حمية الكلى'),
      CarbAdviceBlock.fasting => s.tr('While fasting in Ramadan', 'أثناء صيام رمضان'),
    };
    final tail = block == CarbAdviceBlock.fasting
        ? s.tr(
            ', follow the Ramadan plan your care team gives you. You can enter their numbers here.',
            '، اتبع خطة رمضان التي يضعها لك فريقك الطبي. يمكنك إدخال أرقامهم هنا.',
          )
        : s.tr(
            ', your care team should set this for you. You can enter their numbers here.',
            '، يجب أن يحدد فريقك الطبي هذا الرقم لك. يمكنك إدخال أرقامهم هنا.',
          );
    return '$reason$tail';
  }

  Future<void> _enterDoctorNumbers(BuildContext context) async {
    final s = S.of(context);
    final d = controller.diabetes;
    final meal = TextEditingController(text: d.mealCarbsG?.toStringAsFixed(0) ?? '');
    final snack = TextEditingController(text: d.snackCarbsG?.toStringAsFixed(0) ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.tr("Your doctor's numbers", 'أرقام طبيبك')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: meal,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: s.tr('Carbs a meal', 'كربوهيدرات الوجبة'), suffixText: s.unitG),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: snack,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: s.tr('Carbs a snack', 'كربوهيدرات الوجبة الخفيفة'), suffixText: s.unitG),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(s.tr('Cancel', 'إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(s.tr('Save', 'حفظ'))),
        ],
      ),
    );
    if (saved != true) return;
    final mealG = double.tryParse(normalizeDigits(meal.text).trim());
    final snackG = double.tryParse(normalizeDigits(snack.text).trim());
    if (mealG == null || mealG <= 0 || mealG > 300) return;
    await controller.setDoctorCarbs(meal: mealG, snack: snackG != null && snackG > 0 && snackG <= 300 ? snackG : null);
  }
}

/// Asks the user to accept that Miqdar's number is general guidance, not medical advice, before using it.
/// [strongerReason] is for people the app tells to ask their care team (type 1, insulin, and so on).
Future<bool> confirmMiqdarNumber(BuildContext context, {String? strongerReason}) async {
  final s = S.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(s.tr('Before you use this number', 'قبل أن تستخدم هذا الرقم')),
      content: Text(
        [
          if (strongerReason != null)
            s.tr(
              '$strongerReason, your care team should set this number, and using a general one can be risky.',
              '$strongerReason، يجب أن يحدد فريقك الطبي هذا الرقم، وقد يكون استخدام رقم عام خطرًا.',
            ),
          s.tr(
            'It is general guidance from medical sources, not medical advice for you. Miqdar takes no medical '
                'responsibility for how it is used. Your doctor or dietitian can set the right number for you.',
            'هذا إرشاد عام من مصادر طبية، وليس نصيحة طبية لك. لا يتحمل مقدار أي مسؤولية طبية عن استخدامه. '
                'يمكن لطبيبك أو أخصائي التغذية تحديد الرقم المناسب لك.',
          ),
        ].join(' '),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(s.tr('Cancel', 'إلغاء'))),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(s.tr('I Understand, Use It', 'فهمت، استخدمه')),
        ),
      ],
    ),
  );
  return ok == true;
}

/// The daily free-sugar limit in diabetes mode: the general one, Miqdar's stricter one, or the user's own.
class SugarLimitCard extends StatelessWidget {
  const SugarLimitCard({super.key, required this.controller});

  final MiqdarController controller;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.mq;
    final d = controller.diabetes;
    if (!d.hasDiabetes) return const SizedBox.shrink();
    final muted = MiqdarType.body.copyWith(color: c.inkMuted);
    final limit = controller.sugarLimitG.toStringAsFixed(0);
    final miqdar = freeSugarLimitG(controller.goals.calories, diabetes: true).toStringAsFixed(0);

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.tr('Free sugar a day', 'السكر الحر في اليوم'), style: MiqdarType.titleCard.copyWith(color: c.ink)),
          const SizedBox(height: 8),
          Text(s.tr('Under $limit g a day', 'أقل من $limit غ في اليوم'), style: MiqdarType.bodyStrong.copyWith(color: c.ink)),
          const SizedBox(height: 4),
          Text(
            switch (d.sugarSource) {
              SugarLimitSource.general => s.tr(
                  "The general limit for everyone: under 10% of your calories (WHO). Miqdar's number for diabetes is stricter.",
                  'الحد العام للجميع: أقل من 10% من سعراتك (منظمة الصحة العالمية). رقم مقدار لمرضى السكري أشد.',
                ),
              SugarLimitSource.recommended => s.tr(
                  "Miqdar's number for diabetes: under 5% of your calories (WHO). General guidance, not medical advice.",
                  'رقم مقدار لمرضى السكري: أقل من 5% من سعراتك (منظمة الصحة العالمية). إرشاد عام، وليس نصيحة طبية.',
                ),
              SugarLimitSource.own => s.tr('Your own number, from your doctor.', 'رقمك الخاص، من طبيبك.'),
            },
            style: muted,
          ),
          const SizedBox(height: 4),
          Text(
            s.tr(
              'Free sugar is added sugar, honey, syrups and juice. Sugar inside whole fruit and milk is not counted.',
              'السكر الحر هو السكر المضاف والعسل والشراب المحلّى والعصير. لا يُحسب السكر داخل الفاكهة الكاملة والحليب.',
            ),
            style: muted,
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            if (d.sugarSource != SugarLimitSource.recommended)
              FilledButton(
                onPressed: () async {
                  if (await confirmMiqdarNumber(context)) await controller.useRecommendedSugarLimit();
                },
                child: Text(s.tr("Use Miqdar's Number ($miqdar g)", 'استخدام رقم مقدار ($miqdar غ)')),
              ),
            OutlinedButton(
              onPressed: () => _enterOwn(context),
              child: Text(s.tr("Enter My Doctor's Number", 'إدخال رقم طبيبي')),
            ),
            if (d.sugarSource != SugarLimitSource.general)
              TextButton(
                onPressed: controller.useGeneralSugarLimit,
                child: Text(s.tr('Use the General Limit', 'استخدام الحد العام')),
              ),
          ]),
        ],
      ),
    );
  }

  Future<void> _enterOwn(BuildContext context) async {
    final s = S.of(context);
    final field = TextEditingController(text: controller.diabetes.ownSugarLimitG?.toStringAsFixed(0) ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.tr("Your doctor's number", 'رقم طبيبك')),
        content: TextField(
          controller: field,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: s.tr('Free sugar a day', 'السكر الحر في اليوم'), suffixText: s.unitG),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(s.tr('Cancel', 'إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(s.tr('Save', 'حفظ'))),
        ],
      ),
    );
    if (saved != true) return;
    final grams = double.tryParse(normalizeDigits(field.text).trim());
    if (grams == null || grams <= 0 || grams > 200) return;
    await controller.setOwnSugarLimit(grams);
  }
}

/// A meal's carbs in grams and portions, with the plan beside it when there is one. Quiet: no
/// warning colour, no block.
class CarbLine extends StatelessWidget {
  const CarbLine({super.key, required this.values, this.target, this.style});

  final NutritionValues values;
  final double? target;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = values.isMissing('carbohydrate_g')
        ? s.tr('Carbs Unknown', 'الكربوهيدرات غير معروفة')
        : [
            s.tr(
              'Carbs ${values.carbohydrates.toStringAsFixed(0)} g · ${formatPortions(carbPortions(values.carbohydrates))} portions',
              'كربوهيدرات ${values.carbohydrates.toStringAsFixed(0)} غ · ${formatPortions(carbPortions(values.carbohydrates))} حصص',
            ),
            if (target != null) s.tr('plan ${target!.toStringAsFixed(0)} g', 'الخطة ${target!.toStringAsFixed(0)} غ'),
          ].join(' · ');
    return Text(text, style: style ?? MiqdarType.bodyStrong.copyWith(color: context.mq.ink));
  }
}


/// Blood sugar readings that belong to [meal], with Add Reading. A plain log: no ranges or advice.
class MealGlucoseSection extends StatelessWidget {
  const MealGlucoseSection({super.key, required this.controller, required this.meal});

  final MiqdarController controller;
  final MealEntry meal;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.mq;
    if (!controller.diabetes.hasDiabetes) return const SizedBox.shrink();
    final unit = controller.glucoseUnit;
    final readings = controller.readingsForMeal(meal);
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.tr('Blood sugar', 'سكر الدم'), style: MiqdarType.titleCard.copyWith(color: c.ink)),
          for (final r in readings)
            Row(children: [
              Icon(MiqdarIcons.bloodtype, size: 18, color: c.inkMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${unit.format(r.mgdl)} ${unit.label(s.isAr)} · ${r.tag.label(s.isAr)} · ${s.date(r.at.toLocal(), 'h:mm a')}'
                  '${r.fromHealth ? ' · ${s.tr('Apple Health', 'صحة Apple')}' : ''}',
                  style: MiqdarType.body.copyWith(color: c.ink),
                ),
              ),
              IconButton(
                tooltip: s.tr('Delete reading', 'حذف القراءة'),
                onPressed: () => controller.deleteGlucose(r.id),
                icon: Icon(MiqdarIcons.delete, size: 20, color: c.inkMuted),
              ),
            ]),
          TextButton.icon(
            onPressed: () => showAddGlucoseDialog(context, controller, meal: meal),
            icon: const Icon(MiqdarIcons.add),
            label: Text(s.tr('Add Reading', 'إضافة قراءة')),
          ),
        ],
      ),
    );
  }
}

/// Types a reading in the user's unit. From a meal, the time follows the tag so it links to it.
Future<void> showAddGlucoseDialog(BuildContext context, MiqdarController controller, {MealEntry? meal}) async {
  final s = S.of(context);
  final unit = controller.glucoseUnit;
  final field = TextEditingController();
  var tag = meal != null && DateTime.now().difference(meal.eatenAt).inMinutes > 30 ? GlucoseTag.afterMeal : GlucoseTag.beforeMeal;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(s.tr('Blood sugar reading', 'قراءة سكر الدم')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: field,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(suffixText: unit.label(s.isAr)),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in GlucoseTag.values)
                ChoiceChip(label: Text(t.label(s.isAr)), selected: tag == t, onSelected: (_) => setState(() => tag = t)),
            ]),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(s.tr('Cancel', 'إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(s.tr('Save', 'حفظ'))),
        ],
      ),
    ),
  );
  if (ok != true) return;
  final value = double.tryParse(normalizeDigits(field.text).trim());
  if (value == null || value <= 0) return;
  final mgdl = unit.toMgdl(value);
  if (mgdl < 10 || mgdl > 900) return;
  DateTime? at;
  if (meal != null) {
    at = switch (tag) {
      GlucoseTag.beforeMeal => meal.eatenAt.subtract(const Duration(minutes: 10)),
      GlucoseTag.afterMeal => meal.eatenAt.add(const Duration(hours: 2)),
      GlucoseTag.other => DateTime.now().difference(meal.eatenAt).abs() <= const Duration(hours: 3) ? null : meal.eatenAt,
    };
    if (at != null && at.isAfter(DateTime.now())) at = null;
  }
  await controller.addGlucose(value, tag: tag, at: at);
}

/// mg/dL (Saudi practice) or mmol/L, for people with a meter in the other unit.
class GlucoseUnitCard extends StatelessWidget {
  const GlucoseUnitCard({super.key, required this.controller});

  final MiqdarController controller;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (!controller.diabetes.hasDiabetes) return const SizedBox.shrink();
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.tr('Blood sugar unit', 'وحدة سكر الدم'), style: MiqdarType.titleCard.copyWith(color: context.mq.ink)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final u in GlucoseUnit.values)
              ChoiceChip(
                label: Text(u.label(s.isAr)),
                selected: controller.glucoseUnit == u,
                onSelected: (_) => controller.setGlucoseUnit(u),
              ),
          ]),
        ],
      ),
    );
  }
}
