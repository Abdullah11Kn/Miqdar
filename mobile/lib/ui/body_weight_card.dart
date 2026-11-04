import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app.dart';
import '../app_controller.dart';
import '../l10n/strings.dart';
import '../models/body_profile.dart';
import '../theme.dart';
import 'widgets/charts_and_gauges.dart';

/// Body weight the user types in, on Insights. The kitchen scale cannot weigh a person.
class BodyWeightCard extends StatefulWidget {
  const BodyWeightCard({super.key});

  @override
  State<BodyWeightCard> createState() => _BodyWeightCardState();
}

class _BodyWeightCardState extends State<BodyWeightCard> {
  int? _selected;

  Future<void> _edit(MiqdarController controller, S s, [BodyWeightEntry? entry]) async {
    final field = TextEditingController(text: entry == null ? '' : '${entry.weightKg}');
    var date = entry?.measuredOn ?? DateTime.now();
    String? error;
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                entry == null ? s.tr('Add Your Weight', 'أضف وزنك') : s.tr('Edit Your Weight', 'عدّل وزنك'),
                style: MiqdarType.titleSection.copyWith(color: ctx.mq.ink),
              ),
              const SizedBox(height: 4),
              Text(
                s.tr('Type it in from your bathroom scale.', 'أدخله من ميزان الحمام.'),
                style: MiqdarType.body.copyWith(color: ctx.mq.inkMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: field,
                autofocus: entry == null,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: s.tr('Weight', 'الوزن'),
                  suffixText: s.tr('kg', 'كغ'),
                  errorText: error,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text(s.date(date, 'd MMM yyyy'), style: MiqdarType.body.copyWith(color: ctx.mq.ink))),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime.now().subtract(const Duration(days: 730)),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setSheetState(() => date = picked);
                    },
                    child: Text(s.tr('Change Date', 'تغيير التاريخ')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: () {
                  final kg = double.tryParse(normalizeDigits(field.text).trim());
                  if (kg == null || kg < 20 || kg > 300) {
                    setSheetState(() => error = s.tr('Enter a weight from 20 to 300 kg', 'أدخل وزناً من 20 إلى 300 كغ'));
                    return;
                  }
                  Navigator.of(sheetCtx).pop(true);
                },
                child: Text(s.tr('Save', 'حفظ')),
              ),
              if (entry != null)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: ctx.mq.danger),
                  onPressed: () => Navigator.of(sheetCtx).pop(false),
                  child: Text(s.tr('Delete', 'حذف')),
                ),
            ],
          ),
        ),
      ),
    );
    if (save == null) return;
    setState(() => _selected = null);
    if (save) {
      await controller.saveWeightEntry(
        id: entry?.id,
        measuredOn: date,
        weightKg: double.parse(normalizeDigits(field.text).trim()),
      );
    } else {
      await controller.deleteWeightEntry(entry!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final c = context.mq;
    final entries = controller.weightEntries;
    final offer = controller.goalUpdateOffer;
    final kg = s.tr('kg', 'كغ');
    final selected = _selected != null && _selected! < entries.length ? entries[_selected!] : null;
    final shown = selected ?? (entries.isEmpty ? null : entries.last);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(s.tr('Body weight', 'وزن الجسم'), style: MiqdarType.titleSection.copyWith(color: c.ink))),
            TextButton.icon(
              onPressed: () => _edit(controller, s),
              icon: const Icon(MiqdarIcons.add, size: 18),
              label: Text(s.tr('Add', 'إضافة')),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (offer != null) ...[
          SurfaceCard(
            color: c.accentSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.tr(
                    'Your weight has changed. Update your daily goal to about ${offer.calories.toStringAsFixed(0)} kcal?',
                    'تغيّر وزنك. هل تحدّث هدفك اليومي إلى حوالي ${offer.calories.toStringAsFixed(0)} سعرة؟',
                  ),
                  style: MiqdarType.body.copyWith(color: c.ink),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(onPressed: controller.acceptGoalUpdate, child: Text(s.tr('Update Goal', 'حدّث الهدف'))),
                    TextButton(onPressed: controller.declineGoalUpdate, child: Text(s.tr('Keep Current Goal', 'أبقِ الهدف الحالي'))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        SurfaceCard(
          child: entries.isEmpty
              ? Text(
                  s.tr('Add your weight to see how it changes over time.', 'أضف وزنك لترى كيف يتغير مع الوقت.'),
                  style: MiqdarType.body.copyWith(color: c.inkMuted),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.date(shown!.measuredOn, 'd MMM yyyy'), style: MiqdarType.caption.copyWith(color: c.inkMuted)),
                    Text('${shown.weightKg} $kg', style: MiqdarType.numberLg.copyWith(color: c.ink)),
                    if (entries.length > 1) ...[
                      const SizedBox(height: 10),
                      _WeightChart(
                        entries: entries,
                        selected: _selected,
                        onSelect: (index) => setState(() => _selected = index),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // The newest entries as a table, so every value can be read and corrected.
                    for (final entry in entries.reversed.take(5))
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _edit(controller, s, entry),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Expanded(child: Text(s.date(entry.measuredOn, 'd MMM yyyy'), style: MiqdarType.body.copyWith(color: c.ink))),
                              Text('${entry.weightKg} $kg', style: MiqdarType.bodyStrong.copyWith(color: c.ink)),
                              const SizedBox(width: 4),
                              Icon(MiqdarIcons.chevronRight, size: 18, color: c.inkMuted),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

// A margin of its own for the range labels, so the line never runs through them.
const _plotStart = 42.0;
const _plotEnd = 8.0;

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.entries, required this.selected, required this.onSelect});

  final List<BodyWeightEntry> entries;
  final int? selected;
  final ValueChanged<int> onSelect;

  void _pick(Offset at, double width) {
    final t = ((at.dx - _plotStart) / (width - _plotStart - _plotEnd)).clamp(0.0, 1.0);
    onSelect((t * (entries.length - 1)).round());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mq;
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _pick(details.localPosition, constraints.maxWidth),
        onHorizontalDragUpdate: (details) => _pick(details.localPosition, constraints.maxWidth),
        child: SizedBox(
          height: 120,
          width: double.infinity,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: CustomPaint(
              painter: _WeightChartPainter(
                values: [for (final entry in entries) entry.weightKg],
                selected: selected ?? entries.length - 1,
                line: c.primary,
                grid: c.border,
                surface: c.surface,
                label: c.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One series, one axis: a 2 px line, a marker on the chosen point, and a quiet range label.
class _WeightChartPainter extends CustomPainter {
  _WeightChartPainter({
    required this.values,
    required this.selected,
    required this.line,
    required this.grid,
    required this.surface,
    required this.label,
  });

  final List<double> values;
  final int selected;
  final Color line;
  final Color grid;
  final Color surface;
  final Color label;

  @override
  void paint(Canvas canvas, Size size) {
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final span = math.max(high - low, 1.0);
    const inset = 8.0;
    final height = size.height - inset * 2;
    Offset at(int i) => Offset(
          _plotStart + (size.width - _plotStart - _plotEnd) * i / (values.length - 1),
          inset + height * (1 - (values[i] - low) / span),
        );

    final rule = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(_plotStart, inset), Offset(size.width, inset), rule);
    canvas.drawLine(Offset(_plotStart, size.height - inset), Offset(size.width, size.height - inset), rule);
    _text(canvas, high.toStringAsFixed(1), const Offset(0, 0));
    _text(canvas, low.toStringAsFixed(1), Offset(0, size.height - 16));

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    final point = at(selected.clamp(0, values.length - 1));
    canvas.drawCircle(point, 6, Paint()..color = surface);
    canvas.drawCircle(point, 4, Paint()..color = line);
  }

  void _text(Canvas canvas, String text, Offset offset) {
    TextPainter(
      text: TextSpan(text: text, style: MiqdarType.caption.copyWith(color: label)),
      textDirection: TextDirection.ltr,
    )
      ..layout()
      ..paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_WeightChartPainter old) =>
      old.values != values || old.selected != selected || old.line != line;
}
