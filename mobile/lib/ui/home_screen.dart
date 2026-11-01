import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app.dart';
import '../app_controller.dart';
import '../data/food_catalog.dart';
import '../l10n/strings.dart';
import '../models/nutrition.dart';
import '../theme.dart';
import 'screens.dart';
import 'widgets/brand.dart';
import 'widgets/charts_and_gauges.dart';
import 'widgets/miq_icons.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onScan,
    this.onOpenTab,
  });

  final VoidCallback onScan;
  final ValueChanged<int>? onOpenTab;

  void _openNotices(BuildContext context, S s) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(s.navNotices)),
            body: const SafeArea(child: AlertsScreen()),
          ),
        ),
      );

  void _openMealIdeas(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MealSuggestionsScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final miq = Miq.of(context);
    final selectedDate = controller.selectedDate;
    final isToday = MiqdarController.isSameLocalDay(selectedDate, DateTime.now());
    final totals = controller.selectedDateTotals;
    final dayMeals = controller.mealsForDate(selectedDate);
    final goals = controller.goals;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            Row(
              children: [
                const MiqdarMark(size: 34),
                const Spacer(),
                Badge(
                  isLabelVisible: controller.unreadAlertsCount > 0,
                  label: Text('${controller.unreadAlertsCount}'),
                  backgroundColor: MiqdarColors.danger,
                  child: IconButton(
                    tooltip: s.navNotices,
                    color: miq.text,
                    onPressed: () => _openNotices(context, s),
                    icon: const Icon(MiqIcons.bell),
                  ),
                ),
              ],
            ),
            if (controller.account.isDemo)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  s.demoBanner,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: miq.accent),
                ),
              ),
            const SizedBox(height: 6),

            // The day
            Row(
              children: [
                IconButton(
                  tooltip: s.tr('Previous day', 'اليوم السابق'),
                  color: miq.muted,
                  onPressed: () => controller.setSelectedDate(
                    selectedDate.subtract(const Duration(days: 1)),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) controller.setSelectedDate(picked);
                    },
                    child: Column(
                      children: [
                        Text(
                          isToday ? s.tr('Today', 'اليوم') : s.date(selectedDate, 'EEEE'),
                          style: MiqType.display(32, color: miq.text, height: 1.2),
                        ),
                        Text(
                          s.date(selectedDate, 'd MMMM'),
                          style: TextStyle(fontSize: 13, color: miq.muted),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: s.tr('Next day', 'اليوم التالي'),
                  color: miq.muted,
                  onPressed: isToday
                      ? null
                      : () => controller.setSelectedDate(
                            selectedDate.add(const Duration(days: 1)),
                          ),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Center(child: _CalorieDial(consumed: totals.calories, goals: goals)),
            const SizedBox(height: 24),

            _NutrientSummary(totals: totals, goals: goals),
            const SizedBox(height: 22),

            if (controller.lastRecognition != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Ledger(
                  children: [
                    LedgerRow(
                      icon: MiqIcons.notePencil,
                      title: s.tr('Meal not saved yet', 'وجبة لم تُحفظ بعد'),
                      subtitle:
                          '${s.isAr && controller.lastRecognition!.nameAr.isNotEmpty ? controller.lastRecognition!.nameAr : controller.lastRecognition!.nameEn} • ${controller.lastRecognition!.totalWeightG.toStringAsFixed(0)} ${s.unitG}',
                      trailing: Text(
                        s.tr('Resume', 'متابعة'),
                        style: TextStyle(fontWeight: FontWeight.w600, color: miq.accent),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RecognitionResultScreen(result: controller.lastRecognition!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            _ScalePanel(onScan: onScan),
            const SizedBox(height: 28),

            SectionHeading(
              isToday
                  ? s.recentMealsTitle
                  : '${s.tr("Meals on", "وجبات يوم")} ${s.date(selectedDate, 'd MMM')}',
              action: s.tr('See diary', 'عرض السجل'),
              onAction: () {
                if (onOpenTab != null) {
                  onOpenTab!(2); // Diary tab
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(s.navDiary)),
                        body: const SafeArea(child: HistoryScreen()),
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            if (dayMeals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  s.noMealsToday,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: miq.muted),
                ),
              )
            else
              Ledger(children: dayMeals.map((meal) => MealRowCard(meal: meal)).toList()),
            const SizedBox(height: 28),

            SectionHeading(
              s.mealIdeasTitle,
              action: s.seeAll,
              onAction: () => _openMealIdeas(context),
            ),
            const SizedBox(height: 8),
            if (controller.recommendationsBusy && controller.mealSuggestions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: LinearProgressIndicator(),
              )
            else if (controller.mealSuggestions.isEmpty)
              Ledger(
                children: [
                  LedgerRow(
                    icon: MiqIcons.forkKnife,
                    title: s.tr(
                      'Tell us what you like and what to avoid to get meal ideas.',
                      'أخبرنا بما تحبه وما تتجنبه لتحصل على أفكار للوجبات.',
                    ),
                    onTap: () => _openMealIdeas(context),
                  ),
                ],
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: controller.mealSuggestions
                      .take(4)
                      .map(
                        (suggestion) => Padding(
                          padding: const EdgeInsetsDirectional.only(end: 12),
                          child: SizedBox(
                            width: 268,
                            child: SuggestionCardWidget(suggestion: suggestion, compact: true),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The day's calories on the brand's dial: what is left, unless there is no goal.
class _CalorieDial extends StatelessWidget {
  const _CalorieDial({required this.consumed, required this.goals});

  final double consumed;
  final NutritionGoals goals;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final miq = Miq.of(context);
    final target = goals.calories;
    final hasGoal = !goals.trackingOnly && target > 0;
    final isOver = hasGoal && consumed > target;
    final left = (target - consumed).abs();
    final String headline;
    final String caption;
    if (!hasGoal) {
      headline = consumed.toStringAsFixed(0);
      caption = s.tr('kcal eaten', 'سعرة مسجلة');
    } else if (isOver) {
      headline = left.toStringAsFixed(0);
      caption = s.tr('kcal over goal', 'سعرة فوق الهدف');
    } else {
      headline = left.toStringAsFixed(0);
      caption = s.tr('kcal left', 'سعرة متبقية');
    }
    return MeasureDial(
      size: 248,
      progress: hasGoal ? consumed / target : 0,
      strokeWidth: 10,
      color: isOver ? MiqdarColors.danger : MiqdarColors.saffron,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(headline, style: MiqType.display(68, color: miq.text, height: 1)),
          const SizedBox(height: 2),
          Text(caption, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: miq.text)),
          if (hasGoal)
            Text(
              s.tr(
                '${consumed.toStringAsFixed(0)} of ${target.toStringAsFixed(0)}',
                '${consumed.toStringAsFixed(0)} من ${target.toStringAsFixed(0)}',
              ),
              style: TextStyle(fontSize: 12.5, color: miq.muted),
            ),
        ],
      ),
    );
  }
}

class _NutrientSummary extends StatelessWidget {
  const _NutrientSummary({required this.totals, required this.goals});

  final NutritionValues totals;
  final NutritionGoals goals;

  double? _ratio(double value, double goal) =>
      goals.trackingOnly || goal <= 0 ? null : value / goal;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    Widget column(String label, double value, double goal, String unit, Color color) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: MacroColumn(
              label: label,
              value: '${value.toStringAsFixed(0)} $unit',
              color: color,
              progress: _ratio(value, goal),
            ),
          ),
        );
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GoalsScreen()),
      ),
      child: Column(
        children: [
          Row(
            children: [
              column(s.protein, totals.protein, goals.protein, s.unitG, MiqdarColors.proteinAccent),
              column(s.carbs, totals.carbohydrates, goals.carbohydrates, s.unitG, MiqdarColors.carbsAccent),
              column(s.fat, totals.fat, goals.fat, s.unitG, MiqdarColors.fatAccent),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              column(s.sugar, totals.sugar, goals.sugar, s.unitG, MiqdarColors.sugarAccent),
              column(s.fiber, totals.fiber, goals.fiber, s.unitG, MiqdarColors.fiberAccent),
              column(s.sodium, totals.sodium, goals.sodium, s.unitMg, MiqdarColors.sodiumAccent),
            ],
          ),
        ],
      ),
    );
  }
}

/// The scale, live, with the way into Add Meal. The one dark panel on the page.
class _ScalePanel extends StatelessWidget {
  const _ScalePanel({required this.onScan});
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scale = MiqdarScope.of(context).scaleDevice;
    final grams = scale.effectiveWeightG < 0 ? 0.0 : scale.effectiveWeightG;
    const soft = Color(0xFFBFB1A0);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: BoxDecoration(
        color: MiqdarColors.ink,
        borderRadius: BorderRadius.circular(24),
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: MiqdarColors.darkBorder)
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: scale.online
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DeviceSettingsScreen()),
                      ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scale.online ? s.tr('On the scale', 'على الميزان') : s.tr('Scale', 'الميزان'),
                    style: const TextStyle(color: soft, fontSize: 12.5, fontWeight: FontWeight.w500),
                  ),
                  if (scale.online)
                    Text(
                      '${grams.toStringAsFixed(0)} ${s.unitG}',
                      style: MiqType.display(36, color: MiqdarColors.paper, height: 1.15),
                    )
                  else ...[
                    const SizedBox(height: 3),
                    Text(
                      s.tr('Not connected', 'غير متصل'),
                      style: const TextStyle(color: MiqdarColors.paper, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      s.tr('Tap to connect', 'اضغط للاتصال'),
                      style: const TextStyle(color: MiqdarColors.accentGlow, fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18)),
            onPressed: onScan,
            icon: const Icon(MiqIcons.plus, size: 20),
            label: Text(s.startCapture),
          ),
        ],
      ),
    );
  }
}

class SuggestionCardWidget extends StatelessWidget {
  const SuggestionCardWidget({
    super.key,
    required this.suggestion,
    this.compact = false,
  });

  final MealSuggestion suggestion;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final controller = MiqdarScope.of(context);
    final miq = Miq.of(context);

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            suggestion.displayName(s.isAr),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: MiqType.display(25, color: miq.text, height: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            [
              '${suggestion.portionG.toStringAsFixed(0)} ${s.unitG}',
              '${suggestion.nutrients.calories.toStringAsFixed(0)} ${s.unitKcal}',
              '${suggestion.nutrients.protein.toStringAsFixed(0)} ${s.unitG} ${s.protein}',
              if (!compact) '${suggestion.nutrients.sodium.toStringAsFixed(0)} ${s.unitMg} ${s.sodium}',
            ].join(' • '),
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: miq.accent),
          ),
          const SizedBox(height: 8),
          if (!s.isAr || hasArabicText(suggestion.why.join()))
            Text(
              () {
                final why = suggestion.why.join(' • ');
                return why.isEmpty ? why : why[0].toUpperCase() + why.substring(1);
              }(),
              maxLines: compact ? 2 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: const TextStyle(fontSize: 12),
            ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () async {
                // PRD-01: Suggestion opens an editable meal draft, never logs automatically!
                final catalogItem = MiqdarFoodCatalog.findByIdOrLabel(suggestion.foodId) ??
                    FoodCatalogItem(
                      foodId: suggestion.foodId,
                      nameEn: suggestion.nameEn,
                      nameAr: suggestion.nameAr,
                      category: 'Suggested',
                      preparation: 'Standard serving',
                      verificationStatus: suggestion.verificationStatus,
                      sourceId: 'MIQDAR_RECOMMENDATION',
                      per100g: suggestion.portionG > 0
                          ? suggestion.nutrients.scaledBy(100.0 / suggestion.portionG)
                          : suggestion.nutrients,
                    );
                final draft = await controller.prepareCatalogDraft(
                  food: catalogItem,
                  weightG: suggestion.portionG,
                  portionSource: PortionSource.serving,
                );
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecognitionResultScreen(result: draft),
                  ),
                );
              },
              icon: const Icon(MiqIcons.calendarPlus, size: 16),
              label: Text(s.tr('Log This', 'سجّل هذه الوجبة')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Loads a saved meal's photo. Shows [fallback] when the meal has no photo.
class MealPhoto extends StatefulWidget {
  const MealPhoto({
    super.key,
    required this.mealId,
    required this.builder,
    this.fallback = const SizedBox.shrink(),
  });

  final String mealId;
  final Widget Function(Uint8List bytes) builder;
  final Widget fallback;

  @override
  State<MealPhoto> createState() => _MealPhotoState();
}

class _MealPhotoState extends State<MealPhoto> {
  Future<Uint8List?>? photo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    photo ??= MiqdarScope.of(context).mealPhoto(widget.mealId);
  }

  @override
  void didUpdateWidget(covariant MealPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mealId != widget.mealId) {
      photo = MiqdarScope.of(context).mealPhoto(widget.mealId);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
        future: photo,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          return bytes == null ? widget.fallback : widget.builder(bytes);
        },
      );
}

/// A meal as a row in a [Ledger]: the plate, what it was, when, and its calories.
class MealRowCard extends StatelessWidget {
  const MealRowCard({super.key, required this.meal});
  final MealEntry meal;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final miq = Miq.of(context);
    final name = meal.displayName(s.isAr);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MealDetailScreen(meal: meal)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox.square(
                dimension: 54,
                child: MealPhoto(
                  mealId: meal.id,
                  builder: (bytes) => Image.memory(bytes, fit: BoxFit.cover, cacheWidth: 170),
                  fallback: ColoredBox(
                    color: miq.track,
                    child: Center(
                      child: Text(
                        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                        style: MiqType.display(25, color: miq.text),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: miq.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${s.mealTypeLabel(meal.mealType)} • ${s.date(meal.eatenAt.toLocal(), 'h:mm a')} • ${meal.weightG.toStringAsFixed(0)} ${s.unitG}',
                    style: TextStyle(fontSize: 12.5, color: miq.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  meal.nutrients.calories.toStringAsFixed(0),
                  style: MiqType.display(26, color: miq.text, height: 1.1),
                ),
                Text(s.unitKcal, style: TextStyle(fontSize: 11.5, color: miq.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
