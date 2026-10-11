import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

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

  NutritionGoals goals = const NutritionGoals(
    calories: 2200,
    sugar: 50,
    sodium: 2300,
    potassium: 3500,
    carbohydrates: 275,
    protein: 120,
  );
  List<MealEntry> meals = [];
  List<HealthAlert> alerts = [];
  HealthProfile healthProfile = const HealthProfile();
  List<MealSuggestion> mealSuggestions = [];
  String recommendationDisclaimer = '';
  String connectionStatus = 'Checking server…';
  bool recommendationsOffline = false;
  RecognitionResult? lastRecognition;
  int alertEvaluationMs = 0;
  bool busy = false;
  bool recommendationsBusy = false;

  Future<void> initialize() async {
    await localDatabase.initialize();
    goals = await localDatabase.loadGoals();
    healthProfile = await localDatabase.loadHealthProfile();
    meals = await localDatabase.loadMeals(days: 90);
    alerts = await localDatabase.loadAlerts();
    notifyListeners();
    unawaited(_initializeNetworkFeatures());
  }

  Future<void> _initializeNetworkFeatures() async {
    await checkServer();
    await refreshRecommendations();
  }

  Future<void> checkServer() async {
    try {
      final status = await apiService.health();
      final recognition = status['recognition'] as Map<String, dynamic>? ?? {};
      final provider = recognition['provider'] as String? ?? 'unknown';
      final model = recognition['model'] as String?;
      connectionStatus = model == null ? 'API online • $provider' : 'API online • $model';
    } catch (_) {
      connectionStatus = 'Offline demo mode';
    }
    notifyListeners();
  }

  NutritionValues get todayTotals {
    final now = DateTime.now();
    return meals.where((meal) {
      final date = meal.eatenAt.toLocal();
      return date.year == now.year && date.month == now.month && date.day == now.day;
    }).fold(NutritionValues.zero(), (total, meal) => total + meal.nutrients);
  }

  Future<RecognitionResult> recognize({
    required XFile? image,
    required double weightG,
    required String hint,
  }) async {
    busy = true;
    notifyListeners();
    try {
      final result = await apiService.recognize(image: image, weightG: weightG, hint: hint);
      final evaluation = alertService.evaluate(
        currentTotals: todayTotals,
        incoming: result.nutrients,
        goals: goals,
      );
      alertEvaluationMs = evaluation.elapsedMs;
      alerts = [...evaluation.alerts, ...alerts];
      if (evaluation.alerts.isNotEmpty) {
        await localDatabase.saveAlerts(evaluation.alerts);
      }
      lastRecognition = result;
      connectionStatus = result.isMock ? 'Offline demo mode' : 'API online • Gemini recognition';
      return result;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> saveLastRecognition() async {
    final result = lastRecognition;
    if (result == null) return;
    final meal = await localDatabase.saveRecognition(result);
    meals = [meal, ...meals];
    notifyListeners();
    unawaited(refreshRecommendations());
  }

  Future<void> updateMeal(MealEntry meal) async {
    await localDatabase.updateMeal(meal);
    meals = meals.map((item) => item.id == meal.id ? meal : item).toList()
      ..sort((a, b) => b.eatenAt.compareTo(a.eatenAt));
    notifyListeners();
  }

  Future<void> deleteMeal(String id) async {
    await localDatabase.deleteMeal(id);
    meals = meals.where((meal) => meal.id != id).toList();
    notifyListeners();
    unawaited(refreshRecommendations());
  }

  Future<void> setHistoryWindow(int days) async {
    meals = await localDatabase.loadMeals(days: days);
    notifyListeners();
  }

  Future<void> updateGoals(NutritionGoals value) async {
    goals = value;
    await localDatabase.saveGoals(value);
    notifyListeners();
    unawaited(refreshRecommendations());
  }

  Future<void> updateHealthProfile(HealthProfile value) async {
    healthProfile = value;
    await localDatabase.saveHealthProfile(value);
    if (connectionStatus.startsWith('API online')) {
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
        offlineOnly: !connectionStatus.startsWith('API online'),
      );
      mealSuggestions = result.suggestions;
      recommendationDisclaimer = result.disclaimer;
      recommendationsOffline = result.offline;
    } finally {
      recommendationsBusy = false;
      notifyListeners();
    }
  }
}
