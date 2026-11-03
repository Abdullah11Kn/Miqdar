import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app.dart';
import '../app_controller.dart';
import '../data/food_catalog.dart';
import '../l10n/strings.dart';
import '../models/nutrition.dart';
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
    final isToday = MiqdarController.isSameLocalDay(selectedDate, DateTime.now());
    final totals = controller.selectedDateTotals;
    final dayMeals = controller.mealsForDate(selectedDate);
    final goals = controller.goals;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 780;
        return ListView(
          padding: EdgeInsets.fromLTRB(isWide ? 28 : 20, 18, isWide ? 28 : 20, 32),
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

            // Header Row: Greeting + Quick Controls
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.account.hasPersonalName
                            ? _greeting(s)
                            : _greeting(s).replaceAll(RegExp(r'[,،]\s*$'), ''),
                        style: controller.account.hasPersonalName
                            ? MiqdarType.body.copyWith(color: context.mq.inkMuted)
                            : Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (controller.account.hasPersonalName) ...[
                        const SizedBox(height: 2),
                        Text(
                          controller.account.localizedName(s.isAr),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ],
                  ),
                ),
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
            const SizedBox(height: 16),

            // Day picker
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: s.tr('Previous day', 'اليوم السابق'),
                  onPressed: () => controller.setSelectedDate(
                    selectedDate.subtract(const Duration(days: 1)),
                  ),
                  icon: const Icon(MiqdarIcons.chevronLeft),
                ),
                TextButton(
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
                    isToday ? s.tr('Today', 'اليوم') : s.date(selectedDate, 'EEE, d MMM'),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: s.tr('Next day', 'اليوم التالي'),
                  onPressed: isToday
                      ? null
                      : () => controller.setSelectedDate(
                            selectedDate.add(const Duration(days: 1)),
                          ),
                  icon: const Icon(MiqdarIcons.chevronRight),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Resume Draft Banner if an unsaved recognition draft exists (NAV-06, PRD-06)
            if (controller.lastRecognition != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: SurfaceCard(
                  color: context.mq.primarySoft,
                  borderColor: context.mq.primarySoft,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(MiqdarIcons.editNote, color: context.mq.ink, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.tr('Meal not saved yet', 'وجبة لم تُحفظ بعد'),
                              style: MiqdarType.bodyStrong.copyWith(color: context.mq.ink),
                            ),
                            Text(
                              '${s.isAr && controller.lastRecognition!.nameAr.isNotEmpty ? controller.lastRecognition!.nameAr : controller.lastRecognition!.nameEn} • ${controller.lastRecognition!.totalWeightG.toStringAsFixed(0)} ${s.unitG}',
                              style: MiqdarType.caption.copyWith(fontSize: 13, height: 18 / 13, color: context.mq.ink),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 16)),
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

            // Responsive Top Grid: Daily Nutrition Summary + Add Meal
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _DailySummaryCard(totals: totals, goals: goals),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 5,
                    child: _QuickCaptureHeroCard(onScan: onScan),
                  ),
                ],
              )
            else ...[
              _DailySummaryCard(totals: totals, goals: goals),
              const SizedBox(height: 16),
              _QuickCaptureHeroCard(onScan: onScan),
            ],

            const SizedBox(height: 24),

            // Selected Day's Meals & Recent History
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isToday ? s.recentMealsTitle : '${s.tr("Meals on", "وجبات يوم")} ${s.date(selectedDate, 'd MMM')}',
                  style: MiqdarType.titleSection.copyWith(color: context.mq.ink),
                ),
                TextButton(
                  onPressed: () {
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
                  child: Text(s.tr('See diary', 'عرض السجل')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (dayMeals.isEmpty)
              EmptyStateCard(icon: MiqdarIcons.restaurant, title: s.noMealsToday)
            else
              ...dayMeals.map((meal) => MealRowCard(meal: meal)),

            const SizedBox(height: 24),

            // Meal Ideas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(MiqdarIcons.autoAwesome, color: context.mq.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      s.mealIdeasTitle,
                      style: MiqdarType.titleSection.copyWith(color: context.mq.ink),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MealSuggestionsScreen()),
                  ),
                  icon: const Icon(MiqdarIcons.tune, size: 16),
                  label: Text(s.seeAll),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                    Icon(MiqdarIcons.restaurantMenu, color: context.mq.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        s.tr(
                          'Tell us what you like and what to avoid to get meal ideas.',
                          'أخبرنا بما تحبه وما تتجنبه لتحصل على أفكار للوجبات.',
                        ),
                      ),
                    ),
                    const Icon(MiqdarIcons.chevronRight),
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
                      padding: const EdgeInsets.only(bottom: 10),
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
  });

  final NutritionValues totals;
  final NutritionGoals goals;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.mq;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.dailyIntakeTitle, style: MiqdarType.titleCard.copyWith(color: c.ink)),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GoalsScreen()),
                ),
                icon: const Icon(MiqdarIcons.tune, size: 18),
                label: Text(s.tr('Goals', 'الأهداف')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              RadialCalorieMeter(
                consumed: totals.calories,
                target: goals.calories,
                trackingOnly: goals.trackingOnly,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _MacroProgressLine(
                      label: s.protein,
                      value: totals.protein,
                      target: goals.protein,
                      unit: s.unitG,
                      color: c.nProtein,
                      trackingOnly: goals.trackingOnly,
                    ),
                    _MacroProgressLine(
                      label: s.carbs,
                      value: totals.carbohydrates,
                      target: goals.carbohydrates,
                      unit: s.unitG,
                      color: c.nCarbs,
                      trackingOnly: goals.trackingOnly,
                    ),
                    _MacroProgressLine(
                      label: s.fat,
                      value: totals.fat,
                      target: goals.fat,
                      unit: s.unitG,
                      color: c.nFat,
                      trackingOnly: goals.trackingOnly,
                    ),
                    _MacroProgressLine(
                      label: s.sugar,
                      value: totals.sugar,
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
  });

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
                Text(label, style: MiqdarType.label.copyWith(fontSize: 14, color: c.ink)),
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
                        style: MiqdarType.label.copyWith(fontWeight: FontWeight.w500, color: c.inkMuted),
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
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: c.surfaceSunken,
                color: isOver ? c.accent : color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickCaptureHeroCard extends StatelessWidget {
  const _QuickCaptureHeroCard({required this.onScan});
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.mq;
    final controller = MiqdarScope.of(context);
    final scale = controller.scaleDevice;
    final state = scale.visualState;
    final hasWeight = state == ScaleVisualState.connected || state == ScaleVisualState.simulated;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: c.heroGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(MiqdarIcons.scale, color: hasWeight ? c.onHero : c.accentOnHero, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  switch (state) {
                    ScaleVisualState.disconnected => s.tr('Scale not connected', 'الميزان غير متصل'),
                    ScaleVisualState.fault => s.tr('Weight sensor not responding', 'حساس الوزن لا يستجيب'),
                    _ => s.tr(
                        'On the scale: ${scale.effectiveWeightG.toStringAsFixed(0)} g',
                        'على الميزان: ${scale.effectiveWeightG.toStringAsFixed(0)} غ',
                      ),
                  },
                  style: MiqdarType.titleCard.copyWith(color: c.onHero),
                ),
              ),
              if (!hasWeight)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: c.onHero),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DeviceSettingsScreen()),
                  ),
                  child: Text(
                    s.tr('Connect', 'اتصال'),
                    style: TextStyle(decoration: TextDecoration.underline, decorationColor: context.mq.onHero),
                  ),
                ),
            ],
          ),
          if (state == ScaleVisualState.simulated) ...[
            const SizedBox(height: 4),
            Text(
              s.tr('Simulated scale, not real food', 'ميزان محاكاة، ليس طعاماً حقيقياً'),
              style: MiqdarType.body.copyWith(fontSize: 14, color: c.onHeroMuted),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: c.onHero, foregroundColor: c.hero),
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
                      style: MiqdarType.titleSection.copyWith(fontSize: 19, height: 24 / 19, color: c.ink),
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.symmetric(horizontal: BorderSide(color: c.border)),
            ),
            child: Row(
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
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 16)),
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
                  style: TextStyle(fontSize: 24, height: 28 / 24, fontWeight: FontWeight.w700, color: c.ink),
                ),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.inkMuted),
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
                child: Text(label, style: MiqdarType.label.copyWith(fontWeight: FontWeight.w500, color: c.inkMuted))),
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

class MealRowCard extends StatelessWidget {
  const MealRowCard({super.key, required this.meal});
  final MealEntry meal;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = context.mq;
    final name = meal.displayName(s.isAr);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MealDetailScreen(meal: meal)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox.square(
                dimension: 52,
                child: MealPhoto(
                  mealId: meal.id,
                  builder: (bytes) => Image.memory(bytes, fit: BoxFit.cover, cacheWidth: 160),
                  fallback: ColoredBox(
                    color: c.surfaceSunken,
                    child: Center(
                      child: Text(
                        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                        style: MiqdarType.titleSection.copyWith(color: c.ink),
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
                  const SizedBox(height: 2),
                  Text(
                    '${s.mealTypeLabel(meal.mealType)} • ${s.date(meal.eatenAt.toLocal(), 'h:mm a')} • ${meal.weightG.toStringAsFixed(0)} ${s.unitG}',
                    style: MiqdarType.caption.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: meal.nutrients.calories.toStringAsFixed(0),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: ' ${s.unitKcal}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
                style: TextStyle(color: c.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
