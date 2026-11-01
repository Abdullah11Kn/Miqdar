import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.onAddMeal});

  final VoidCallback? onAddMeal;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
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
      return meal.nameEn.toLowerCase().contains(query) || meal.nameAr.contains(query);
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
        Text(
          s.navDiary,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),

        if (controller.meals.isEmpty)
          SurfaceCard(
            child: Column(
              children: [
                MeasureDial(
                  size: 88,
                  progress: 0,
                  strokeWidth: 5,
                  ticks: 0,
                  child: Icon(MiqIcons.forkKnife, size: 30, color: Miq.of(context).muted),
                ),
                const SizedBox(height: 14),
                Text(
                  s.tr('Your diary is empty', 'سجلك فارغ'),
                  style: MiqType.display(26, color: Miq.of(context).text),
                ),
                const SizedBox(height: 4),
                Text(
                  s.tr('Meals you save will appear here.', 'ستظهر هنا الوجبات التي تحفظها.'),
                  textAlign: TextAlign.center,
                ),
                if (widget.onAddMeal != null) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: widget.onAddMeal,
                    icon: const Icon(MiqIcons.plus),
                    label: Text(s.navAdd),
                  ),
                ],
              ],
            ),
          )
        else ...[
          TextField(
            controller: searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: s.tr('Search your meals', 'ابحث في وجباتك'),
              prefixIcon: const Icon(MiqIcons.magnifyingGlass),
              suffixIcon: searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: s.tr('Clear', 'مسح'),
                      onPressed: () {
                        searchCtrl.clear();
                        setState(() {});
                      },
                      icon: const Icon(MiqIcons.x),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Breakfast', 'Lunch', 'Dinner', 'Snack'].map((type) {
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(type == 'All' ? s.tr('All', 'الكل') : s.mealTypeLabel(type)),
                    selected: mealTypeFilter == type,
                    onSelected: (_) => setState(() => mealTypeFilter = type),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          if (sortedKeys.isEmpty)
            SurfaceCard(
              child: Column(
                children: [
                  const Icon(MiqIcons.magnifyingGlassMinus, size: 36, color: MiqdarColors.muted),
                  const SizedBox(height: 8),
                  Text(
                    s.tr('No meals match your search.', 'لا توجد وجبات تطابق بحثك.'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          else
            ...sortedKeys.map((dateKey) {
              final dayMeals = grouped[dateKey]!;
              final dayDate = DateTime.parse(dateKey);
              final dayCalories = dayMeals.fold(0.0, (sum, m) => sum + m.nutrients.calories);
              final isToday = MiqdarController.isSameLocalDay(dayDate, DateTime.now());

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isToday
                                  ? s.tr('Today', 'اليوم')
                                  : s.date(dayDate, 'EEE, d MMM yyyy'),
                              style: MiqType.display(22, color: Miq.of(context).text),
                            ),
                          ),
                          Text(
                            '${dayCalories.toStringAsFixed(0)} ${s.unitKcal}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Miq.of(context).muted),
                          ),
                        ],
                      ),
                    ),
                    Ledger(children: dayMeals.map((meal) => MealRowCard(meal: meal)).toList()),
                  ],
                ),
              );
            }),
        ],
      ],
    );
  }
}

class MealDetailScreen extends StatelessWidget {
  const MealDetailScreen({super.key, required this.meal});
  final MealEntry meal;

  Future<void> _logAgain(BuildContext context, MiqdarController controller, MealEntry currentMeal) async {
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
  }

  @override
  Widget build(BuildContext context) {
    final controller = MiqdarScope.of(context);
    final s = S.of(context);
    // Look up live meal in case it was just edited
    final currentMeal = controller.meals.where((m) => m.id == meal.id).firstOrNull ?? meal;
    final secondaryName = currentMeal.secondaryName(s.isAr);

    return Scaffold(
      appBar: AppBar(title: Text(s.mealTypeLabel(currentMeal.mealType))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                MealPhoto(
                  mealId: currentMeal.id,
                  builder: (bytes) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Image.memory(bytes, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentMeal.displayName(s.isAr),
                            style: MiqType.display(34, color: Miq.of(context).text, height: 1.15),
                          ),
                          if (secondaryName.isNotEmpty && secondaryName != currentMeal.displayName(s.isAr))
                            Text(secondaryName, style: const TextStyle(fontSize: 13.5)),
                          const SizedBox(height: 4),
                          Text(
                            '${s.date(currentMeal.eatenAt.toLocal(), 'EEE, d MMM • h:mm a')} • ${currentMeal.weightG.toStringAsFixed(0)} ${s.unitG}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currentMeal.nutrients.calories.toStringAsFixed(0),
                          style: MiqType.display(56, color: Miq.of(context).accent, height: 1),
                        ),
                        Text(s.unitKcal, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
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
                        const Icon(MiqIcons.note, color: MiqdarColors.primary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(currentMeal.notes)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
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
                        icon: const Icon(MiqIcons.pencilSimple),
                        label: Text(s.tr('Edit', 'تعديل')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _logAgain(context, controller, currentMeal),
                        icon: const Icon(MiqIcons.arrowCounterClockwise),
                        label: Text(s.tr('Log Again', 'تسجيل مجدداً')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: MiqdarColors.danger),
                  onPressed: () => _confirmDelete(context, controller, currentMeal),
                  icon: const Icon(MiqIcons.trash),
                  label: Text(s.tr('Delete Meal', 'حذف الوجبة')),
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

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              22,
              22,
              22,
              MediaQuery.viewInsetsOf(ctx).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.tr('Edit Meal', 'تعديل الوجبة'),
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Meal']
                          .contains(selectedType)
                      ? selectedType
                      : 'Meal',
                  decoration: InputDecoration(
                    labelText: s.tr('Meal', 'الوجبة'),
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
                    labelText: s.tr('Weight', 'الوزن'),
                    suffixText: s.unitG,
                  ),
                  onChanged: (_) => setSheetState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: s.tr('Note', 'ملاحظة'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(MiqIcons.calendarBlank, size: 16, color: MiqdarColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.date(selectedDate, 'EEE, d MMM yyyy'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
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
                  child: Wrap(
                    alignment: WrapAlignment.spaceAround,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        '${previewMeal.nutrients.calories.toStringAsFixed(0)} ${s.unitKcal}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: MiqdarColors.primary,
                        ),
                      ),
                      Text('${s.protein} ${previewMeal.nutrients.protein.toStringAsFixed(1)}${s.unitG}'),
                      Text('${s.carbs} ${previewMeal.nutrients.carbohydrates.toStringAsFixed(1)}${s.unitG}'),
                      Text('${s.fat} ${previewMeal.nutrients.fat.toStringAsFixed(1)}${s.unitG}'),
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
          );
        },
      ),
    );
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
            '"${currentMeal.displayName(s.isAr)}" will be removed from your diary.',
            'ستُحذف "${currentMeal.displayName(s.isAr)}" من سجلك.',
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
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await controller.deleteMeal(currentMeal.id);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        persist: false,
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
    navigator.pop();
  }
}
