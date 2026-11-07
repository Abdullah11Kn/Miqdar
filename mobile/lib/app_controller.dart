import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'data/food_catalog.dart';
import 'data/local_database.dart';
import 'l10n/strings.dart';
import 'models/body_profile.dart';
import 'models/diabetes.dart';
import 'models/doctor_report.dart';
import 'models/nutrition.dart';
import 'models/ramadan.dart';
import 'services/alert_service.dart';
import 'services/api_service.dart';
import 'services/gemini_service.dart';
import 'services/reminder_service.dart';

/// A capture the scale could not finish, with the photo when one was taken.
class ScaleCaptureFailure {
  const ScaleCaptureFailure({required this.error, this.imageBytes, this.weightG = 0, this.event, this.plate});

  final RecognitionException error;
  final Uint8List? imageBytes;
  final double weightG;
  final Map<String, dynamic>? event;

  /// Set when a whole mixed plate failed. Its photos and grams are kept here.
  final TakenPlate? plate;

  /// A photo that reached the app can go back to Gemini without capturing again.
  bool get canRetry => plate != null || (imageBytes != null && event?['status'] == 'photo');
}

/// A finished plate the phone has taken from the scale.
class TakenPlate {
  const TakenPlate({required this.plateId, required this.steps, this.note = ''});

  final String plateId;
  final List<PlatePhoto> steps;
  final String note;

  double get totalG => steps.fold(0.0, (sum, step) => sum + step.grams);
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
    ReminderScheduler? reminderScheduler,
  }) : reminderScheduler = reminderScheduler ?? LocalNotificationReminders();

  final ReminderScheduler reminderScheduler;
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
    if (reminderSettings.enabled) unawaited(_applyReminders().catchError((Object _) {}));
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

  /// The answers behind the calculated goal. Stays on this phone and never goes to Gemini.
  BodyProfile? bodyProfile;

  /// Test builds only: lets Abdullah get past the required profile while testing.
  bool bodyProfileSkipped = false;

  /// A brand new user with no goals of their own to keep, even if they left and came back.
  bool bodyProfileIsFirstRun = false;

  bool get needsBodyProfile => !account.isDemo && bodyProfile == null && !bodyProfileSkipped;

  /// Saves the answers only. Goals change separately, when the user accepts them.
  Future<void> saveBodyProfile(BodyProfile value) async {
    if (account.isDemo) return;
    bodyProfile = value;
    bodyProfileIsFirstRun = false;
    _remember('body_profile_first_run', '0');
    await localDatabase.saveBodyProfile(value);
    // The log's newest entry is the current weight, so a change here belongs in it too.
    if (weightEntries.isNotEmpty && weightEntries.last.weightKg != value.weightKg) {
      await saveWeightEntry(measuredOn: DateTime.now(), weightKg: value.weightKg);
    }
    notifyListeners();
  }

  void skipBodyProfile() {
    bodyProfileSkipped = true;
    _remember('body_profile_skipped', '1');
    notifyListeners();
  }

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
      if (!onboarded) {
        bodyProfileIsFirstRun = true;
        _remember('body_profile_first_run', '1');
      }
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
    bodyProfile = null;
    bodyProfileSkipped = false;
    bodyProfileIsFirstRun = false;
    weightEntries = [];
    goalBasisWeightKg = null;
    if (reminderSettings.enabled) {
      reminderSettings = const ReminderSettings();
      unawaited(_applyReminders().catchError((Object _) {}));
    }
    reminderSettings = const ReminderSettings();
    diabetes = const DiabetesSettings();
    ramadanPeriods = [];
    answeredRamadanPrompts = {};
    selectedDate = today;
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

  Future<void> restorePreferences() async {
    if (await localDatabase.getSetting('locale') == 'ar') locale = const Locale('ar');
    apiService.gemini.noteInArabic = isAr;
    if (await localDatabase.getSetting('theme') == 'dark') themeMode = ThemeMode.dark;
    onboarded = await localDatabase.getSetting('onboarded') == '1';
    bodyProfileSkipped = await localDatabase.getSetting('body_profile_skipped') == '1';
    bodyProfileIsFirstRun = await localDatabase.getSetting('body_profile_first_run') == '1';
    bodyProfile = await localDatabase.loadBodyProfile();
    weightEntries = await localDatabase.loadBodyWeights();
    goalBasisWeightKg = double.tryParse(await localDatabase.getSetting('goal_weight_kg') ?? '');
    reminderSettings = ReminderSettings.decode(await localDatabase.getSetting('reminders'));
    diabetes = _decodeDiabetes(await localDatabase.getSetting('diabetes'));
    ramadanPeriods = _decodeRamadan(await localDatabase.getSetting('ramadan_periods'));
    answeredRamadanPrompts =
        (await localDatabase.getSetting('ramadan_prompts') ?? '').split(',').where((k) => k.isNotEmpty).toSet();
    selectedDate = today;
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
    await restorePreferences();
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
    if (reminderSettings.enabled) unawaited(_applyReminders().catchError((Object _) {}));
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

  /// The diary day a moment belongs to: its local calendar date. While Ramadan mode was on, the day
  /// runs from noon to noon, so an iftar and the suhoor after it fall on one day.
  DateTime diaryDayOf(DateTime moment) {
    final local = moment.toLocal();
    final date = DateTime(local.year, local.month, local.day);
    // A morning meal joins the night before only if the mode was already on by that midnight, so a
    // meal soon after switching on never moves into a day that ran midnight to midnight.
    if (local.hour < 12 && _inRamadanPeriod(moment, onBy: date)) return DateTime(date.year, date.month, date.day - 1);
    return date;
  }

  DateTime get today => diaryDayOf(DateTime.now());

  bool isToday(DateTime day) => DateTime(day.year, day.month, day.day) == today;

  // Ramadan mode
  /// When Ramadan mode was on: start and end, with no end while it is on. Earlier days keep midnight.
  List<({DateTime start, DateTime? end})> ramadanPeriods = [];

  bool get ramadanMode => ramadanPeriods.isNotEmpty && ramadanPeriods.last.end == null;

  bool _inRamadanPeriod(DateTime moment, {required DateTime onBy}) => ramadanPeriods.any((p) =>
      p.start.isBefore(onBy) && (p.end == null || moment.isBefore(p.end!)));

  static List<({DateTime start, DateTime? end})> _decodeRamadan(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      return [
        for (final item in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
          (
            start: DateTime.parse(item['start'] as String),
            end: item['end'] == null ? null : DateTime.parse(item['end'] as String),
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> setRamadanMode(bool on) async {
    if (on == ramadanMode) return;
    final now = DateTime.now();
    if (on) {
      ramadanPeriods = [...ramadanPeriods, (start: now, end: null)];
    } else {
      ramadanPeriods = [...ramadanPeriods.sublist(0, ramadanPeriods.length - 1), (start: ramadanPeriods.last.start, end: now)];
    }
    selectedDate = today;
    notifyListeners();
    if (!account.isDemo) {
      await localDatabase.saveSetting(
        'ramadan_periods',
        jsonEncode([
          for (final p in ramadanPeriods) {'start': p.start.toUtc().toIso8601String(), 'end': p.end?.toUtc().toIso8601String()},
        ]),
      );
      if (reminderSettings.enabled) await _applyReminders().catchError((Object _) {});
    }
  }

  /// Suggestions to turn Ramadan mode on or off that were answered, so each is shown once.
  Set<String> answeredRamadanPrompts = {};

  RamadanPrompt? get ramadanPrompt => account.isDemo
      ? null
      : ramadanPromptFor(DateTime.now(), modeOn: ramadanMode, dismissed: answeredRamadanPrompts);

  /// Answers the suggestion: [accept] switches the mode as suggested; either way it is not shown again.
  Future<void> answerRamadanPrompt(RamadanPrompt prompt, {required bool accept}) async {
    answeredRamadanPrompts = {...answeredRamadanPrompts, prompt.key};
    if (!account.isDemo) _remember('ramadan_prompts', answeredRamadanPrompts.join(','));
    if (accept) {
      await setRamadanMode(prompt.kind == RamadanPromptKind.turnOn);
    } else {
      notifyListeners();
    }
  }

  /// The meal types to choose from. Ramadan has Iftar, Suhoor and Snack.
  List<String> get mealTypes => ramadanMode ? const ['Iftar', 'Suhoor', 'Snack'] : const ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  /// The meal type picked for a meal logged at [time].
  String mealTypeFor(DateTime time) {
    if (!ramadanMode) return defaultMealType(time);
    return time.toLocal().hour >= 12 ? 'Iftar' : 'Suhoor';
  }

  static bool isSameLocalDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  List<MealEntry> mealsForDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return meals.where((meal) => diaryDayOf(meal.eatenAt) == day).toList();
  }

  NutritionValues totalsForDate(DateTime date) =>
      mealsForDate(date).fold(NutritionValues.zero(), (total, meal) => total + meal.nutrients);

  NutritionValues get todayTotals => totalsForDate(today);

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
  bool _answeringScaleSave = false;
  ({String eventId, String food, double kcal})? _savedFromScale;

  /// A capture was cancelled on the scale, so its Analyzing or Review screen must close.
  bool closeScaleScreens = false;

  /// Set while Review Meal is open, so a save from the scale keeps the meal type and note chosen there.
  Future<void> Function()? reviewSaveHandler;
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

        final bootId = data['boot_id'] as String?;
        final restarted = _scaleBootId != null && bootId != null && bootId != _scaleBootId;
        if (bootId != null) _scaleBootId = bootId;
        if (restarted && scalePlate != null && scalePlate!.isOpen && data['plate'] == null) {
          plateLostToRestart = true;
        }
        final plateChanged = await _followPlate(data['plate'] as Map<String, dynamic>?);
        await _followCancelRequest(data['cancel_request'] as String?);
        final newCapture = await _followLatestCapture(data['latest_capture']);
        await _followSaveRequest(data['save_request'] as String?);
        if (newCapture ||
            plateChanged ||
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

  /// The plate being built on the scale, from either screen.
  ScalePlate? scalePlate;
  bool plateBusy = false;
  final Map<String, Uint8List> _platePhotos = {};
  String? _takenPlateId;
  String? _scaleBootId;

  /// The scale restarted during a plate. It keeps plates in memory, so that plate is gone.
  bool plateLostToRestart = false;

  void dismissPlateLost() {
    plateLostToRestart = false;
    notifyListeners();
  }

  /// Step photos for the rows on Review. Only the last photo is kept with the saved meal.
  Map<String, Uint8List> plateItemPhotos = {};

  Uint8List? platePhoto(ScalePlateStep step) {
    final plate = scalePlate;
    return plate == null ? null : _platePhotos[step.photoKey(plate.plateId)];
  }

  /// add, finish, undo or cancel. Throws [RecognitionException] when the scale refuses.
  Future<void> plateAction(String action) async {
    plateBusy = true;
    notifyListeners();
    try {
      await _followPlate(await apiService.plateAction(action));
    } finally {
      plateBusy = false;
      notifyListeners();
    }
  }

  /// Keeps the phone's copy in step with the scale, and picks up a finished plate.
  Future<bool> _followPlate(Map<String, dynamic>? json) async {
    final plate = json == null ? null : ScalePlate.fromJson(json);
    final changed = plate?.plateId != scalePlate?.plateId ||
        plate?.finished != scalePlate?.finished ||
        plate?.steps.length != scalePlate?.steps.length ||
        plate?.totalG != scalePlate?.totalG;
    scalePlate = plate;
    if (plate == null) return changed;

    var fetched = false;
    for (final step in plate.steps) {
      final key = step.photoKey(plate.plateId);
      if (_platePhotos.containsKey(key)) continue;
      try {
        _platePhotos[key] = await apiService.getPlatePhoto(step.index);
        fetched = true;
      } catch (_) {
        return changed || fetched; // tried again on the next poll
      }
    }
    if (plate.finished && plate.plateId != _takenPlateId) {
      _takenPlateId = plate.plateId;
      final taken = TakenPlate(
        plateId: plate.plateId,
        steps: [
          for (final step in plate.steps)
            PlatePhoto(photo: _platePhotos[step.photoKey(plate.plateId)]!, grams: step.grams),
        ],
        note: aiNote.trim(),
      );
      aiNote = '';
      _platePhotos.clear();
      scalePlate = null;
      unawaited(apiService.plateAction('cancel').catchError((Object _) => null)); // the phone holds it now
      unawaited(_analyzePlate(taken));
      return true;
    }
    return changed || fetched;
  }

  void _rememberPlatePhotos(TakenPlate plate, RecognitionResult result) {
    plateItemPhotos = {
      for (var i = 0; i < result.plateItems.length && i < plate.steps.length; i++)
        result.plateItems[i].id: plate.steps[i].photo,
    };
  }

  Future<void> _analyzePlate(TakenPlate plate) async {
    _analyzingEventId = plate.plateId;
    pendingScaleCapture = PendingScaleCapture(imageBytes: plate.steps.last.photo, weightG: plate.totalG);
    notifyListeners();
    try {
      final result = await apiService.gemini.analyzePlate(
        steps: plate.steps,
        eventId: plate.plateId,
        hint: plate.note.isEmpty ? null : plate.note,
      );
      if (_analyzingEventId != plate.plateId) return;
      _rememberPlatePhotos(plate, result);
      await _acceptScaleCapture(result);
    } on RecognitionException catch (error) {
      if (_analyzingEventId != plate.plateId) return;
      latestScaleCaptureFailure = ScaleCaptureFailure(
        error: error,
        imageBytes: plate.steps.last.photo,
        weightG: plate.totalG,
        plate: plate,
      );
    } finally {
      if (_analyzingEventId == plate.plateId) _analyzingEventId = null;
      notifyListeners();
    }
  }

  /// Gemini could not help, so the user names each food. The weighing is kept.
  Future<void> openPlateForNaming(TakenPlate plate) async {
    final result = RecognitionResult.forPlate(
      eventId: plate.plateId,
      items: [
        for (var i = 0; i < plate.steps.length; i++)
          MealItemEntry.unidentified(id: 'plate-item-${plate.plateId}-$i', weightG: plate.steps[i].grams),
      ],
      nameEn: '',
      nameAr: '',
      confidence: 0,
      provider: 'manual',
      imageBytes: plate.steps.last.photo,
    );
    _rememberPlatePhotos(plate, result);
    await _acceptScaleCapture(result);
    notifyListeners();
  }

  Future<RecognitionResult?> _replacePlateItems(List<MealItemEntry> items) async {
    final current = lastRecognition;
    if (current == null || items.isEmpty) return current;
    // A name nobody chose follows the foods; Gemini's name for the plate stays once it has one.
    final named = items.where((item) => !item.isUnidentified);
    final namedByHand = current.provider == 'manual';
    final applied = await _applyResult(RecognitionResult.forPlate(
      eventId: current.eventId,
      items: items,
      nameEn: namedByHand ? named.map((i) => i.nameEn).join(' + ') : current.plateNameEn,
      nameAr: namedByHand ? named.map((i) => i.nameAr).join(' + ') : current.plateNameAr,
      confidence: current.confidence,
      provider: current.provider,
      model: current.model,
      imageBytes: current.imageBytes,
    ));
    notifyListeners();
    return applied;
  }

  List<MealItemEntry> _platePatched(String itemId, MealItemEntry Function(MealItemEntry) patch) => [
        for (final item in lastRecognition?.plateItems ?? const <MealItemEntry>[])
          item.id == itemId ? patch(item) : item,
      ];

  Future<RecognitionResult?> removePlateItem(String itemId) => _replacePlateItems(
        (lastRecognition?.plateItems ?? const <MealItemEntry>[]).where((item) => item.id != itemId).toList(),
      );

  Future<RecognitionResult?> setPlateItemWeight(String itemId, double grams) => _replacePlateItems(
        _platePatched(itemId, (item) => item.withWeight(grams, newSource: PortionSource.manual)),
      );

  Future<RecognitionResult?> replacePlateItemFood(String itemId, FoodCatalogItem food) => _replacePlateItems(
        _platePatched(
          itemId,
          (item) => MealItemEntry(
            id: item.id,
            foodId: food.foodId,
            nameEn: food.nameEn,
            nameAr: food.nameAr,
            weightG: item.weightG,
            nutrients: food.per100g.forPortionGrams(item.weightG),
            basisPer100g: food.per100g,
            portionSource: item.portionSource,
            verificationStatus: food.verificationStatus,
            preparation: food.preparation,
          ),
        ),
      );

  /// The user types what a food really is. Gemini gives its values; the measured grams stay.
  Future<RecognitionResult?> namePlateItem(String itemId, String name) async {
    final items = lastRecognition?.plateItems ?? const <MealItemEntry>[];
    final item = items.where((i) => i.id == itemId).firstOrNull;
    if (item == null) return lastRecognition;
    final answer = await apiService.gemini.analyzeDescription(description: name, weightG: item.weightG);
    return _replacePlateItems(
      _platePatched(
        itemId,
        (old) => MealItemEntry(
          id: old.id,
          foodId: answer.foodId,
          nameEn: answer.nameEn,
          nameAr: answer.nameAr,
          weightG: old.weightG,
          nutrients: answer.resolvedBasisPer100g.forPortionGrams(old.weightG),
          basisPer100g: answer.resolvedBasisPer100g,
          portionSource: old.portionSource,
          verificationStatus: answer.verificationStatus,
        ),
      ),
    );
  }

  /// A meal logged away from the scale, from words, a photo or both. Gemini estimates the amount
  /// too, so it is marked as estimated. Throws [RecognitionException] if Gemini cannot help.
  Future<RecognitionResult> logEstimatedMeal({String description = '', Uint8List? photo}) async {
    final result = await apiService.gemini.analyzeDescription(description: description, photo: photo);
    activeProviderName = result.provider;
    activeModelName = result.model;
    final applied = await _applyResult(result);
    notifyListeners();
    return applied;
  }

  /// Recent foods for Search, newest first, one row per name. Repeating one uses its saved
  /// values and sends nothing to Gemini.
  List<MealEntry> get recentFoods {
    final seen = <String>{};
    final sorted = [...meals]..sort((a, b) => b.eatenAt.compareTo(a.eatenAt));
    return sorted.where((meal) => seen.add(meal.nameEn.toLowerCase())).take(5).toList();
  }

  /// A saved meal back on Review with its own values, so the portion can change before saving.
  Future<RecognitionResult> prepareRelog(MealEntry meal) {
    if (meal.items.length > 1) return prepareMealAgain(meal);
    return prepareCatalogDraft(
      food: FoodCatalogItem(
        foodId: meal.foodId,
        nameEn: meal.nameEn,
        nameAr: meal.nameAr,
        category: 'Logged',
        preparation: 'Copied snapshot',
        verificationStatus: meal.verificationStatus,
        sourceId: 'DIARY_REPEAT',
        per100g: meal.resolvedBasisPer100g,
      ),
      weightG: meal.weightG,
      portionSource: _repeatedSource(meal.portionSource),
    );
  }

  /// Nobody weighed the repeat, so it is not "weighed". An estimate is still only an estimate.
  PortionSource _repeatedSource(PortionSource saved) =>
      saved == PortionSource.estimated ? PortionSource.estimated : PortionSource.manual;

  // Body weight log

  List<BodyWeightEntry> weightEntries = [];

  /// The body weight the current goals were calculated from.
  double? goalBasisWeightKg;

  static const goalUpdateAfterKg = 2.0;

  Future<void> saveWeightEntry({String? id, required DateTime measuredOn, required double weightKg}) async {
    if (account.isDemo) return;
    await localDatabase.saveBodyWeight(BodyWeightEntry(
      id: id ?? 'weight-${DateTime.now().microsecondsSinceEpoch}',
      measuredOn: measuredOn,
      weightKg: weightKg,
    ));
    await _reloadWeights();
  }

  Future<void> deleteWeightEntry(String id) async {
    if (account.isDemo) return;
    await localDatabase.deleteBodyWeight(id);
    await _reloadWeights();
  }

  /// The newest entry is the current weight in the profile.
  Future<void> _reloadWeights() async {
    weightEntries = await localDatabase.loadBodyWeights();
    final profile = bodyProfile;
    if (profile != null && weightEntries.isNotEmpty && weightEntries.last.weightKg != profile.weightKg) {
      bodyProfile = profile.withWeight(weightEntries.last.weightKg);
      await localDatabase.saveBodyProfile(bodyProfile!);
    }
    notifyListeners();
  }

  /// New goals to offer once weight has moved far enough. Goals change only if accepted.
  NutritionGoals? get goalUpdateOffer {
    final profile = bodyProfile;
    final basis = goalBasisWeightKg;
    if (profile == null || basis == null || goals.trackingOnly || weightEntries.isEmpty) return null;
    if ((weightEntries.last.weightKg - basis).abs() < goalUpdateAfterKg) return null;
    final now = DateTime.now();
    // Reaching the target makes it invalid, and then the goal is to keep the new weight.
    final plan = profile.problems(now).isEmpty ? profile : profile.maintaining;
    if (plan.problems(now).isNotEmpty) return null;
    return suggestGoals(plan, goals, now).goals;
  }

  Future<void> rememberGoalWeight(double kg) async {
    if (account.isDemo) return;
    goalBasisWeightKg = kg;
    await localDatabase.saveSetting('goal_weight_kg', '$kg');
    notifyListeners();
  }

  Future<void> acceptGoalUpdate() async {
    final offer = goalUpdateOffer;
    if (offer == null) return;
    await updateGoals(offer);
    await rememberGoalWeight(weightEntries.last.weightKg);
  }

  /// Not asked again until weight moves as far again.
  Future<void> declineGoalUpdate() async {
    if (weightEntries.isNotEmpty) await rememberGoalWeight(weightEntries.last.weightKg);
  }

  // Meal reminders

  ReminderSettings reminderSettings = const ReminderSettings();

  /// False if the user refused permission, in which case reminders stay off.
  Future<bool> updateReminders(ReminderSettings value) async {
    if (account.isDemo) return false;
    var settings = value;
    var allowed = true;
    if (value.enabled && !reminderSettings.enabled) {
      allowed = await reminderScheduler.requestPermission();
      if (!allowed) settings = value.copyWith(enabled: false);
    }
    reminderSettings = settings;
    await localDatabase.saveSetting('reminders', settings.encode());
    await _applyReminders();
    notifyListeners();
    return allowed;
  }

  Future<void> _applyReminders() => reminderScheduler.replaceAll([
        // Timed reminders pause in Ramadan and come back unchanged after it.
        if (reminderSettings.enabled && !ramadanMode)
          for (var i = 0; i < reminderSettings.meals.length; i++)
            if (reminderSettings.meals[i].on)
              DailyReminder(
                id: i + 1,
                body: _reminderText(reminderSettings.meals[i].meal),
                hour: reminderSettings.meals[i].hour,
                minute: reminderSettings.meals[i].minute,
              ),
      ]);

  String _reminderText(String meal) {
    final s = S(isAr);
    return switch (meal) {
      'Breakfast' => s.tr('Time to log your breakfast', 'حان وقت تسجيل فطورك'),
      'Lunch' => s.tr('Time to log your lunch', 'حان وقت تسجيل غدائك'),
      _ => s.tr('Time to log your dinner', 'حان وقت تسجيل عشائك'),
    };
  }

  /// When Gemini cannot help and the food is not in Search. The measured grams stay, and
  /// anything not typed stays Unknown.
  Future<RecognitionResult?> enterPlateItemByHand(
    String itemId, {
    required String name,
    required double caloriesPer100g,
    double? protein,
    double? carbs,
    double? fat,
  }) {
    final per100g = NutritionValues.fromJson({
      'calories_kcal': caloriesPer100g,
      'protein_g': protein,
      'carbohydrate_g': carbs,
      'fat_g': fat,
    });
    return _replacePlateItems(
      _platePatched(
        itemId,
        (old) => MealItemEntry(
          id: old.id,
          foodId: 'custom-${old.id}',
          nameEn: name,
          nameAr: name,
          weightG: old.weightG,
          nutrients: per100g.forPortionGrams(old.weightG),
          basisPer100g: per100g,
          portionSource: old.portionSource,
          verificationStatus: 'user_entered',
        ),
      ),
    );
  }

  /// Log Again for a meal of several foods keeps all of them.
  Future<RecognitionResult> prepareMealAgain(MealEntry meal) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    plateItemPhotos = {};
    final applied = await _applyResult(RecognitionResult.forPlate(
      eventId: 'again-$stamp',
      items: [
        for (var i = 0; i < meal.items.length; i++)
          MealItemEntry(
            id: 'plate-item-$stamp-$i',
            foodId: meal.items[i].foodId,
            nameEn: meal.items[i].nameEn,
            nameAr: meal.items[i].nameAr,
            weightG: meal.items[i].weightG,
            nutrients: meal.items[i].nutrients,
            basisPer100g: meal.items[i].resolvedBasisPer100g,
            portionSource: _repeatedSource(meal.items[i].portionSource),
            verificationStatus: meal.items[i].verificationStatus,
            preparation: meal.items[i].preparation,
          ),
      ],
      nameEn: meal.nameEn,
      nameAr: meal.nameAr,
      confidence: meal.confidence,
      provider: 'diary',
    ));
    notifyListeners();
    return applied;
  }

  /// Cancel on the scale's Analyzing screen. Whatever stage this capture reached here, it stops.
  Future<void> _followCancelRequest(String? eventId) async {
    if (eventId == null) return;
    // Marked seen, so a phone that connects only now does not start analyzing it.
    _lastSeenCaptureEventId = eventId;
    _remember('last_capture_event', eventId);
    if (_analyzingEventId == eventId) {
      _analyzingEventId = null;
      pendingScaleCapture = null;
      closeScaleScreens = true;
    }
    if (lastRecognition?.eventId == eventId) {
      latestExternalScaleCapture = null;
      closeScaleScreens = true;
      lastRecognition = null;
      projectedAlerts = [];
    }
    if (closeScaleScreens) notifyListeners();
    await apiService.postMealOutcome(eventId, 'discarded');
  }

  /// Save to Diary on the scale's touchscreen. The diary is here, so the save happens here,
  /// once, however many polls see the request, and the scale is told how it went.
  Future<void> _followSaveRequest(String? eventId) async {
    if (eventId == null || _answeringScaleSave) return;
    _answeringScaleSave = true;
    try {
      final saved = _savedFromScale;
      if (saved != null && saved.eventId == eventId) {
        // Saved already, but the scale did not hear: only the answer is repeated.
        await apiService.postMealOutcome(eventId, 'saved', food: saved.food, kcal: saved.kcal);
        return;
      }
      final draft = lastRecognition;
      if (draft == null || draft.eventId != eventId || draft.plateNeedsNames) {
        await apiService.postMealOutcome(eventId, 'missing');
        return;
      }
      final handler = reviewSaveHandler;
      if (handler != null) {
        await handler();
      } else {
        final now = DateTime.now();
        await saveLastRecognition(mealType: mealTypeFor(now), eatenAt: now);
      }
    } catch (_) {
      // The meal is still on the phone; the scale must not keep waiting or say Saved.
      await apiService.postMealOutcome(eventId, 'failed');
    } finally {
      _answeringScaleSave = false;
    }
  }

  /// The meal type a new draft starts with, from the time of day.
  static String defaultMealType(DateTime time) {
    if (time.hour < 11) return 'Breakfast';
    if (time.hour < 16) return 'Lunch';
    if (time.hour < 22) return 'Dinner';
    return 'Snack';
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
    if (failure.plate != null) return _analyzePlate(failure.plate!);
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
    if (current.isPlate) return _replacePlateItems([...current.plateItems, item]);
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
    if (result == null || result.plateNeedsNames) return null;

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

    // Whichever screen saved it, the scale's touchscreen stops offering Save.
    if (result.eventId == _lastSeenCaptureEventId) {
      final food = meal.nameEn;
      final kcal = meal.nutrients.calories;
      _savedFromScale = (eventId: result.eventId, food: food, kcal: kcal);
      unawaited(apiService.postMealOutcome(result.eventId, 'saved', food: food, kcal: kcal));
    }

    // The phone holds the diary. A Gemini estimate has no food record on the scale to link to;
    // anything else is also logged there when it can be, without holding up the save.
    if (!isDemo && !result.isPlate && !result.foodId.startsWith(aiFoodIdPrefix) && isApiOnline) {
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
    final eventId = lastRecognition?.eventId;
    if (eventId != null && eventId == _lastSeenCaptureEventId) {
      unawaited(apiService.postMealOutcome(eventId, 'discarded'));
    }
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

  // Diabetes mode
  DiabetesSettings diabetes = const DiabetesSettings();

  static DiabetesSettings _decodeDiabetes(String? raw) {
    if (raw == null || raw.isEmpty) return const DiabetesSettings();
    try {
      return DiabetesSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const DiabetesSettings();
    }
  }

  /// Asked in the Body Profile and in Food Preferences; both write here.
  Future<void> updateDiabetes(DiabetesSettings value) async {
    diabetes = value;
    notifyListeners();
    if (!account.isDemo) await localDatabase.saveSetting('diabetes', jsonEncode(value.toJson()));
  }

  /// Fasting in Ramadan. Ramadan mode sets it.
  bool get fasting => ramadanMode;

  /// Why no carb number is suggested to this user, or null when one can be.
  CarbAdviceBlock? get carbBlock => carbAdviceBlock(
        diabetes,
        profile: bodyProfile,
        kidneyDisease: healthProfile.conditions.contains('kidney_disease'),
        fasting: fasting,
      );

  /// The starting point the app can offer, or null when the care team should set it.
  ({double meal, double snack})? get suggestedCarbPlan =>
      diabetes.hasDiabetes && carbBlock == null ? suggestedCarbs(bodyProfile) : null;

  Future<void> useSuggestedCarbs() async {
    final plan = suggestedCarbPlan;
    if (plan == null) return;
    await updateDiabetes(diabetes.copyWith(mealCarbsG: plan.meal, snackCarbsG: plan.snack, source: CarbPlanSource.suggested));
  }

  Future<void> waitForDoctor() => updateDiabetes(diabetes.copyWith(clearPlan: true, source: CarbPlanSource.waiting));

  Future<void> setDoctorCarbs({required double meal, double? snack}) => updateDiabetes(
      diabetes.copyWith(mealCarbsG: meal, snackCarbsG: snack ?? meal, source: CarbPlanSource.doctor));

  Future<void> clearCarbPlan() => updateDiabetes(diabetes.copyWith(clearPlan: true));

  /// The planned carbs for a meal. A suggestion stops applying once it would no longer be offered;
  /// numbers from a doctor always apply.
  double? carbTargetFor(String mealType) {
    if (diabetes.source == CarbPlanSource.suggested && carbBlock != null) return null;
    return diabetes.carbTargetFor(mealType);
  }

  /// The doctor's report for the last [days] diary days, worked out from the user's own numbers.
  DoctorReport doctorReport(int days, {required bool isAr}) => buildDoctorReport(
        meals: meals,
        goals: goals,
        weights: weightEntries,
        today: today,
        periodDays: days,
        dayOf: diaryDayOf,
        // The placeholder name is not a person's name, so a report never shows it.
        name: account.displayName == UserAccount.defaultName
            ? ''
            : (isAr && account.displayNameAr.isNotEmpty ? account.displayNameAr : account.displayName),
        carbsFirst: diabetes.carbsFirst,
      );

  /// Leftovers can be weighed until the end of the meal's diary day.
  bool canWeighLeftovers(MealEntry meal) => diaryDayOf(meal.eatenAt) == today;

  /// Records food weighed after eating. Returns why it was refused, or null once saved.
  Future<LeftoverProblem?> saveLeftover(MealEntry meal, double grams, {int? itemIndex}) async {
    final problem = leftoverProblem(meal, grams, itemIndex: itemIndex);
    if (problem != null) return problem;
    await updateMeal(meal.copyWith(
      leftover: MealLeftover(grams: grams, itemIndex: itemIndex, weighedAt: DateTime.now()),
    ));
    return null;
  }

  /// The meal goes back to what was served.
  Future<void> removeLeftover(MealEntry meal) => updateMeal(meal.copyWith(clearLeftover: true));

  /// Food left on plates in [mealsInPeriod]: grams and values that were served but not eaten.
  static ({double grams, NutritionValues values, int meals}) notEaten(Iterable<MealEntry> mealsInPeriod) {
    var grams = 0.0;
    var count = 0;
    var values = NutritionValues.zero();
    for (final meal in mealsInPeriod) {
      if (meal.leftover == null) continue;
      count++;
      grams += meal.weightG - meal.eatenWeightG;
      values = values + leftoverNutrients(meal);
    }
    return (grams: grams, values: values, meals: count);
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
      'Date,Time,Meal Type,Food (EN),Food (AR),Portion (g),Left (g),Portion Source,Verification,Calories (kcal),Protein (g),Carbs (g),Fat (g),Sugar (g),Fiber (g),Sodium (mg),Potassium (mg),Notes',
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
        (meal.leftover?.grams ?? 0).toStringAsFixed(1),
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
