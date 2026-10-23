import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
            // Demo Workspace Banner (S60, PRD-09)
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
                        _greeting(s),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? MiqdarColors.darkMuted : MiqdarColors.muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        controller.account.localizedName(s.isAr),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                // Language pill
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: controller.toggleLocale,
                  child: Text(
                    controller.isAr ? 'EN' : 'عربي',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                ),
                const SizedBox(width: 8),
                // Theme toggle
                IconButton.outlined(
                  tooltip: s.tr('Switch theme', 'تبديل المظهر'),
                  onPressed: controller.toggleThemeMode,
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 8),
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

            // Telemetry & Scale Status Strip (DEV-02)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: controller.checkServer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: controller.isApiOnline
                          ? MiqdarColors.primary.withValues(alpha: 0.11)
                          : MiqdarColors.warning.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: controller.isApiOnline
                            ? MiqdarColors.primary.withValues(alpha: 0.3)
                            : MiqdarColors.warning.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 9,
                          color: controller.isApiOnline
                              ? MiqdarColors.emeraldBright
                              : MiqdarColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          controller.connectionStatus,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: controller.isApiOnline
                                ? (isDark ? MiqdarColors.mintGlow : MiqdarColors.primary)
                                : MiqdarColors.warning,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.refresh_rounded, size: 14),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DeviceSettingsScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: isDark ? MiqdarColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? MiqdarColors.darkBorder : MiqdarColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.scale_rounded,
                          size: 15,
                          color: controller.scaleDevice.paired
                              ? MiqdarColors.primary
                              : MiqdarColors.muted,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          controller.scaleDevice.paired
                              ? '${controller.scaleDevice.deviceId} • ${controller.scaleDevice.effectiveWeightG.toStringAsFixed(0)} ${s.unitG}'
                              : s.tr('No scale paired', 'الميزان غير مقترن'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                // Date Navigation Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? MiqdarColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? MiqdarColors.darkBorder : MiqdarColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        onPressed: () => controller.setSelectedDate(
                          selectedDate.subtract(const Duration(days: 1)),
                        ),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Text(
                        isToday
                            ? s.tr('Today', 'اليوم')
                            : DateFormat('d MMM yyyy').format(selectedDate),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        onPressed: isToday
                            ? null
                            : () => controller.setSelectedDate(
                                  selectedDate.add(const Duration(days: 1)),
                                ),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

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
                              s.tr('Unsaved Meal Draft Ready', 'مسودة وجبة جاهزة للمراجعة'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: MiqdarColors.emeraldDeep,
                              ),
                            ),
                            Text(
                              '${controller.lastRecognition!.nameEn} • ${controller.lastRecognition!.totalWeightG.toStringAsFixed(0)} ${s.unitG}',
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

            // Responsive Top Grid: Daily Nutrition Summary + Quick Capture Card
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

            // Smart Meal Ideas Section (S39)
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
                          'Configure dietary preferences & exclusions to generate tailored meal ideas.',
                          'أضف تفضيلاتك الغذائية والاستثناءات لتوليد اقتراحات وجبات مخصصة.',
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

            const SizedBox(height: 22),

            // Selected Day's Meals & Recent History
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isToday
                      ? s.recentMealsTitle
                      : '${s.tr("Meals on", "وجبات يوم")} ${DateFormat('d MMM').format(selectedDate)}',
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
                  child: Text('${controller.meals.length} ${s.tr("in 90d", "في 90 يوماً")}'),
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
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onScan,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(s.navAdd),
                    ),
                  ],
                ),
              )
            else
              ...dayMeals.map((meal) => MealRowCard(meal: meal)),

            if (isToday && dayMeals.length < 3 && controller.meals.length > dayMeals.length) ...[
              const SizedBox(height: 12),
              Text(
                s.tr('Earlier this week', 'في وقت سابق هذا الأسبوع'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ...controller.meals
                  .where((m) => !dayMeals.contains(m))
                  .take(3)
                  .map((meal) => MealRowCard(meal: meal)),
            ],
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
                  s.tr('Targets', 'الأهداف'),
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
                  target: '/ ${goals.fiber.toStringAsFixed(0)} ${s.unitG}',
                  color: MiqdarColors.fiberAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SecondaryNutrientChip(
                  label: s.sodium,
                  value: '${totals.sodium.toStringAsFixed(0)} ${s.unitMg}',
                  target: '/ ${goals.sodium.toStringAsFixed(0)} ${s.unitMg}',
                  color: MiqdarColors.sodiumAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SecondaryNutrientChip(
                  label: s.potassium,
                  value: '${totals.potassium.toStringAsFixed(0)} ${s.unitMg}',
                  target: '/ ${goals.potassium.toStringAsFixed(0)} ${s.unitMg}',
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
          Text(target, style: const TextStyle(fontSize: 10)),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: const BoxDecoration(gradient: MiqdarColors.heroGradient),
        child: Stack(
          children: [
            PositionedDirectional(
              end: -20,
              bottom: -20,
              width: 190,
              height: 190,
              child: Opacity(
                opacity: 0.24,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Image.asset(
                    'assets/branding/miqdar-food.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      s.tr('AI + SMART SCALE', 'ذكاء اصطناعي + ميزان ذكي'),
                      style: const TextStyle(
                        color: Color(0xFFD1FAE5),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.quickCaptureTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.quickCaptureSubtitle,
                    style: const TextStyle(
                      color: Color(0xFFD1FAE5),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: MiqdarColors.emeraldDeep,
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: onScan,
                          icon: const Icon(Icons.center_focus_strong_rounded),
                          label: Text(s.startCapture),
                        ),
                      ),
                    ],
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
              label: Text(s.tr('Review as Draft', 'مراجعة كمسودة وجبة')),
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

class MealRowCard extends StatelessWidget {
  const MealRowCard({super.key, required this.meal});
  final MealEntry meal;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SurfaceCard(
        padding: const EdgeInsets.all(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MealDetailScreen(meal: meal)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: MiqdarColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  meal.displayName(s.isAr).isEmpty
                      ? '🍽'
                      : meal.displayName(s.isAr).characters.first.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: MiqdarColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: MiqdarColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          s.mealTypeLabel(meal.mealType),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: MiqdarColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        meal.portionSource.label(s.isAr),
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                      ),
                      if (meal.syncStatus != 'synced') ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.cloud_upload_outlined, size: 13, color: MiqdarColors.warning),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meal.displayName(s.isAr),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isDark ? Colors.white : MiqdarColors.dark,
                    ),
                  ),
                  Text(
                    '${DateFormat('d MMM • h:mm a').format(meal.eatenAt.toLocal())} • ${meal.weightG.toStringAsFixed(0)} ${s.unitG}',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                ],
              ),
            ),
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
