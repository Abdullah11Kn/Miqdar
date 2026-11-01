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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: MiqdarColors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MiqdarColors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.science_rounded, color: MiqdarColors.warning, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.demoBanner,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: MiqdarColors.warning,
                        ),
                      ),
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
                            ? TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? MiqdarColors.darkMuted : MiqdarColors.muted,
                              )
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
                // Inbox / Notices button with badge
                Badge(
                  isLabelVisible: controller.unreadAlertsCount > 0,
                  label: Text('${controller.unreadAlertsCount}'),
                  backgroundColor: MiqdarColors.warning,
                  child: IconButton.outlined(
                    tooltip: s.navNotices,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: Text(s.navNotices)),
                          body: const SafeArea(child: AlertsScreen()),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.notifications_none_rounded, size: 20),
                  ),
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
                  icon: const Icon(Icons.chevron_left_rounded),
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
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: s.tr('Next day', 'اليوم التالي'),
                  onPressed: isToday
                      ? null
                      : () => controller.setSelectedDate(
                            selectedDate.add(const Duration(days: 1)),
                          ),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Resume Draft Banner if an unsaved recognition draft exists (NAV-06, PRD-06)
            if (controller.lastRecognition != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: SurfaceCard(
                  color: MiqdarColors.softGreen,
                  borderColor: MiqdarColors.mintBorder,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note_rounded, color: MiqdarColors.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.tr('Meal not saved yet', 'وجبة لم تُحفظ بعد'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: MiqdarColors.emeraldDeep,
                              ),
                            ),
                            Text(
                              '${s.isAr && controller.lastRecognition!.nameAr.isNotEmpty ? controller.lastRecognition!.nameAr : controller.lastRecognition!.nameEn} • ${controller.lastRecognition!.totalWeightG.toStringAsFixed(0)} ${s.unitG}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: MiqdarColors.emeraldDeep,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                RecognitionResultScreen(result: controller.lastRecognition!),
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
                  isToday
                      ? s.recentMealsTitle
                      : '${s.tr("Meals on", "وجبات يوم")} ${s.date(selectedDate, 'd MMM')}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
              SurfaceCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.restaurant_outlined,
                      size: 36,
                      color: MiqdarColors.muted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.noMealsToday,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...dayMeals.map((meal) => MealRowCard(meal: meal)),


            const SizedBox(height: 24),

            // Meal Ideas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: MiqdarColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      s.mealIdeasTitle,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MealSuggestionsScreen()),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 16),
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
                    const Icon(Icons.restaurant_menu_rounded, color: MiqdarColors.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        s.tr(
                          'Tell us what you like and what to avoid to get meal ideas.',
                          'أخبرنا بما تحبه وما تتجنبه لتحصل على أفكار للوجبات.',
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
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
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                s.dailyIntakeTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GoalsScreen()),
                ),
                icon: const Icon(Icons.tune_rounded, size: 15),
                label: Text(
                  s.tr('Goals', 'الأهداف'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              RadialCalorieMeter(
                consumed: totals.calories,
                target: goals.calories,
                trackingOnly: goals.trackingOnly,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _MacroProgressLine(
                      label: s.protein,
                      value: totals.protein,
                      target: goals.protein,
                      unit: s.unitG,
                      color: MiqdarColors.proteinAccent,
                      trackingOnly: goals.trackingOnly,
                    ),
                    _MacroProgressLine(
                      label: s.carbs,
                      value: totals.carbohydrates,
                      target: goals.carbohydrates,
                      unit: s.unitG,
                      color: MiqdarColors.carbsAccent,
                      trackingOnly: goals.trackingOnly,
                    ),
                    _MacroProgressLine(
                      label: s.fat,
                      value: totals.fat,
                      target: goals.fat,
                      unit: s.unitG,
                      color: MiqdarColors.fatAccent,
                      trackingOnly: goals.trackingOnly,
                    ),
                    _MacroProgressLine(
                      label: s.sugar,
                      value: totals.sugar,
                      target: goals.sugar,
                      unit: s.unitG,
                      color: MiqdarColors.sugarAccent,
                      trackingOnly: goals.trackingOnly,
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 26),
          // Secondary Micronutrients Row (Fiber, Sodium, Potassium)
          Row(
            children: [
              Expanded(
                child: _SecondaryNutrientChip(
                  label: s.fiber,
                  value: '${totals.fiber.toStringAsFixed(1)} ${s.unitG}',
                  target: goals.trackingOnly ? '' : '/ ${goals.fiber.toStringAsFixed(0)} ${s.unitG}',
                  color: MiqdarColors.fiberAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SecondaryNutrientChip(
                  label: s.sodium,
                  value: '${totals.sodium.toStringAsFixed(0)} ${s.unitMg}',
                  target: goals.trackingOnly ? '' : '/ ${goals.sodium.toStringAsFixed(0)} ${s.unitMg}',
                  color: MiqdarColors.sodiumAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SecondaryNutrientChip(
                  label: s.potassium,
                  value: '${totals.potassium.toStringAsFixed(0)} ${s.unitMg}',
                  target: goals.trackingOnly ? '' : '/ ${goals.potassium.toStringAsFixed(0)} ${s.unitMg}',
                  color: MiqdarColors.potassiumAccent,
                ),
              ),
            ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ratio = (target > 0 && !trackingOnly && !value.isNaN)
        ? (value / target).clamp(0.0, 1.0)
        : 0.0;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : MiqdarColors.dark,
                  ),
                ),
              ),
              Text(
                trackingOnly || target <= 0
                    ? '${value.toStringAsFixed(1)} $unit'
                    : '${value.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} $unit',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: color.withValues(alpha: 0.14),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryNutrientChip extends StatelessWidget {
  const _SecondaryNutrientChip({
    required this.label,
    required this.value,
    required this.target,
    required this.color,
  });

  final String label;
  final String value;
  final String target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : MiqdarColors.dark,
            ),
          ),
          if (target.isNotEmpty) Text(target, style: const TextStyle(fontSize: 10)),
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
    final controller = MiqdarScope.of(context);
    final scale = controller.scaleDevice;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: MiqdarColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.scale_rounded,
                color: scale.online ? const Color(0xFFD1FAE5) : MiqdarColors.warning,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  scale.online
                      ? s.tr(
                          'On the scale: ${scale.effectiveWeightG.toStringAsFixed(0)} g',
                          'على الميزان: ${scale.effectiveWeightG.toStringAsFixed(0)} غ',
                        )
                      : s.tr('Scale not connected', 'الميزان غير متصل'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!scale.online)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DeviceSettingsScreen()),
                  ),
                  child: Text(s.tr('Connect', 'اتصال')),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: MiqdarColors.emeraldDeep,
              minimumSize: const Size(0, 48),
            ),
            onPressed: onScan,
            icon: const Icon(Icons.add_rounded),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: MiqdarColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.restaurant_rounded, color: MiqdarColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.displayName(s.isAr),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: isDark ? Colors.white : MiqdarColors.dark,
                      ),
                    ),
                    if (suggestion.nameAr.isNotEmpty && !s.isAr)
                      Text(suggestion.nameAr, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: MiqdarColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${suggestion.portionG.toStringAsFixed(0)} ${s.unitG}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: MiqdarColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MiniBadge(
                text: '${suggestion.nutrients.calories.toStringAsFixed(0)} ${s.unitKcal}',
                color: MiqdarColors.caloriesAccent,
              ),
              _MiniBadge(
                text: '${suggestion.nutrients.protein.toStringAsFixed(1)} ${s.unitG} ${s.protein}',
                color: MiqdarColors.proteinAccent,
              ),
              if (!compact)
                _MiniBadge(
                  text: '${suggestion.nutrients.sodium.toStringAsFixed(0)} ${s.unitMg} ${s.sodium}',
                  color: MiqdarColors.sodiumAccent,
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (!s.isAr || hasArabicText(suggestion.why.join()))
            Text(
              suggestion.why.join(' • '),
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
              icon: const Icon(Icons.edit_calendar_rounded, size: 16),
              label: Text(s.tr('Log This', 'سجّل هذه الوجبة')),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = meal.displayName(s.isAr);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SurfaceCard(
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MealDetailScreen(meal: meal)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox.square(
                dimension: 52,
                child: MealPhoto(
                  mealId: meal.id,
                  builder: (bytes) => Image.memory(bytes, fit: BoxFit.cover, cacheWidth: 160),
                  fallback: ColoredBox(
                    color: MiqdarColors.primary.withValues(alpha: 0.12),
                    child: Center(
                      child: Text(
                        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: MiqdarColors.primary,
                        ),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isDark ? Colors.white : MiqdarColors.dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${s.mealTypeLabel(meal.mealType)} • ${s.date(meal.eatenAt.toLocal(), 'h:mm a')} • ${meal.weightG.toStringAsFixed(0)} ${s.unitG}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  meal.nutrients.calories.toStringAsFixed(0),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: MiqdarColors.primary,
                  ),
                ),
                Text(
                  s.unitKcal,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
