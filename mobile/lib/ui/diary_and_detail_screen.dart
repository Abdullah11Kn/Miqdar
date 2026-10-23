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

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int days = 90;
  String mealTypeFilter = 'All';
  final searchCtrl = TextEditingController();

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    final query = searchCtrl.text.trim().toLowerCase();

    final filtered = controller.meals.where((meal) {
      if (mealTypeFilter != 'All' && meal.mealType != mealTypeFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return meal.nameEn.toLowerCase().contains(query) ||
          meal.nameAr.contains(query) ||
          meal.mealType.toLowerCase().contains(query);
    }).toList();

    // Group meals by local diary date (YYYY-MM-DD)
    final grouped = <String, List<MealEntry>>{};
    for (final meal in filtered) {
      final key = DateFormat('yyyy-MM-dd').format(meal.eatenAt.toLocal());
      grouped.putIfAbsent(key, () => []).add(meal);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.tr('Nutrition Diary & History', 'سجل الوجبات والتاريخ الغذائي'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    s.tr(
                      'Day-by-day grouped timeline across your 90-day window (S27).',
                      'عرض زمني مصنف يوماً بيوم خلال نافذة 90 يوماً (S27).',
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: s.navInsights,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TrendsScreen()),
              ),
              icon: const Icon(Icons.query_stats_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Undo Banner if a meal was just deleted (UI-02, LOG-05)
        if (controller.lastDeletedMeal != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SurfaceCard(
              color: MiqdarColors.warningBg,
              borderColor: MiqdarColors.warning.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.restore_from_trash_rounded, color: MiqdarColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${s.tr("Deleted", "تم حذف")}: ${controller.lastDeletedMeal!.displayName(s.isAr)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: MiqdarColors.dark,
                      ),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: controller.undoLastDelete,
                    child: Text(s.tr('Undo', 'تراجع')),
                  ),
                ],
              ),
            ),
          ),

        // Date Range Segmented Control
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 7, label: Text(s.tr('7 Days', '7 أيام'))),
            ButtonSegment(value: 30, label: Text(s.tr('30 Days', '30 يوماً'))),
            ButtonSegment(value: 90, label: Text(s.tr('90 Days', '90 يوماً'))),
          ],
          selected: {days},
          onSelectionChanged: (selection) async {
            setState(() => days = selection.first);
            await controller.setHistoryWindow(days);
          },
        ),
        const SizedBox(height: 12),

        // Search & Meal Type Filter
        TextField(
          controller: searchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: s.tr('Filter logged meals…', 'ابحث في الوجبات المسجلة…'),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: searchCtrl.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      searchCtrl.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Breakfast', 'Lunch', 'Dinner', 'Snack'].map((type) {
              final selected = mealTypeFilter == type;
              final label = type == 'All' ? s.tr('All Meals', 'كل الوجبات') : s.mealTypeLabel(type);
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => setState(() => mealTypeFilter = type),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Summary Bar
        SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: MiqdarColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${filtered.length} ${s.tr("meals across", "وجبة عبر")} ${sortedKeys.length} ${s.tr("logged days", "أيام مسجلة")}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '$days-${s.tr("day window", "يوم")}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MiqdarColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (sortedKeys.isEmpty)
          SurfaceCard(
            child: Column(
              children: [
                const Icon(Icons.event_busy_rounded, size: 36, color: MiqdarColors.muted),
                const SizedBox(height: 8),
                Text(
                  s.tr('No meals match your current filter.', 'لا توجد وجبات مطابقة للفلتر الحالي.'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          )
        else
          ...sortedKeys.map((dateKey) {
            final dayMeals = grouped[dateKey]!;
            final dayDate = DateTime.parse(dateKey);
            final dayTotals = dayMeals.fold(
              NutritionValues.zero(),
              (sum, m) => sum + m.nutrients,
            );
            final isToday = MiqdarController.isSameLocalDay(dayDate, DateTime.now());

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isToday
                              ? '${s.tr("Today", "اليوم")} • ${DateFormat('d MMM yyyy').format(dayDate)}'
                              : DateFormat('EEE, d MMM yyyy').format(dayDate),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${dayTotals.calories.toStringAsFixed(0)} ${s.unitKcal} • P ${dayTotals.protein.toStringAsFixed(0)}${s.unitG} • C ${dayTotals.carbohydrates.toStringAsFixed(0)}${s.unitG} • F ${dayTotals.fat.toStringAsFixed(0)}${s.unitG}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: MiqdarColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...dayMeals.map((meal) => MealRowCard(meal: meal)),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class MealDetailScreen extends StatelessWidget {
  const MealDetailScreen({super.key, required this.meal});
  final MealEntry meal;

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    // Look up live meal in case it was just edited
    final currentMeal = controller.meals.where((m) => m.id == meal.id).firstOrNull ?? meal;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.tr('Meal Details', 'تفاصيل الوجبة')),
        actions: [
          IconButton(
            tooltip: s.tr('Repeat as new draft (LOG-04)', 'تكرار الوجبة كمسودة جديدة'),
            onPressed: () async {
              final catalogItem = MiqdarFoodCatalog.findByIdOrLabel(currentMeal.foodId) ??
                  FoodCatalogItem(
                    foodId: currentMeal.foodId,
                    nameEn: currentMeal.nameEn,
                    nameAr: currentMeal.nameAr,
                    category: 'Logged',
                    preparation: 'Copied snapshot',
                    verificationStatus: currentMeal.verificationStatus,
                    sourceId: 'DIARY_REPEAT',
                    per100g: currentMeal.resolvedBasisPer100g,
                  );
              final draft = await controller.prepareCatalogDraft(
                food: catalogItem,
                weightG: currentMeal.weightG,
                portionSource: PortionSource.manual,
              );
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => RecognitionResultScreen(result: draft),
                ),
              );
            },
            icon: const Icon(Icons.copy_all_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                // Hero Header Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: MiqdarColors.heroGradient,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Text(
                            currentMeal.displayName(s.isAr).isEmpty
                                ? '?'
                                : currentMeal.displayName(s.isAr).characters.first.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '${s.mealTypeLabel(currentMeal.mealType)} • ${currentMeal.portionSource.label(s.isAr)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFD1FAE5),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              currentMeal.displayName(s.isAr),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              currentMeal.secondaryName(s.isAr),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFFD1FAE5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currentMeal.nutrients.calories.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: MiqdarColors.mintGlow,
                            ),
                          ),
                          Text(
                            s.unitKcal,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Metadata row
                SurfaceCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 18, color: MiqdarColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${DateFormat('EEE, d MMM yyyy • h:mm a').format(currentMeal.eatenAt.toLocal())} • ${currentMeal.weightG.toStringAsFixed(0)} ${s.unitG}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: currentMeal.syncStatus == 'synced'
                              ? MiqdarColors.softGreen
                              : MiqdarColors.warningBg,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          currentMeal.syncStatus == 'synced'
                              ? s.tr('Synced', 'متزامن')
                              : s.tr('Saved Locally', 'محفوظ محلياً'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: currentMeal.syncStatus == 'synced'
                                ? MiqdarColors.primary
                                : MiqdarColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                AiVerificationBadge(
                  verificationStatus: currentMeal.verificationStatus,
                  portionSource: currentMeal.portionSource,
                ),

                if (currentMeal.notes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SurfaceCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.notes_rounded, color: MiqdarColors.primary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(currentMeal.notes)),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),
                Text(
                  s.tr('Nutrition Facts Snapshot (LOG-02)', 'ملخص القيم الغذائية المحفوظة (LOG-02)'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                NutrientGrid2x4(
                  values: currentMeal.nutrients,
                  goals: controller.goals,
                ),

                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _showEditMealSheet(context, controller, currentMeal),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(s.tr('Edit Portion / Meal', 'تعديل الوزن أو الوجبة')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MiqdarColors.danger,
                          side: BorderSide(color: MiqdarColors.danger.withValues(alpha: 0.4)),
                        ),
                        onPressed: () => _confirmDelete(context, controller, currentMeal),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(s.tr('Delete Meal', 'حذف الوجبة')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditMealSheet(
    BuildContext context,
    MiqdarController controller,
    MealEntry currentMeal,
  ) async {
    final s = S.of(context);
    var selectedType = currentMeal.mealType;
    var selectedDate = currentMeal.eatenAt.toLocal();
    final weightController = TextEditingController(
      text: currentMeal.weightG.toStringAsFixed(currentMeal.weightG % 1 == 0 ? 0 : 1),
    );
    final notesController = TextEditingController(text: currentMeal.notes);

    final updated = await showModalBottomSheet<MealEntry>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final parsedWeight =
              double.tryParse(normalizeDigits(weightController.text).trim()) ??
                  currentMeal.weightG;
          final previewMeal = currentMeal.rescaledToWeight(
            parsedWeight > 0 ? parsedWeight : currentMeal.weightG,
          );

          return Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              22,
              22,
              MediaQuery.viewInsetsOf(ctx).bottom + 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.tr('Edit Meal (S29)', 'تعديل الوجبة (S29)'),
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.tr(
                      'Recalculates deterministically from the immutable per-100g snapshot without rounding drift (CALC-04).',
                      'يعيد حساب القيم الغذائية بدقة من القاعدة المرجعية لكل 100 غ دون تراكم فروق التقريب (CALC-04).',
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Meal']
                            .contains(selectedType)
                        ? selectedType
                        : 'Meal',
                    decoration: InputDecoration(
                      labelText: s.tr('Meal Type', 'نوع الوجبة'),
                    ),
                    items: ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Meal']
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(s.mealTypeLabel(type)),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setSheetState(() => selectedType = value ?? selectedType),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: s.tr('Weight (g)', 'الوزن (غ)'),
                      suffixText: s.unitG,
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: s.tr('Notes', 'ملاحظات'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: MiqdarColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          DateFormat('EEE, d MMM yyyy').format(selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setSheetState(() {
                              selectedDate = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                selectedDate.hour,
                                selectedDate.minute,
                              );
                            });
                          }
                        },
                        child: Text(s.tr('Change Date', 'تغيير التاريخ')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MiqdarColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          '${previewMeal.nutrients.calories.toStringAsFixed(0)} ${s.unitKcal}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: MiqdarColors.primary,
                          ),
                        ),
                        Text('P: ${previewMeal.nutrients.protein.toStringAsFixed(1)} ${s.unitG}'),
                        Text('C: ${previewMeal.nutrients.carbohydrates.toStringAsFixed(1)} ${s.unitG}'),
                        Text('F: ${previewMeal.nutrients.fat.toStringAsFixed(1)} ${s.unitG}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () {
                      final weight = double.tryParse(
                        normalizeDigits(weightController.text).trim(),
                      );
                      if (weight == null || weight <= 0) return;
                      final rescaled = currentMeal.rescaledToWeight(
                        weight,
                        newSource: (weight - currentMeal.weightG).abs() > 0.01
                            ? PortionSource.manual
                            : currentMeal.portionSource,
                      );
                      Navigator.of(sheetContext).pop(
                        rescaled.copyWith(
                          mealType: selectedType,
                          eatenAt: selectedDate.toUtc(),
                          notes: notesController.text.trim(),
                        ),
                      );
                    },
                    child: Text(s.tr('Save Changes', 'حفظ التعديلات')),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    weightController.dispose();
    notesController.dispose();
    if (updated == null) return;
    await controller.updateMeal(updated);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MiqdarController controller,
    MealEntry currentMeal,
  ) async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.tr('Delete this meal?', 'حذف هذه الوجبة؟')),
        content: Text(
          s.tr(
            'This removes "${currentMeal.displayName(s.isAr)}" from your diary. You can undo within 8 seconds (UI-02).',
            'سيتم حذف "${currentMeal.displayName(s.isAr)}" من السجل. يمكنك التراجع خلال 8 ثوانٍ (UI-02).',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.tr('Cancel', 'إلغاء')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MiqdarColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.tr('Delete', 'حذف')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.deleteMeal(currentMeal.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(
          '${s.tr("Deleted", "تم حذف")} ${currentMeal.displayName(s.isAr)}',
        ),
        action: SnackBarAction(
          label: s.tr('Undo', 'تراجع'),
          onPressed: controller.undoLastDelete,
        ),
      ),
    );
    Navigator.of(context).pop();
  }
}
