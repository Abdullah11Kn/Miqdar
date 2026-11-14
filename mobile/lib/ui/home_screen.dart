import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app.dart';
import '../data/food_catalog.dart';
import '../l10n/strings.dart';
import '../models/diabetes.dart';
import '../models/nutrition.dart';
import '../models/ramadan.dart';
import '../services/alert_service.dart';
import '../theme.dart';
import 'screens.dart';
import 'widgets/charts_and_gauges.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onScan,
    this.onOpenTab,
  });

  final VoidCallback onScan;
  final ValueChanged<int>? onOpenTab;

  String _greeting(S s) {
    final hour = DateTime.now().hour;
    if (hour < 12) return s.greetingMorning;
    if (hour < 17) return s.greetingAfternoon;
    return s.greetingEvening;
  }

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final selectedDate = controller.selectedDate;
    final isToday = controller.isToday(selectedDate);
    final totals = controller.selectedDateTotals;
    final dayMeals = controller.mealsForDate(selectedDate);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 780;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            isWide ? 28 : 20,
            8,
            isWide ? 28 : 20,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            // Demo Workspace Banner
            if (controller.account.isDemo)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: context.mq.accentSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(MiqdarIcons.science, color: context.mq.accentInk, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(s.demoBanner, style: MiqdarType.label.copyWith(color: context.mq.ink)),
                    ),
                  ],
                ),
              ),

            // Greeting and the bell
            Row(
              children: [
                Expanded(
                  child: Text(
                    _greeting(s).replaceAll(RegExp(r'[,،]\s*$'), ''),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(width: 12),
                RoundIconButton(
                  tooltip: s.navNotices,
                  count: controller.unreadAlertsCount,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(s.navNotices)),
                        body: const SafeArea(child: AlertsScreen()),
                      ),
                    ),
                  ),
                  icon: MiqdarIcons.notifications,
                ),
              ],
            ),

            // The date line doubles as the day picker
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: context.mq.inkMuted,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) controller.setSelectedDate(picked);
                      },
                      child: Text(
                        isToday
                            ? '${s.tr('Today', 'اليوم')} · ${s.date(selectedDate, 'EEE, d MMM')}'
                            : s.date(selectedDate, 'EEE, d MMM'),
                      ),
                    ),
                  ),
                ),
                RoundIconButton(
                  plain: true,
                  tooltip: s.tr('Previous day', 'اليوم السابق'),
                  onPressed: () => controller.setSelectedDate(
                    selectedDate.subtract(const Duration(days: 1)),
                  ),
                  icon: MiqdarIcons.chevronLeft,
                ),
                RoundIconButton(
                  plain: true,
                  tooltip: s.tr('Next day', 'اليوم التالي'),
                  onPressed: isToday
                      ? null
                      : () => controller.setSelectedDate(
                            selectedDate.add(const Duration(days: 1)),
                          ),
                  icon: MiqdarIcons.chevronRight,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Resume Draft Banner if an unsaved recognition draft exists (NAV-06, PRD-06)
            if (controller.lastRecognition != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: SurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.tr('Meal not saved yet', 'وجبة لم تُحفظ بعد'),
                              style: MiqdarType.bodyStrong.copyWith(color: context.mq.ink),
                            ),
                            Text(
                              '${controller.lastRecognition!.displayName(s.isAr)} · ${controller.lastRecognition!.totalWeightG.toStringAsFixed(0)} ${s.unitG}',
                              style: MiqdarType.body.copyWith(fontSize: 13, height: 18 / 13, color: context.mq.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16)),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RecognitionResultScreen(result: controller.lastRecognition!),
                          ),
                        ),
                        child: Text(s.tr('Resume', 'متابعة')),
                      ),
                    ],
                  ),
                ),
              ),

            if (controller.ramadanPrompt case final prompt?)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: SurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prompt.kind == RamadanPromptKind.turnOn
                            ? s.tr('Ramadan is near. Turn on Ramadan mode?', 'اقترب رمضان. هل تريد تفعيل وضع رمضان؟')
                            : s.tr('Ramadan has ended. Turn off Ramadan mode?', 'انتهى رمضان. هل تريد إيقاف وضع رمضان؟'),
                        style: MiqdarType.bodyStrong.copyWith(color: context.mq.ink),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        prompt.kind == RamadanPromptKind.turnOn
                            ? s.tr(
                                'Meals become Iftar, Suhoor and Snack, the day runs from noon to noon, and timed reminders pause. You can change it in Profile.',
                                'تصبح الوجبات إفطاراً وسحوراً ووجبة خفيفة، ويمتد اليوم من الظهر إلى الظهر، وتتوقف التذكيرات المؤقتة. يمكنك تغييره من ملفي.',
                              )
                            : s.tr(
                                'Meals and days go back to normal, and your reminders come back.',
                                'تعود الوجبات والأيام إلى وضعها المعتاد، وتعود تذكيراتك.',
                              ),
                        style: MiqdarType.body.copyWith(fontSize: 13, height: 18 / 13, color: context.mq.inkMuted),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilledButton(
                            style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16)),
                            onPressed: () => controller.answerRamadanPrompt(prompt, accept: true),
                            child: Text(prompt.kind == RamadanPromptKind.turnOn
                                ? s.tr('Turn On', 'تفعيل')
                                : s.tr('Turn Off', 'إيقاف')),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => controller.answerRamadanPrompt(prompt, accept: false),
                            child: Text(s.tr('Not Now', 'ليس الآن')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Responsive Top Grid: Daily Nutrition Summary + Add Meal
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _DailySummaryCard(
                totals: totals,
                goals: controller.limitGoals,
                carbsFirst: controller.diabetes.carbsFirst,
                limits: controller.alertContextFor(null),
              ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 5,
                    child: _ScaleCard(onScan: onScan),
                  ),
                ],
              )
            else ...[
              _DailySummaryCard(
                totals: totals,
                goals: controller.limitGoals,
                carbsFirst: controller.diabetes.carbsFirst,
                limits: controller.alertContextFor(null),
              ),
            ],

            const SizedBox(height: 40),

            // Selected Day's Meals & Recent History
            MiqdarSectionHeader(
              title: isToday ? s.recentMealsTitle : '${s.tr("Meals on", "وجبات يوم")} ${s.date(selectedDate, 'd MMM')}',
              moreLabel: s.tr('See diary', 'عرض السجل'),
              onMore: () {
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
            if (dayMeals.isEmpty)
              EmptyStateCard(icon: MiqdarIcons.restaurant, title: s.noMealsToday)
            else
              ...dayMeals.map((meal) => MealRowCard(meal: meal)),

            const SizedBox(height: 40),

            // Meal Ideas
            MiqdarSectionHeader(
              title: s.mealIdeasTitle,
              moreLabel: s.seeAll,
              onMore: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MealSuggestionsScreen()),
              ),
            ),
            if (controller.recommendationsBusy && controller.mealSuggestions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: LinearProgressIndicator(),
              )
            else if (controller.mealSuggestions.isEmpty)
              SurfaceCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MealSuggestionsScreen()),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.tr(
                          'Tell us what you like and what to avoid to get meal ideas.',
                          'أخبرنا بما تحبه وما تتجنبه لتحصل على أفكار للوجبات.',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(MiqdarIcons.chevronRight, color: context.mq.inkMuted),
                  ],
                ),
              )
            else if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: controller.mealSuggestions
                    .take(2)
                    .map(
                      (suggestion) => Expanded(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 12),
                          child: SuggestionCardWidget(
                            suggestion: suggestion,
                            compact: true,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              )
            else
              ...controller.mealSuggestions.take(2).map(
                    (suggestion) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SuggestionCardWidget(
                        suggestion: suggestion,
                        compact: true,
                      ),
                    ),
                  ),
          ],
        );
      },
    );
  }
}

class _DailySummaryCard extends StatelessWidget {
  const _DailySummaryCard({
    required this.totals,
    required this.goals,
    this.carbsFirst = false,
    this.limits = const AlertContext(),
  });

  final NutritionValues totals;
  final NutritionGoals goals;

  /// Decides which bars turn red when passed, and the daily carb limit in diabetes mode.
  final AlertContext limits;

  /// Diabetes mode: today's carbs lead the card, in grams and portions.
  final bool carbsFirst;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.mq;
    bool harmful(String key) => isHarmfulLimit(key, goals, limits);
    final carbLimit = limits.dayCarbLimitG ?? goals.carbohydrates;
    final carbsOver = passesHarmfulLimit('carbohydrate_g', totals.carbohydrates, carbLimit, goals: goals, context: limits);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.dailyIntakeTitle, style: MiqdarType.titleCard.copyWith(color: c.ink)),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GoalsScreen()),
                ),
                child: Text(s.tr('Goals', 'الأهداف')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (carbsFirst) ...[
            Text(s.tr('Carbs today', 'كربوهيدرات اليوم'), style: MiqdarType.label.copyWith(color: c.inkMuted)),
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: totals.carbohydrates.toStringAsFixed(0),
                  style: MiqdarType.numberLg.copyWith(color: carbsOver ? c.danger : c.ink),
                ),
                TextSpan(
                  text: ' ${s.unitG} · ${s.tr('${formatPortions(carbPortions(totals.carbohydrates))} portions', '${formatPortions(carbPortions(totals.carbohydrates))} حصص')}',
                  style: MiqdarType.bodyStrong.copyWith(color: c.inkMuted),
                ),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              RadialCalorieMeter(
                consumed: totals.calories,
                target: goals.calories,
                trackingOnly: goals.trackingOnly,
                harmfulWhenOver: harmful('calories_kcal'),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _MacroProgressLine(
                      label: s.protein,
                      harmfulWhenOver: harmful('protein_g'),
                      value: totals.protein,
                      target: goals.protein,
                      unit: s.unitG,
                      color: c.nProtein,
                      trackingOnly: goals.trackingOnly,
                    ),
                    _MacroProgressLine(
                      label: s.carbs,
                      harmfulWhenOver: harmful('carbohydrate_g'),
                      value: totals.carbohydrates,
                      target: carbLimit,
                      unit: s.unitG,
                      color: c.nCarbs,
                      trackingOnly: goals.trackingOnly,
                    ),
                    _MacroProgressLine(
                      label: s.fat,
                      harmfulWhenOver: harmful('fat_g'),
                      value: totals.fat,
                      target: goals.fat,
                      unit: s.unitG,
                      color: c.nFat,
                      trackingOnly: goals.trackingOnly,
                    ),
                    _MacroProgressLine(
                      // The limit is on free sugar; days with older meals count their total sugar.
                      label: totals.freeSugar != null && !totals.countsTotalSugar ? s.freeSugar : s.sugar,
                      harmfulWhenOver: harmful('sugar_g'),
                      value: totals.sugarForLimit,
                      target: goals.sugar,
                      unit: s.unitG,
                      color: c.nSugar,
                      trackingOnly: goals.trackingOnly,
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: NutrientTile(
                    label: s.fiber,
                    value: totals.fiber.toStringAsFixed(1),
                    unit: s.unitG,
                    goal: goals.trackingOnly ? null : '/ ${goals.fiber.toStringAsFixed(0)} ${s.unitG}',
                    color: c.nFiber,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NutrientTile(
                    label: s.sodium,
                    value: totals.sodium.toStringAsFixed(0),
                    unit: s.unitMg,
                    goal: goals.trackingOnly ? null : '/ ${goals.sodium.toStringAsFixed(0)} ${s.unitMg}',
                    color: c.nSodium,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NutrientTile(
                    label: s.potassium,
                    value: totals.potassium.toStringAsFixed(0),
                    unit: s.unitMg,
                    goal: goals.trackingOnly ? null : '/ ${goals.potassium.toStringAsFixed(0)} ${s.unitMg}',
                    color: c.nPotassium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroProgressLine extends StatelessWidget {
  const _MacroProgressLine({
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
    required this.color,
    this.trackingOnly = false,
    this.isLast = false,
    this.harmfulWhenOver = false,
  });

  /// Red, not orange, once passed: a limit that is harmful to pass.
  final bool harmfulWhenOver;
  final String label;
  final double value;
  final double target;
  final String unit;
  final Color color;
  final bool trackingOnly;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.mq;
    final hasGoal = target > 0 && !trackingOnly;
    final ratio = (hasGoal && !value.isNaN) ? (value / target).clamp(0.0, 1.0) : 0.0;
    final isOver = hasGoal && value > target;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NutrientDot(color: color),
                const SizedBox(width: 6),
                Text(label, style: MiqdarType.label.copyWith(color: c.ink)),
                const SizedBox(width: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: hasGoal ? value.toStringAsFixed(0) : value.toStringAsFixed(1),
                        style: MiqdarType.label.copyWith(color: c.ink),
                      ),
                      TextSpan(
                        text: hasGoal ? ' / ${target.toStringAsFixed(0)} $unit' : ' $unit',
                        style: MiqdarType.label.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (hasGoal) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: c.surfaceSunken,
                color: isOver ? (harmfulWhenOver ? c.danger : c.accent) : color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The scale in the wide layout, where there is no floating bar over the content.
class _ScaleCard extends StatelessWidget {
  const _ScaleCard({required this.onScan});
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.mq;
    final controller = MiqdarScope.of(context);
    final scale = controller.scaleDevice;
    final state = scale.visualState;
    final hasWeight = state == ScaleVisualState.connected || state == ScaleVisualState.simulated;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: ScaleStatusLabel(state: state)),
              if (!hasWeight)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DeviceSettingsScreen()),
                  ),
                  child: Text(s.tr('Connect', 'اتصال')),
                ),
            ],
          ),
          if (hasWeight) ...[
            const SizedBox(height: 16),
            Row(
              textDirection: TextDirection.ltr,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(scale.effectiveWeightG.toStringAsFixed(0), style: MiqdarType.numberXl.copyWith(color: c.ink)),
                Text(
                  ' ${s.unitG}',
                  style: MiqdarType.titleCard.copyWith(fontSize: 20, color: c.inkMuted),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onScan,
            icon: const Icon(MiqdarIcons.add),
            label: Text(s.startCapture),
          ),
        ],
      ),
    );
  }
}

/// A meal suggestion led by its numbers. The nutrient dots are its only color.
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
    final c = context.mq;
    final controller = MiqdarScope.of(context);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.displayName(s.isAr),
                      style: MiqdarType.titleCard.copyWith(fontSize: 19, height: 24 / 19, color: c.ink),
                    ),
                    if (suggestion.nameAr.isNotEmpty && !s.isAr)
                      Text(suggestion.nameAr, style: MiqdarType.body.copyWith(color: c.inkMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${suggestion.portionG.toStringAsFixed(0)} ${s.unitG}',
                style: MiqdarType.bodyStrong.copyWith(fontSize: 14, color: c.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
              children: [
                Expanded(
                  child: _IdeaStat(
                    value: suggestion.nutrients.calories.toStringAsFixed(0),
                    label: s.unitKcal,
                    color: c.nCalories,
                  ),
                ),
                Expanded(
                  child: _IdeaStat(
                    value: suggestion.nutrients.protein.toStringAsFixed(1),
                    unit: s.unitG,
                    label: s.protein,
                    color: c.nProtein,
                  ),
                ),
                if (!compact)
                  Expanded(
                    child: _IdeaStat(
                      value: suggestion.nutrients.sodium.toStringAsFixed(0),
                      unit: s.unitMg,
                      label: s.sodium,
                      color: c.nSodium,
                    ),
                  ),
              ],
          ),
          if (!s.isAr || hasArabicText(suggestion.why.join())) ...[
            const SizedBox(height: 16),
            Text(
              suggestion.why.join(' · '),
              maxLines: compact ? 2 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: MiqdarType.body.copyWith(fontSize: 14, height: 21 / 14, color: c.inkMuted),
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: MiqdarType.bodyStrong,
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
              icon: const Icon(MiqdarIcons.add, size: 20),
              label: Text(s.tr('Log This', 'سجّل هذه الوجبة')),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdeaStat extends StatelessWidget {
  const _IdeaStat({required this.value, this.unit, required this.label, required this.color});
  final String value;
  final String? unit;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.mq;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: MiqdarType.numberLg.copyWith(fontSize: 24, height: 28 / 24, letterSpacing: -0.3, color: c.ink),
                ),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: MiqdarType.label.copyWith(fontSize: 14, color: c.inkMuted),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            NutrientDot(color: color, size: 8),
            const SizedBox(width: 6),
            Flexible(
                child: Text(label, style: MiqdarType.body.copyWith(fontSize: 13, height: 18 / 13, color: c.inkMuted))),
          ],
        ),
      ],
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
  // A photo already in memory shows on the first frame, which lets it fly between screens.
  Uint8List? cached;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (photo == null) _load();
  }

  @override
  void didUpdateWidget(covariant MealPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mealId != widget.mealId) _load();
  }

  void _load() {
    final controller = MiqdarScope.of(context);
    cached = controller.cachedMealPhoto(widget.mealId);
    photo = controller.mealPhoto(widget.mealId);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
        future: photo,
        initialData: cached,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          return bytes == null ? widget.fallback : widget.builder(bytes);
        },
      );
}

/// One saved meal, directly on `bg` with no box. The food photo is the color.
class MealRowCard extends StatelessWidget {
  const MealRowCard({super.key, required this.meal});
  final MealEntry meal;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.mq;
    final name = meal.displayName(s.isAr);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MealDetailScreen(meal: meal)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.square(
                dimension: 64,
                child: MealPhoto(
                  mealId: meal.id,
                  builder: (bytes) => MealPhotoHero(mealId: meal.id, bytes: bytes, radius: 12, cacheWidth: 200),
                  fallback: ColoredBox(
                    color: c.surface,
                    child: Center(
                      child: Text(
                        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                        style: MiqdarType.titleCard.copyWith(fontSize: 22, color: c.inkMuted),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MiqdarType.titleCard.copyWith(fontSize: 16, color: c.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${s.mealTypeLabel(meal.mealType)} · ${s.date(meal.eatenAt.toLocal(), 'h:mm a')} · ${meal.weightG.toStringAsFixed(0)} ${s.unitG}',
                    style: MiqdarType.body.copyWith(fontSize: 13, height: 18 / 13, color: c.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (MiqdarScope.of(context).diabetes.carbsFirst)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    meal.nutrients.isMissing('carbohydrate_g')
                        ? s.tr('Unknown', 'غير معروف')
                        : s.tr('${meal.nutrients.carbohydrates.toStringAsFixed(0)} g carbs',
                            '${meal.nutrients.carbohydrates.toStringAsFixed(0)} غ كربوهيدرات'),
                    style: MiqdarType.titleCard.copyWith(fontSize: 16, color: c.ink),
                  ),
                  Text('${meal.nutrients.calories.toStringAsFixed(0)} ${s.unitKcal}',
                      style: MiqdarType.caption.copyWith(color: c.inkMuted)),
                ],
              )
            else
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: meal.nutrients.calories.toStringAsFixed(0),
                    style: MiqdarType.titleCard.copyWith(color: c.ink),
                  ),
                  TextSpan(
                    text: ' ${s.unitKcal}',
                    style: MiqdarType.caption.copyWith(fontWeight: FontWeight.w700, color: c.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
