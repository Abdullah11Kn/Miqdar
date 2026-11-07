import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n/strings.dart';
import '../models/diabetes.dart';
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
          d.source == CarbPlanSource.doctor
              ? s.tr('From your doctor', 'من طبيبك')
              : s.tr('General starting point, not your personal target', 'نقطة بداية عامة، وليست هدفك الشخصي'),
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
          Expanded(child: FilledButton(onPressed: controller.useSuggestedCarbs, child: Text(s.tr('Use This', 'استخدمه')))),
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
