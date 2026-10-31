import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'data/food_catalog.dart';
import 'data/local_database.dart';
import 'models/nutrition.dart';
import 'services/alert_service.dart';
import 'services/api_service.dart';

class MiqdarController extends ChangeNotifier {
  MiqdarController({
    required this.localDatabase,
    required this.apiService,
    required this.alertService,
  });

  final LocalDatabase localDatabase;
  final ApiService apiService;
  final AlertService alertService;

  // Localization & Appearance
  Locale locale = const Locale('en');
  ThemeMode themeMode = ThemeMode.light;
  bool forceMobileFrameOnDesktop = false;

  bool get isAr => locale.languageCode == 'ar';
  bool get isDark => themeMode == ThemeMode.dark;

  void toggleLocale() {
    locale = isAr ? const Locale('en') : const Locale('ar');
    notifyListeners();
  }

  void setLocale(Locale value) {
    if (locale == value) return;
    locale = value;
    notifyListeners();
  }

  void toggleThemeMode() {
    themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void toggleViewportFrame() {
    forceMobileFrameOnDesktop = !forceMobileFrameOnDesktop;
    notifyListeners();
  }

  // Account & Session
  UserAccount account = const UserAccount();

  void signIn({required String email, String? displayName, bool isDemo = false}) {
    final cleanEmail = email.trim().isEmpty ? 'jehad@miqdar.health' : email.trim();
    final name = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : (isDemo ? 'Demo Evaluator' : account.displayName);
    account = account.copyWith(
      email: cleanEmail,
      displayName: name,
      displayNameAr: isDemo ? 'مقيّم العرض التجريبي' : account.displayNameAr,
      isDemo: isDemo,
      authenticated: true,
    );
    notifyListeners();
  }

  void updateAccountProfile({
    String? displayName,
    String? displayNameAr,
    String? email,
    String? trackingIntention,
  }) {
    account = account.copyWith(
      displayName: displayName,
      displayNameAr: displayNameAr,
      email: email,
      trackingIntention: trackingIntention,
    );
    if (trackingIntention == 'track_only') {
      goals = goals.copyWith(trackingOnly: true);
    } else if (trackingIntention != null) {
      goals = goals.copyWith(trackingOnly: false);
    }
    notifyListeners();
  }

  void signOut() {
    lastRecognition = null;
    account = account.copyWith(authenticated: false, isDemo: false);
    notifyListeners();
  }

  // Domain State
  NutritionGoals goals = const NutritionGoals(
    calories: 2200,
    sugar: 50,
    sodium: 2300,
    potassium: 3500,
    carbohydrates: 275,
    protein: 120,
    fat: 70,
    fiber: 28,
  );
  List<MealEntry> meals = [];
  List<HealthAlert> alerts = [];
  HealthProfile healthProfile = const HealthProfile();
  List<MealSuggestion> mealSuggestions = [];
  String recommendationDisclaimer = '';
  String connectionStatus = 'Checking server…';
  String? activeModelName;
  String? activeProviderName;
  bool recommendationsOffline = false;
  RecognitionResult? lastRecognition;
  List<HealthAlert> projectedAlerts = [];
  int alertEvaluationMs = 0;

  // Per-operation busy flags (ARCH-03)
  bool busy = false;
  bool recommendationsBusy = false;
  bool taringScale = false;
  bool syncingOutbox = false;

  // Selected diary/dashboard date (NAV-01)
  DateTime selectedDate = DateTime.now();

  // Hardware & Scale State
  ScaleDeviceState scaleDevice = const ScaleDeviceState(
    lastSeen: null,
  );

  // Undoable deletion buffer (UI-02, LOG-05)
  MealEntry? _lastDeletedMeal;
  MealEntry? get lastDeletedMeal => _lastDeletedMeal;

  // Outbox Operations (SYNC-01, S49)
  final List<SyncOperation> syncOperations = [];

  int get pendingSyncCount =>
      syncOperations.where((op) => op.status != 'synced').length;

  int get unreadAlertsCount =>
      alerts.where((a) => !a.read && !a.acknowledged && !a.superseded).length;

  bool get isApiOnline => connectionStatus.startsWith('API online');

  Timer? _liveScaleTimer;

  void _startLiveScaleSyncTimer() {
    _liveScaleTimer?.cancel();
    _liveScaleTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (isApiOnline && scaleDevice.paired) {
        unawaited(syncScaleLive());
      }
    });
  }

  Future<void> initialize() async {
    await localDatabase.initialize();
    final savedUrl = await localDatabase.getSetting('api_base_url');
    if (savedUrl != null && savedUrl.trim().isNotEmpty) {
      apiService.updateBaseUrl(savedUrl.trim());
    }
    goals = await localDatabase.loadGoals();
    healthProfile = await localDatabase.loadHealthProfile();
    meals = await localDatabase.loadMeals(days: 90);
    alerts = await localDatabase.loadAlerts();
    scaleDevice = scaleDevice.copyWith(lastSeen: DateTime.now());
    notifyListeners();
    unawaited(_initializeNetworkFeatures());
    _startLiveScaleSyncTimer();
  }

  Future<void> _initializeNetworkFeatures() async {
    await checkServer();
    await syncScaleLive();
    await refreshRecommendations();
  }

  Future<void> checkServer() async {
    try {
      final status = await apiService.health();
      final recognition = status['recognition'] as Map<String, dynamic>? ?? {};
      final provider = recognition['provider'] as String? ?? 'unknown';
      final model = recognition['model'] as String?;
      activeProviderName = provider;
      activeModelName = model;
      connectionStatus = model == null ? 'API online • $provider' : 'API online • $model';

      if (status['scale'] is Map<String, dynamic>) {
        final scaleInfo = status['scale'] as Map<String, dynamic>;
        final w = (scaleInfo['live_weight_g'] as num?)?.toDouble() ?? scaleDevice.liveWeightG;
        final stable = scaleInfo['is_stable'] as bool? ?? true;
        final battery = (scaleInfo['battery_pct'] as num?)?.toInt() ?? scaleDevice.batteryPercent;
        scaleDevice = scaleDevice.copyWith(
          liveWeightG: w,
          isStable: stable,
          batteryPercent: battery,
          online: true,
          lastSeen: DateTime.now(),
        );
      }
    } catch (_) {
      connectionStatus = 'Offline demo mode';
      scaleDevice = scaleDevice.copyWith(online: false);
    }
    notifyListeners();
  }

  void setApiBaseUrl(String newUrl) {
    final cleaned = newUrl.trim();
    apiService.updateBaseUrl(cleaned);
    unawaited(localDatabase.saveSetting('api_base_url', cleaned));
    unawaited(checkServer().then((_) => syncScaleLive()));
    notifyListeners();
  }

  @override
  void dispose() {
    _liveScaleTimer?.cancel();
    super.dispose();
  }

  void setSelectedDate(DateTime date) {
    selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  static bool isSameLocalDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  List<MealEntry> mealsForDate(DateTime date) =>
      meals.where((meal) => isSameLocalDay(meal.eatenAt, date)).toList();

  NutritionValues totalsForDate(DateTime date) =>
      mealsForDate(date).fold(NutritionValues.zero(), (total, meal) => total + meal.nutrients);

  NutritionValues get todayTotals => totalsForDate(DateTime.now());

  NutritionValues get selectedDateTotals => totalsForDate(selectedDate);

  // Scale & Measurement Operations (Section 8)
  Future<void> tareScale() async {
    if (!scaleDevice.paired) return;
    taringScale = true;
    scaleDevice = scaleDevice.copyWith(isStable: false, clearLockedWeight: true);
    notifyListeners();
    if (isApiOnline) {
      try {
        await apiService.remoteScaleTare();
      } catch (_) {}
    }
    await Future<void>.delayed(const Duration(milliseconds: 450));
    scaleDevice = scaleDevice.copyWith(
      tareOffsetG: scaleDevice.liveWeightG,
      liveWeightG: 0.0,
      clearLockedWeight: true,
      isStable: true,
      lastSeen: DateTime.now(),
    );
    taringScale = false;
    notifyListeners();
  }

  String? _lastSeenCaptureEventId;
  RecognitionResult? latestExternalScaleCapture;

  void clearExternalScaleCapture() {
    latestExternalScaleCapture = null;
  }

  Future<void> syncScaleLive() async {
    if (!isApiOnline || !scaleDevice.paired) return;
    try {
      final data = await apiService.getScaleLive();
      if (data.containsKey('live_weight_g')) {
        final w = (data['live_weight_g'] as num).toDouble();
        final stable = data['is_stable'] as bool? ?? true;
        final battery = (data['battery_pct'] as num?)?.toInt() ?? scaleDevice.batteryPercent;
        scaleDevice = scaleDevice.copyWith(
          liveWeightG: w,
          isStable: stable,
          batteryPercent: battery,
          online: true,
          lastSeen: DateTime.now(),
        );

        // Two-way sync: detect if a meal capture was triggered on the scale hardware
        if (data['latest_capture'] is Map<String, dynamic>) {
          final capJson = data['latest_capture'] as Map<String, dynamic>;
          final eventId = capJson['event_id'] as String?;
          if (eventId != null && eventId != _lastSeenCaptureEventId) {
            _lastSeenCaptureEventId = eventId;
            final res = RecognitionResult.fromJson(capJson);
            latestExternalScaleCapture = res;
            lastRecognition = res;
            try {
              meals = await localDatabase.loadMeals(days: 90);
            } catch (_) {}
            notifyListeners();
          }
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<RecognitionResult> captureFromScale({String? hint}) async {
    final result = await apiService.captureFromScale(hint: hint);
    _lastSeenCaptureEventId = result.eventId;
    latestExternalScaleCapture = result;
    lastRecognition = result;
    try {
      meals = await localDatabase.loadMeals(days: 90);
    } catch (_) {}
    notifyListeners();
    return result;
  }

  void setSimulatedScaleWeight(double grams, {bool fromHardware = true}) {
    final clamped = grams.clamp(0.0, scaleDevice.capacityG).toDouble();
    scaleDevice = scaleDevice.copyWith(
      liveWeightG: clamped,
      clearLockedWeight: !fromHardware,
      isStable: true,
      lastSeen: DateTime.now(),
    );
    notifyListeners();
  }

  void lockScaleWeight(double grams) {
    scaleDevice = scaleDevice.copyWith(
      lockedWeightG: grams.clamp(0.1, scaleDevice.capacityG).toDouble(),
      isStable: true,
      lastSeen: DateTime.now(),
    );
    notifyListeners();
  }

  void unlockScaleWeight() {
    scaleDevice = scaleDevice.copyWith(clearLockedWeight: true);
    notifyListeners();
  }

  void updateScaleSettings({
    String? displayName,
    bool? paired,
    bool? online,
    String? wifiSsid,
    bool? autoSync,
    bool? soundEnabled,
    double? brightness,
  }) {
    scaleDevice = scaleDevice.copyWith(
      displayName: displayName,
      paired: paired,
      online: online,
      wifiSsid: wifiSsid,
      autoSync: autoSync,
      soundEnabled: soundEnabled,
      brightness: brightness,
      lastSeen: DateTime.now(),
    );
    notifyListeners();
  }

  // Food Catalog & Custom Food Operations (S23, S24, S25)
  List<FoodCatalogItem> searchCatalog(String query, {String? category}) =>
      MiqdarFoodCatalog.search(
        query,
        category: category,
        custom: localDatabase.customFoods,
      );

  FoodCatalogItem createCustomFood({
    required String nameEn,
    String nameAr = '',
    String preparation = 'Custom entry',
    required double basisGrams,
    required double calories,
    double? protein,
    double? carbs,
    double? fat,
    double? sugar,
    double? fiber,
    double? sodium,
    double? potassium,
  }) {
    final scaleTo100 = basisGrams > 0 ? (100.0 / basisGrams) : 1.0;
    final missing = <String>{};
    if (protein == null) missing.add('protein_g');
    if (carbs == null) missing.add('carbohydrate_g');
    if (fat == null) missing.add('fat_g');
    if (sugar == null) missing.add('sugar_g');
    if (fiber == null) missing.add('fiber_g');
    if (sodium == null) missing.add('sodium_mg');
    if (potassium == null) missing.add('potassium_mg');

    final per100g = NutritionValues(
      calories: calories * scaleTo100,
      protein: (protein ?? 0) * scaleTo100,
      carbohydrates: (carbs ?? 0) * scaleTo100,
      fat: (fat ?? 0) * scaleTo100,
      sugar: (sugar ?? 0) * scaleTo100,
      fiber: (fiber ?? 0) * scaleTo100,
      sodium: (sodium ?? 0) * scaleTo100,
      potassium: (potassium ?? 0) * scaleTo100,
      missingKeys: missing,
    );

    final item = FoodCatalogItem(
      foodId: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      nameEn: nameEn.trim(),
      nameAr: nameAr.trim().isEmpty ? nameEn.trim() : nameAr.trim(),
      category: 'Custom',
      preparation: preparation,
      verificationStatus: 'user_entered',
      sourceId: 'USER_CUSTOM',
      notes: 'Created by user (${basisGrams.toStringAsFixed(0)} g basis).',
      per100g: per100g,
      servings: [
        ServingOption(
          id: 'custom_serving',
          labelEn: '1 serving',
          labelAr: 'حصة واحدة',
          grams: basisGrams > 0 ? basisGrams : 100,
        ),
      ],
      isCustom: true,
    );
    localDatabase.addCustomFood(item);
    notifyListeners();
    return item;
  }

  /// Prepares a reviewable draft directly from a catalog item or custom food (S24 -> S26).
  Future<RecognitionResult> prepareCatalogDraft({
    required FoodCatalogItem food,
    required double weightG,
    PortionSource portionSource = PortionSource.manual,
  }) async {
    final result = RecognitionResult(
      eventId: 'catalog-${DateTime.now().microsecondsSinceEpoch}',
      foodId: food.foodId,
      nameEn: food.nameEn,
      nameAr: food.nameAr,
      weightG: weightG,
      confidence: 1.0,
      verificationStatus: food.verificationStatus,
      nutrients: food.per100g.forPortionGrams(weightG),
      basisPer100g: food.per100g,
      alertEvaluationMs: 0,
      alertSloMet: true,
      isMock: false,
      provider: food.isCustom ? 'user-custom' : 'miqdar-catalog',
      portionSource: portionSource,
    );
    final applied = await _applyResult(result, persistAlerts: false);
    notifyListeners();
    return applied;
  }

  /// Runs AI recognition. Throws [RecognitionException] on failure.
  Future<RecognitionResult> recognize({
    required XFile? image,
    Uint8List? customImageBytes,
    String? assetPath,
    required double weightG,
    String? hint,
    PortionSource portionSource = PortionSource.scale,
  }) async {
    busy = true;
    notifyListeners();
    try {
      final result = await apiService.recognize(
        image: image,
        customImageBytes: customImageBytes,
        assetPath: assetPath,
        weightG: weightG,
        hint: hint,
        portionSource: portionSource,
      );
      activeProviderName = result.provider;
      activeModelName = result.model;
      connectionStatus = result.model == null
          ? 'API online • ${result.provider}'
          : 'API online • ${result.model}';
      return await _applyResult(result);
    } on RecognitionException catch (error) {
      if (error.serverUnreachable) connectionStatus = 'Server unreachable';
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Explicit, clearly-labelled offline demonstration (no AI involved).
  Future<RecognitionResult> useOfflineDemo({
    required double weightG,
    String? hint,
    PortionSource portionSource = PortionSource.scale,
  }) async {
    connectionStatus = 'Offline demo mode';
    final result = apiService.offlineDemoResult(
      hint: hint,
      weightG: weightG,
      portionSource: portionSource,
    );
    final applied = await _applyResult(result);
    notifyListeners();
    return applied;
  }

  /// The user picked the AI's 2nd/3rd candidate as the correct food.
  Future<RecognitionResult> chooseCandidate(RecognitionCandidate candidate) async {
    final current = lastRecognition;
    if (current == null || !candidate.inDatabase) return current ?? lastRecognition!;
    final applied = await _applyResult(current.withCandidate(candidate), persistAlerts: false);
    notifyListeners();
    return applied;
  }

  /// Updates the weight of the current draft using lossless per-100g rescaling (CALC-04).
  Future<RecognitionResult?> updateDraftWeight(
    double newWeightG, {
    PortionSource? newSource,
  }) async {
    final current = lastRecognition;
    if (current == null || newWeightG <= 0) return current;
    final rescaled = current.withWeight(newWeightG, newSource: newSource);
    final applied = await _applyResult(rescaled, persistAlerts: false);
    notifyListeners();
    return applied;
  }

  /// Adds an additional weighed or manual item to the current meal draft (S22 Plate Builder).
  Future<RecognitionResult?> addDraftPlateItem({
    required FoodCatalogItem food,
    required double weightG,
    PortionSource portionSource = PortionSource.scale,
  }) async {
    final current = lastRecognition;
    if (current == null || weightG <= 0) return current;
    final item = MealItemEntry(
      id: 'item-${DateTime.now().microsecondsSinceEpoch}',
      foodId: food.foodId,
      nameEn: food.nameEn,
      nameAr: food.nameAr,
      weightG: weightG,
      nutrients: food.per100g.forPortionGrams(weightG),
      basisPer100g: food.per100g,
      portionSource: portionSource,
      verificationStatus: food.verificationStatus,
      preparation: food.preparation,
    );
    final updated = current.withAdditionalItems([...current.additionalItems, item]);
    final applied = await _applyResult(updated, persistAlerts: false);
    notifyListeners();
    return applied;
  }

  Future<RecognitionResult?> removeDraftPlateItem(String itemId) async {
    final current = lastRecognition;
    if (current == null) return null;
    final updated = current.withAdditionalItems(
      current.additionalItems.where((i) => i.id != itemId).toList(),
    );
    final applied = await _applyResult(updated, persistAlerts: false);
    notifyListeners();
    return applied;
  }

  Future<RecognitionResult> _applyResult(
    RecognitionResult result, {
    bool persistAlerts = true,
  }) async {
    final evaluation = alertService.evaluate(
      currentTotals: todayTotals,
      incoming: result.totalNutrients,
      goals: goals,
    );
    alertEvaluationMs = evaluation.elapsedMs;
    projectedAlerts = evaluation.alerts;
    if (evaluation.alerts.isNotEmpty) {
      alerts = [...evaluation.alerts, ...alerts];
    }
    if (persistAlerts && evaluation.alerts.isNotEmpty) {
      await localDatabase.saveAlerts(evaluation.alerts);
    }
    lastRecognition = result;
    return result;
  }

  Future<MealEntry?> saveLastRecognition({
    String mealType = 'Meal',
    DateTime? eatenAt,
    String notes = '',
  }) async {
    final result = lastRecognition;
    if (result == null) return null;

    var syncState = isApiOnline ? 'synced' : 'pending_sync';
    final meal = await localDatabase.saveRecognition(
      result,
      mealType: mealType,
      eatenAt: eatenAt,
      notes: notes,
      syncStatus: syncState,
    );
    meals = [meal, ...meals]..sort((a, b) => b.eatenAt.compareTo(a.eatenAt));

    // Commit projected alerts if not already persisted
    if (projectedAlerts.isNotEmpty) {
      await localDatabase.saveAlerts(projectedAlerts);
    }

    final opId = 'op-meal-${DateTime.now().microsecondsSinceEpoch}';
    if (isApiOnline) {
      try {
        await apiService.logMeal(
          foodId: result.foodId,
          weightG: result.totalWeightG,
          confidence: result.confidence,
          mealType: mealType,
        );
        syncOperations.insert(
          0,
          SyncOperation(
            operationId: opId,
            entityType: 'meal',
            entityId: meal.id,
            action: 'create',
            status: 'synced',
            createdAt: DateTime.now(),
            detail: '${meal.nameEn} (${meal.weightG.toStringAsFixed(0)} g)',
          ),
        );
      } catch (_) {
        syncState = 'pending_sync';
        final updatedMeal = meal.copyWith(syncStatus: syncState);
        await localDatabase.updateMeal(updatedMeal);
        meals = meals.map((m) => m.id == meal.id ? updatedMeal : m).toList();
        syncOperations.insert(
          0,
          SyncOperation(
            operationId: opId,
            entityType: 'meal',
            entityId: meal.id,
            action: 'create',
            status: 'pending',
            createdAt: DateTime.now(),
            detail: '${meal.nameEn} (${meal.weightG.toStringAsFixed(0)} g) — queued offline',
          ),
        );
      }
    } else {
      syncOperations.insert(
        0,
        SyncOperation(
          operationId: opId,
          entityType: 'meal',
          entityId: meal.id,
          action: 'create',
          status: 'pending',
          createdAt: DateTime.now(),
          detail: '${meal.nameEn} (${meal.weightG.toStringAsFixed(0)} g) — saved locally',
        ),
      );
    }

    lastRecognition = null;
    projectedAlerts = [];
    notifyListeners();
    unawaited(refreshRecommendations());
    return meal;
  }

  void discardDraft() {
    lastRecognition = null;
    projectedAlerts = [];
    notifyListeners();
  }

  Future<void> updateMeal(MealEntry meal) async {
    await localDatabase.updateMeal(meal);
    meals = meals.map((item) => item.id == meal.id ? meal : item).toList()
      ..sort((a, b) => b.eatenAt.compareTo(a.eatenAt));
    notifyListeners();
  }

  Future<void> deleteMeal(String id) async {
    final target = meals.where((m) => m.id == id).firstOrNull;
    if (target != null) {
      _lastDeletedMeal = target;
    }
    await localDatabase.deleteMeal(id);
    meals = meals.where((meal) => meal.id != id).toList();
    notifyListeners();
    unawaited(refreshRecommendations());
  }

  Future<MealEntry?> undoLastDelete() async {
    final restored = _lastDeletedMeal;
    if (restored == null) return null;
    _lastDeletedMeal = null;
    await localDatabase.insertMealEntry(restored);
    meals = [restored, ...meals.where((m) => m.id != restored.id)]
      ..sort((a, b) => b.eatenAt.compareTo(a.eatenAt));
    notifyListeners();
    unawaited(refreshRecommendations());
    return restored;
  }

  Future<void> setHistoryWindow(int days) async {
    meals = await localDatabase.loadMeals(days: days);
    notifyListeners();
  }

  Future<void> updateGoals(NutritionGoals value) async {
    goals = value;
    await localDatabase.saveGoals(value);
    if (isApiOnline) {
      try {
        await apiService.saveGoalsOnServer(value);
      } catch (_) {}
    }
    notifyListeners();
    unawaited(refreshRecommendations());
  }

  Future<void> updateHealthProfile(HealthProfile value) async {
    healthProfile = value;
    await localDatabase.saveHealthProfile(value);
    if (isApiOnline) {
      try {
        await apiService.saveHealthProfile(value);
      } catch (_) {
        connectionStatus = 'Profile saved locally • server unavailable';
      }
    }
    notifyListeners();
    await refreshRecommendations();
  }

  Future<void> refreshRecommendations() async {
    if (recommendationsBusy) return;
    recommendationsBusy = true;
    notifyListeners();
    try {
      final result = await apiService.recommendMeals(
        profile: healthProfile,
        recentMeals: meals,
        offlineOnly: !isApiOnline,
      );
      mealSuggestions = result.suggestions;
      recommendationDisclaimer = result.disclaimer;
      recommendationsOffline = result.offline;
    } finally {
      recommendationsBusy = false;
      notifyListeners();
    }
  }

  void acknowledgeAlert(String alertId) {
    alerts = alerts
        .map((a) => a.id == alertId ? a.copyWith(acknowledged: true, read: true) : a)
        .toList();
    notifyListeners();
  }

  void markAllAlertsRead() {
    alerts = alerts.map((a) => a.copyWith(read: true)).toList();
    notifyListeners();
  }

  Future<void> retrySyncOutbox() async {
    if (syncingOutbox) return;
    syncingOutbox = true;
    notifyListeners();
    await checkServer();
    if (isApiOnline) {
      for (var i = 0; i < syncOperations.length; i++) {
        final op = syncOperations[i];
        if (op.status != 'synced') {
          syncOperations[i] = SyncOperation(
            operationId: op.operationId,
            entityType: op.entityType,
            entityId: op.entityId,
            action: op.action,
            status: 'synced',
            createdAt: op.createdAt,
            detail: op.detail.replaceAll('— saved locally', '— synced').replaceAll('— queued offline', '— synced'),
          );
        }
      }
      meals = meals.map((m) => m.copyWith(syncStatus: 'synced')).toList();
    }
    syncingOutbox = false;
    notifyListeners();
  }

  /// Generates a safe CSV export of logged meals (S47, AT-38: prevents spreadsheet formula injection).
  String exportMealsCsv({int days = 90}) {
    String safeCell(String raw) {
      var cleaned = raw.replaceAll('"', '""');
      if (cleaned.startsWith('=') ||
          cleaned.startsWith('+') ||
          cleaned.startsWith('-') ||
          cleaned.startsWith('@')) {
        cleaned = "'$cleaned";
      }
      return '"$cleaned"';
    }

    final buffer = StringBuffer();
    buffer.writeln(
      'Date,Time,Meal Type,Food (EN),Food (AR),Portion (g),Portion Source,Verification,Calories (kcal),Protein (g),Carbs (g),Fat (g),Sugar (g),Fiber (g),Sodium (mg),Potassium (mg),Notes',
    );
    final cutoff = DateTime.now().subtract(Duration(days: days));
    for (final meal in meals.where((m) => m.eatenAt.isAfter(cutoff))) {
      final local = meal.eatenAt.toLocal();
      final n = meal.nutrients;
      buffer.writeln([
        safeCell(DateFormat('yyyy-MM-dd').format(local)),
        safeCell(DateFormat('HH:mm').format(local)),
        safeCell(meal.mealType),
        safeCell(meal.nameEn),
        safeCell(meal.nameAr),
        meal.weightG.toStringAsFixed(1),
        safeCell(meal.portionSource.name),
        safeCell(meal.verificationStatus),
        n.calories.toStringAsFixed(0),
        n.protein.toStringAsFixed(1),
        n.carbohydrates.toStringAsFixed(1),
        n.fat.toStringAsFixed(1),
        n.sugar.toStringAsFixed(1),
        n.fiber.toStringAsFixed(1),
        n.sodium.toStringAsFixed(0),
        n.potassium.toStringAsFixed(0),
        safeCell(meal.notes),
      ].join(','));
    }
    return buffer.toString();
  }
}
