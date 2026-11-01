import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'data/food_catalog.dart';
import 'data/local_database.dart';
import 'models/nutrition.dart';
import 'services/alert_service.dart';
import 'services/api_service.dart';

/// A capture the scale could not finish, with the photo when one was taken.
class ScaleCaptureFailure {
  const ScaleCaptureFailure({required this.error, this.imageBytes, this.weightG = 0, this.event});

  final RecognitionException error;
  final Uint8List? imageBytes;
  final double weightG;
  final Map<String, dynamic>? event;

  /// A photo that reached the app can go back to Gemini without capturing again.
  bool get canRetry => imageBytes != null && event?['status'] == 'photo';
}

/// A scale photo Gemini is still analyzing, shown to the user right away.
class PendingScaleCapture {
  const PendingScaleCapture({required this.imageBytes, required this.weightG});

  final Uint8List imageBytes;
  final double weightG;
}

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
    apiService.gemini.noteInArabic = isAr;
    _remember('locale', locale.languageCode);
    notifyListeners();
    unawaited(refreshRecommendations());
  }

  void setLocale(Locale value) {
    if (locale == value) return;
    locale = value;
    apiService.gemini.noteInArabic = isAr;
    _remember('locale', locale.languageCode);
    notifyListeners();
    unawaited(refreshRecommendations());
  }

  void toggleThemeMode() {
    themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    _remember('theme', isDark ? 'dark' : 'light');
    notifyListeners();
  }

  void toggleViewportFrame() {
    forceMobileFrameOnDesktop = !forceMobileFrameOnDesktop;
    notifyListeners();
  }

  // Account & Session
  UserAccount account = const UserAccount();

  /// True once the user has been through the welcome screen, so it only appears once.
  bool onboarded = false;

  void _remember(String key, String value) {
    unawaited(localDatabase.saveSetting(key, value).catchError((Object _) {}));
  }

  void signIn({required String email, String? displayName, bool isDemo = false}) {
    final cleanEmail = email.trim();
    final name = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : account.displayName;
    account = account.copyWith(
      email: cleanEmail,
      displayName: name,
      displayNameAr: isDemo ? 'حساب تجريبي' : account.displayNameAr,
      isDemo: isDemo,
      authenticated: true,
    );
    if (isDemo) {
      // Sample meals stay in memory and never mix with a real diary.
      meals = localDatabase.demoHistory();
    } else {
      onboarded = true;
      _remember('onboarded', '1');
      _rememberAccount();
    }
    notifyListeners();
  }

  void updateAccountProfile({
    String? displayName,
    String? displayNameAr,
    String? email,
  }) {
    account = account.copyWith(
      displayName: displayName,
      displayNameAr: displayNameAr,
      email: email,
    );
    if (!account.isDemo) _rememberAccount();
    notifyListeners();
  }

  /// Leaves the sample workspace and drops everything done inside it.
  Future<void> exitDemo() async {
    lastRecognition = null;
    projectedAlerts = [];
    _sessionPhotos.clear();
    _photoCache.clear();
    account = const UserAccount();
    goals = await localDatabase.loadGoals();
    await _reloadMeals();
    notifyListeners();
  }

  /// Deletes everything stored on this phone and returns the app to its first launch.
  Future<void> deleteAllData() async {
    await localDatabase.deleteAllData();
    lastRecognition = null;
    projectedAlerts = [];
    _lastDeletedMeal = null;
    _lastDeletedPhoto = null;
    _sessionPhotos.clear();
    _photoCache.clear();
    account = const UserAccount();
    onboarded = false;
    meals = [];
    alerts = [];
    goals = await localDatabase.loadGoals();
    healthProfile = await localDatabase.loadHealthProfile();
    notifyListeners();
    unawaited(refreshRecommendations());
  }

  void _rememberAccount() {
    _remember('account_name', account.displayName);
    _remember('account_name_ar', account.displayNameAr);
    _remember('account_email', account.email);
  }

  Future<void> _reloadMeals() async {
    try {
      meals = await localDatabase.loadMeals(days: _diaryDays);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _restorePreferences() async {
    if (await localDatabase.getSetting('locale') == 'ar') locale = const Locale('ar');
    apiService.gemini.noteInArabic = isAr;
    if (await localDatabase.getSetting('theme') == 'dark') themeMode = ThemeMode.dark;
    onboarded = await localDatabase.getSetting('onboarded') == '1';
    _lastSeenCaptureEventId = await localDatabase.getSetting('last_capture_event');
    final name = await localDatabase.getSetting('account_name');
    if (name != null && name.isNotEmpty) {
      account = account.copyWith(
        displayName: name,
        displayNameAr: await localDatabase.getSetting('account_name_ar'),
        email: await localDatabase.getSetting('account_email'),
      );
    }
  }

  // Domain State
  static const _diaryDays = 365;
  NutritionGoals goals = LocalDatabase.defaultGoals;
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

  // Per-operation busy flags (ARCH-03)
  bool busy = false;
  bool recommendationsBusy = false;
  bool taringScale = false;

  // Selected diary/dashboard date (NAV-01)
  DateTime selectedDate = DateTime.now();

  // Hardware & Scale State
  ScaleDeviceState scaleDevice = const ScaleDeviceState(
    lastSeen: null,
  );

  // Undoable deletion buffer (UI-02, LOG-05)
  MealEntry? _lastDeletedMeal;
  Uint8List? _lastDeletedPhoto;

  // Meal photos taken in the demo workspace are never written to disk.
  final Map<String, Uint8List> _sessionPhotos = {};
  final Map<String, Uint8List?> _photoCache = {};
  static const _photoCacheSize = 60;

  Future<Uint8List?> mealPhoto(String mealId) async {
    if (_sessionPhotos.containsKey(mealId)) return _sessionPhotos[mealId];
    if (_photoCache.containsKey(mealId)) return _photoCache[mealId];
    final bytes = await localDatabase.loadMealPhoto(mealId).catchError((Object _) => null);
    if (_photoCache.length >= _photoCacheSize) _photoCache.clear();
    _photoCache[mealId] = bytes;
    return bytes;
  }

  int get unreadAlertsCount =>
      alerts.where((a) => !a.read && !a.acknowledged && !a.superseded).length;

  bool get isApiOnline => connectionStatus.startsWith('API online');

  Timer? _liveScaleTimer;

  void _startLiveScaleSyncTimer() {
    _liveScaleTimer?.cancel();
    _liveScaleTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (scaleDevice.paired) {
        unawaited(syncScaleLive());
      }
    });
  }

  Future<void> initialize() async {
    await initializeDateFormatting();
    // Dates use the same digits as every other number in the app.
    DateFormat.useNativeDigitsByDefaultFor('ar', false);
    await localDatabase.initialize();
    await _restorePreferences();
    final savedUrl = await localDatabase.getSetting('api_base_url');
    // A URL passed with --dart-define=MIQDAR_API_URL wins over the one saved last time.
    const launchUrl = String.fromEnvironment('MIQDAR_API_URL');
    if (launchUrl.isEmpty && savedUrl != null && savedUrl.trim().isNotEmpty) {
      apiService.updateBaseUrl(savedUrl.trim());
    }
    goals = await localDatabase.loadGoals();
    healthProfile = await localDatabase.loadHealthProfile();
    meals = await localDatabase.loadMeals(days: _diaryDays);
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
        scaleDevice = scaleDevice.copyWith(
          liveWeightG: w,
          isStable: stable,
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
    _scaleFailures = 0;
    scaleConnectionIssue = null;
    unawaited(localDatabase.saveSetting('api_base_url', cleaned));
    unawaited(checkServer().then((_) => syncScaleLive()));
    notifyListeners();
  }

  /// Saves the scale's address and reports whether the scale actually answered there.
  Future<bool> connectToScale(String address) async {
    final cleaned = normalizeScaleAddress(address);
    apiService.updateBaseUrl(cleaned);
    _scaleFailures = 0;
    scaleConnectionIssue = null;
    scaleDevice = scaleDevice.copyWith(online: false);
    notifyListeners();
    unawaited(localDatabase.saveSetting('api_base_url', cleaned));
    await checkServer();
    // A poll to the old address may still be finishing, so give this one a few tries.
    for (var attempt = 0; attempt < 3; attempt++) {
      await syncScaleLive();
      if (scaleDevice.online) break;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    return scaleDevice.online;
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
  Future<bool> tareScale() async {
    if (!scaleDevice.paired || !scaleDevice.online) return false;
    taringScale = true;
    scaleDevice = scaleDevice.copyWith(isStable: false, clearLockedWeight: true);
    notifyListeners();
    final ok = await apiService.remoteScaleTare();
    if (ok) {
      scaleDevice = scaleDevice.copyWith(
        liveWeightG: 0.0,
        clearLockedWeight: true,
        isStable: true,
        lastSeen: DateTime.now(),
      );
    }
    taringScale = false;
    notifyListeners();
    return ok;
  }

  /// A capture older than this when first seen is history, not something to pop up.
  static const _staleCaptureAgeS = 300;

  /// One missed poll is normal over a tunnel; only a run of them means offline.
  static const _offlineAfterFailures = 3;

  String? _lastSeenCaptureEventId;
  RecognitionResult? latestExternalScaleCapture;
  ScaleCaptureFailure? latestScaleCaptureFailure;
  PendingScaleCapture? pendingScaleCapture;

  /// Note typed for the AI ("no sauce"), used by the next capture from any button.
  String aiNote = '';
  String? scaleConnectionIssue;
  String? _analyzingEventId;
  bool _scalePollInFlight = false;
  int _scaleFailures = 0;

  void clearExternalScaleCapture() {
    latestExternalScaleCapture = null;
  }

  bool get analyzingScalePhoto => _analyzingEventId != null;

  /// True from the moment a capture starts until its result is ready.
  bool get scaleWorking => busy || scaleDevice.isCapturing || analyzingScalePhoto;

  void clearPendingScaleCapture() {
    pendingScaleCapture = null;
  }

  void clearScaleCaptureFailure() {
    latestScaleCaptureFailure = null;
  }

  Future<void> syncScaleLive() async {
    if (!scaleDevice.paired || _scalePollInFlight) return;
    _scalePollInFlight = true;
    try {
      final data = await apiService.getScaleLive();
      if (data.containsKey('live_weight_g')) {
        final previous = scaleDevice;
        final wasOffline = !previous.online;
        scaleDevice = previous.copyWith(
          liveWeightG: (data['live_weight_g'] as num).toDouble(),
          isStable: data['is_stable'] as bool? ?? true,
          online: true,
          lastSeen: DateTime.now(),
          simulated: data['mode'] == 'simulated',
          autoCapture: data['auto_capture'] as bool? ?? false,
          captureState: data['capture_state'] as String? ?? 'idle',
          sensorError: data['sensor_error'] as String?,
          clearSensorError: data['sensor_error'] == null,
        );
        _scaleFailures = 0;
        final hadIssue = scaleConnectionIssue != null;
        scaleConnectionIssue = null;
        if (!isApiOnline) {
          connectionStatus = 'API online • Live Scale';
        }
        if (wasOffline) unawaited(checkServer());

        final newCapture = await _followLatestCapture(data['latest_capture']);
        if (newCapture ||
            wasOffline ||
            hadIssue ||
            previous.liveWeightG != scaleDevice.liveWeightG ||
            previous.isStable != scaleDevice.isStable ||
            previous.simulated != scaleDevice.simulated ||
            previous.captureState != scaleDevice.captureState ||
            previous.sensorError != scaleDevice.sensorError) {
          notifyListeners();
        }
      }
    } catch (error) {
      _scaleFailures++;
      scaleConnectionIssue = error is ApiException
          ? error.message
          : 'Scale not found. Check that it is on and on the same network.';
      if (scaleDevice.online && _scaleFailures >= _offlineAfterFailures) {
        scaleDevice = scaleDevice.copyWith(online: false, captureState: 'idle');
        connectionStatus = 'Server unreachable';
      }
      notifyListeners();
    } finally {
      _scalePollInFlight = false;
    }
  }

  /// Picks up captures started anywhere: the scale's button, auto-capture or this phone.
  Future<bool> _followLatestCapture(Object? summary) async {
    if (summary is! Map<String, dynamic>) return false;
    final eventId = summary['event_id'] as String?;
    if (eventId == null || eventId == _lastSeenCaptureEventId) return false;
    final ageS = (summary['age_s'] as num?)?.toDouble() ?? 0;
    if (_lastSeenCaptureEventId == null && ageS > _staleCaptureAgeS) {
      _lastSeenCaptureEventId = eventId;
      return false;
    }
    // Marked seen only after the photo arrives, so a failed download retries on the next poll.
    final event = await apiService.getLatestScaleCapture();
    if (event['status'] == 'photo') {
      unawaited(_ingestCaptureEvent(event)); // Gemini takes seconds; keep the weight live meanwhile
    } else {
      await _ingestCaptureEvent(event);
    }
    return true;
  }

  Future<RecognitionResult?> _ingestCaptureEvent(Map<String, dynamic> event) async {
    _lastSeenCaptureEventId = event['event_id'] as String?;
    // Survives a restart, so reopening the app does not offer a saved capture again.
    _remember('last_capture_event', _lastSeenCaptureEventId ?? '');
    final status = event['status'] as String?;
    if (status == 'error') {
      _publishCaptureFailure(ApiService.recognitionExceptionFromJson(event), event);
      return null;
    }
    if (status == 'photo') {
      return _analyzeScalePhoto(event);
    }
    final result = RecognitionResult.fromJson(event);
    await _acceptScaleCapture(result);
    return result;
  }

  void _publishCaptureFailure(RecognitionException error, Map<String, dynamic> event) {
    final image = event['image_base64'] as String?;
    latestScaleCaptureFailure = ScaleCaptureFailure(
      error: error,
      imageBytes: image == null || image.isEmpty ? null : base64Decode(image),
      weightG: (event['weight_g'] as num?)?.toDouble() ?? 0,
      event: event,
    );
  }

  Future<void> retryScaleAnalysis(ScaleCaptureFailure failure) async {
    final event = failure.event;
    if (event != null && failure.canRetry) await _analyzeScalePhoto(event);
  }

  /// Sends the draft's photo back to Gemini with what the user says it really is.
  Future<RecognitionResult?> correctDraftWithGemini(String correction) async {
    final current = lastRecognition;
    final image = current?.imageBytes;
    if (current == null || image == null || image.isEmpty) return current;
    final result = await apiService.gemini.analyze(
      imageBytes: image,
      weightG: current.weightG,
      correction: correction,
      eventId: current.eventId,
      portionSource: current.portionSource,
    );
    final applied = await _applyResult(result.withAdditionalItems(current.additionalItems));
    notifyListeners();
    return applied;
  }

  /// Sends the scale's weighed photo to Gemini. Runs apart from the live poll, so the
  /// weight keeps updating. A newer capture makes this one's answer irrelevant.
  Future<RecognitionResult?> _analyzeScalePhoto(Map<String, dynamic> event) async {
    final eventId = event['event_id'] as String?;
    final image = event['image_base64'] as String?;
    final imageBytes = image == null ? Uint8List(0) : base64Decode(image);
    final weightG = (event['weight_g'] as num?)?.toDouble() ?? 0;
    final note = (event['ai_note'] as String?) ?? aiNote.trim();
    event['ai_note'] = note;
    aiNote = '';
    _analyzingEventId = eventId;
    if (imageBytes.isNotEmpty) {
      pendingScaleCapture = PendingScaleCapture(imageBytes: imageBytes, weightG: weightG);
    }
    notifyListeners();
    try {
      final result = await apiService.gemini.analyze(
        imageBytes: imageBytes,
        weightG: weightG,
        hint: note.isEmpty ? null : note,
        eventId: eventId,
      );
      if (_analyzingEventId != eventId) return null;
      await _acceptScaleCapture(result);
      unawaited(apiService.postScaleResult(result));
      return result;
    } on RecognitionException catch (error) {
      if (_analyzingEventId != eventId) return null;
      // An empty plate settling on the scale is normal, not worth interrupting the user for.
      if (!(event['source'] == 'auto' && error.code == 'NOT_FOOD')) {
        _publishCaptureFailure(error, event);
      }
      return null;
    } finally {
      if (_analyzingEventId == eventId) _analyzingEventId = null;
      notifyListeners();
    }
  }

  Future<void> _acceptScaleCapture(RecognitionResult result) async {
    await _applyResult(result);
    activeProviderName = result.provider;
    activeModelName = result.model;
    latestExternalScaleCapture = result;
  }

  /// Asks the scale to capture. The review screen opens from [latestExternalScaleCapture]
  /// (see MainShell), the same way as for captures started on the scale itself.
  Future<RecognitionResult?> captureFromScale({String? hint}) async {
    busy = true;
    notifyListeners();
    try {
      final event = await apiService.captureFromScale(hint: hint);
      if (event['event_id'] == _lastSeenCaptureEventId) return null; // the live poll got there first
      return await _ingestCaptureEvent(event);
    } on RecognitionException catch (error) {
      if (error.eventId != null && error.eventId != _lastSeenCaptureEventId) {
        try {
          await _ingestCaptureEvent(await apiService.getLatestScaleCapture());
        } catch (_) {}
      }
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
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
    final applied = await _applyResult(result);
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
    final applied = await _applyResult(current.withCandidate(candidate));
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
    final applied = await _applyResult(rescaled);
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
    final applied = await _applyResult(updated);
    notifyListeners();
    return applied;
  }

  Future<RecognitionResult?> removeDraftPlateItem(String itemId) async {
    final current = lastRecognition;
    if (current == null) return null;
    final updated = current.withAdditionalItems(
      current.additionalItems.where((i) => i.id != itemId).toList(),
    );
    final applied = await _applyResult(updated);
    notifyListeners();
    return applied;
  }

  /// Alerts stay a projection until the meal is saved, so moving the weight slider or
  /// discarding a draft leaves no trace in the alert history.
  Future<RecognitionResult> _applyResult(RecognitionResult result) async {
    final evaluation = alertService.evaluate(
      currentTotals: todayTotals,
      incoming: result.totalNutrients,
      goals: goals,
    );
    projectedAlerts = evaluation.alerts;
    lastRecognition = result;
    return result;
  }

  Future<MealEntry?> saveLastRecognition({
    String mealType = 'Meal',
    DateTime? eatenAt,
    String notes = '',
    Uint8List? photo,
  }) async {
    final result = lastRecognition;
    if (result == null) return null;

    final isDemo = account.isDemo;
    final meal = await localDatabase.saveRecognition(
      result,
      mealType: mealType,
      eatenAt: eatenAt,
      notes: notes,
      persist: !isDemo,
    );
    meals = [meal, ...meals]..sort((a, b) => b.eatenAt.compareTo(a.eatenAt));

    final mealPhoto = photo ?? result.imageBytes;
    if (mealPhoto != null && mealPhoto.isNotEmpty) {
      if (isDemo) {
        _sessionPhotos[meal.id] = mealPhoto;
      } else {
        _photoCache[meal.id] = mealPhoto;
        unawaited(localDatabase.saveMealPhoto(meal.id, mealPhoto).catchError((Object _) {}));
      }
    }

    if (projectedAlerts.isNotEmpty) {
      alerts = [...projectedAlerts, ...alerts];
      if (!isDemo) await localDatabase.saveAlerts(projectedAlerts);
    }

    // The phone holds the diary. A Gemini estimate has no food record on the scale to link to;
    // anything else is also logged there when it can be, without holding up the save.
    if (!isDemo && !result.foodId.startsWith(aiFoodIdPrefix) && isApiOnline) {
      unawaited(apiService
          .logMeal(
            foodId: result.foodId,
            weightG: result.totalWeightG,
            confidence: result.confidence,
            mealType: mealType,
          )
          .then((_) {}, onError: (Object _) {}));
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
    if (!account.isDemo) await localDatabase.updateMeal(meal);
    meals = meals.map((item) => item.id == meal.id ? meal : item).toList()
      ..sort((a, b) => b.eatenAt.compareTo(a.eatenAt));
    notifyListeners();
  }

  Future<void> deleteMeal(String id) async {
    final target = meals.where((m) => m.id == id).firstOrNull;
    if (target != null) {
      _lastDeletedMeal = target;
      _lastDeletedPhoto = await mealPhoto(id);
    }
    if (!account.isDemo) {
      await localDatabase.deleteMeal(id);
      await localDatabase.deleteMealPhoto(id).catchError((Object _) {});
    }
    _photoCache.remove(id);
    meals = meals.where((meal) => meal.id != id).toList();
    notifyListeners();
    unawaited(refreshRecommendations());
  }

  Future<MealEntry?> undoLastDelete() async {
    final restored = _lastDeletedMeal;
    if (restored == null) return null;
    _lastDeletedMeal = null;
    final photo = _lastDeletedPhoto;
    _lastDeletedPhoto = null;
    if (!account.isDemo) {
      await localDatabase.insertMealEntry(restored);
      if (photo != null) await localDatabase.saveMealPhoto(restored.id, photo).catchError((Object _) {});
    }
    if (photo != null) _photoCache[restored.id] = photo;
    meals = [restored, ...meals.where((m) => m.id != restored.id)]
      ..sort((a, b) => b.eatenAt.compareTo(a.eatenAt));
    notifyListeners();
    unawaited(refreshRecommendations());
    return restored;
  }

  Future<void> updateGoals(NutritionGoals value) async {
    goals = value;
    if (!account.isDemo) {
      await localDatabase.saveGoals(value);
      if (isApiOnline) {
        try {
          await apiService.saveGoalsOnServer(value);
        } catch (_) {}
      }
    }
    notifyListeners();
    unawaited(refreshRecommendations());
  }

  Future<void> updateHealthProfile(HealthProfile value) async {
    healthProfile = value;
    if (!account.isDemo) {
      await localDatabase.saveHealthProfile(value);
      if (isApiOnline) {
        try {
          await apiService.saveHealthProfile(value);
        } catch (_) {}
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
        isAr: isAr,
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
    _rememberAlertStates();
    notifyListeners();
  }

  void markAllAlertsRead() {
    alerts = alerts.map((a) => a.copyWith(read: true)).toList();
    _rememberAlertStates();
    notifyListeners();
  }

  void _rememberAlertStates() {
    if (account.isDemo) return;
    unawaited(localDatabase.updateAlertStates(alerts).catchError((Object _) {}));
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
