import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n/strings.dart';
import '../models/nutrition.dart';
import '../theme.dart';
import 'widgets/charts_and_gauges.dart';

/// Weigh What's Left: an empty container on the scale, Zero, then the leftovers go in.
Future<void> showLeftoversSheet(BuildContext context, MiqdarController controller, MealEntry meal) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LeftoversSheet(controller: controller, meal: meal),
    );

enum _Step { chooseFood, container, leftovers }

class _LeftoversSheet extends StatefulWidget {
  const _LeftoversSheet({required this.controller, required this.meal});

  final MiqdarController controller;
  final MealEntry meal;

  @override
  State<_LeftoversSheet> createState() => _LeftoversSheetState();
}

class _LeftoversSheetState extends State<_LeftoversSheet> {
  late _Step step = widget.meal.items.length > 1 ? _Step.chooseFood : _Step.container;

  /// The plate food that was left; null is the whole meal, or Mixed on a plate.
  int? itemIndex;
  String? problem;
  bool saving = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final scale = widget.controller.scaleDevice;
        final connected = scale.paired && scale.online;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.tr("Weigh What's Left", 'وزن المتبقي'), style: MiqdarType.titleSection.copyWith(color: context.mq.ink)),
                const SizedBox(height: 12),
                if (!connected && step != _Step.chooseFood)
                  Text(
                    s.tr(
                      'The scale is not connected. Connect it from Profile, then try again.',
                      'الميزان غير متصل. اربطه من ملفي ثم حاول مرة أخرى.',
                    ),
                    style: MiqdarType.body.copyWith(color: context.mq.ink),
                  )
                else
                  ..._stepBody(context, s, scale),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _stepBody(BuildContext context, S s, ScaleDeviceState scale) {
    final muted = MiqdarType.body.copyWith(color: context.mq.inkMuted);
    switch (step) {
      case _Step.chooseFood:
        return [
          Text(s.tr('Which food is left?', 'أي طعام تبقى؟'), style: muted),
          const SizedBox(height: 8),
          for (var i = 0; i < widget.meal.items.length; i++)
            _choice(
              context,
              s.isAr && widget.meal.items[i].nameAr.isNotEmpty ? widget.meal.items[i].nameAr : widget.meal.items[i].nameEn,
              () => setState(() {
                itemIndex = i;
                step = _Step.container;
              }),
            ),
          _choice(
            context,
            s.tr('Mixed, a bit of everything', 'خليط من كل شيء'),
            () => setState(() {
              itemIndex = null;
              step = _Step.container;
            }),
          ),
        ];
      case _Step.container:
        return [
          Text(
            s.tr(
              'Put the empty container on the scale, then tap Zero.',
              'ضع الوعاء فارغاً على الميزان، ثم اضغط تصفير.',
            ),
            style: muted,
          ),
          const SizedBox(height: 16),
          _weight(context, s, scale),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: widget.controller.taringScale
                ? null
                : () async {
                    final ok = await widget.controller.tareScale();
                    if (!mounted) return;
                    setState(() {
                      problem = ok ? null : 'zero_failed';
                      if (ok) step = _Step.leftovers;
                    });
                  },
            child: Text(s.tr('Zero', 'تصفير')),
          ),
          if (problem != null) ...[const SizedBox(height: 10), _problemText(context, s)],
        ];
      case _Step.leftovers:
        final grams = scale.liveWeightG;
        final ready = scale.isStable && grams >= 1 && !saving;
        return [
          Text(s.tr('Now put the leftovers in the container.', 'الآن ضع المتبقي في الوعاء.'), style: muted),
          const SizedBox(height: 16),
          _weight(context, s, scale),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: ready ? () => _save(grams.roundToDouble()) : null,
            child: Text(
              ready
                  ? s.tr('Save ${grams.toStringAsFixed(0)} g Left', 'حفظ ${grams.toStringAsFixed(0)} غ متبقية')
                  : s.tr('Waiting for a steady weight', 'بانتظار ثبات الوزن'),
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              problem = null;
              step = _Step.container;
            }),
            child: Text(s.tr('Zero Again', 'تصفير مرة أخرى')),
          ),
          if (problem != null) _problemText(context, s),
        ];
    }
  }

  Widget _choice(BuildContext context, String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: OutlinedButton(onPressed: onTap, child: Text(label)),
      );

  Widget _weight(BuildContext context, S s, ScaleDeviceState scale) => Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            LockedNumber(scale.liveWeightG.toStringAsFixed(0), style: MiqdarType.numberLg.copyWith(color: context.mq.ink)),
            const SizedBox(width: 6),
            Text(s.unitG, style: MiqdarType.label.copyWith(color: context.mq.inkMuted)),
          ],
        ),
      );

  Widget _problemText(BuildContext context, S s) => Text(
        switch (problem) {
          'too_heavy' => s.tr(
              'That is more than was served. Check the container was zeroed, then try again.',
              'هذا أكثر مما قُدّم. تأكد من تصفير الوعاء ثم حاول مرة أخرى.',
            ),
          'zero_failed' => s.tr('The scale did not zero. Try again.', 'لم يتم تصفير الميزان. حاول مرة أخرى.'),
          _ => s.tr('Nothing is on the scale yet.', 'لا يوجد شيء على الميزان بعد.'),
        },
        style: MiqdarType.body.copyWith(color: context.mq.danger),
      );

  Future<void> _save(double grams) async {
    setState(() => saving = true);
    final result = await widget.controller.saveLeftover(widget.meal, grams, itemIndex: itemIndex);
    if (!mounted) return;
    if (result == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        saving = false;
        problem = result;
      });
    }
  }
}
