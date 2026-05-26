import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';

// --- Models ---

class PlanMeal {
  final String id;
  final String date;
  final String type;
  final String recipeName;
  final String? imageUrl;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final bool isTogo;
  final int prepMinutes;
  final List<String> ingredients;
  final String instructions;
  final bool isEaten;
  final bool isSkipped;
  final int alternativesCount;
  final double servingSize;

  const PlanMeal({
    required this.id,
    required this.date,
    required this.type,
    required this.recipeName,
    this.imageUrl,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.isTogo,
    required this.prepMinutes,
    required this.ingredients,
    required this.instructions,
    required this.isEaten,
    this.isSkipped = false,
    this.alternativesCount = 0,
    this.servingSize = 1.0,
  });

  factory PlanMeal.fromJson(Map<String, dynamic> json) {
    final recipe = json['recipe_data'] as Map<String, dynamic>? ?? {};
    final nutrients = recipe['nutrients'] as Map<String, dynamic>? ?? {};
    return PlanMeal(
      id: json['id'] as String,
      date: (json['meal_date'] as String).split('T')[0],
      type: json['meal_type'] as String,
      recipeName: recipe['title'] as String? ?? '',
      imageUrl: recipe['imageUrl'] as String?,
      calories: (nutrients['calories'] as num?)?.toInt() ?? 0,
      proteinG: (nutrients['protein'] as num?)?.toInt() ?? 0,
      carbsG: (nutrients['carbs'] as num?)?.toInt() ?? 0,
      fatG: (nutrients['fat'] as num?)?.toInt() ?? 0,
      isTogo: json['is_togo'] as bool? ?? false,
      prepMinutes: recipe['prepMinutes'] as int? ?? 20,
      ingredients: (recipe['ingredients'] as List<dynamic>?)?.cast<String>() ?? [],
      instructions: recipe['instructions'] as String? ?? '',
      isEaten: json['is_eaten'] as bool? ?? false,
      isSkipped: json['skipped'] as bool? ?? false,
      alternativesCount: (json['alternatives_count'] as num?)?.toInt() ?? 0,
      servingSize: double.tryParse(json['serving_size']?.toString() ?? '') ?? 1.0,
    );
  }

  PlanMeal copyWith({
    bool? isEaten,
    bool? isSkipped,
    String? recipeName,
    String? imageUrl,
    int? calories,
    int? proteinG,
    int? carbsG,
    int? fatG,
    int? prepMinutes,
    List<String>? ingredients,
    String? instructions,
    int? alternativesCount,
  }) => PlanMeal(
    id: id,
    date: date,
    type: type,
    recipeName: recipeName ?? this.recipeName,
    imageUrl: imageUrl ?? this.imageUrl,
    calories: calories ?? this.calories,
    proteinG: proteinG ?? this.proteinG,
    carbsG: carbsG ?? this.carbsG,
    fatG: fatG ?? this.fatG,
    isTogo: isTogo,
    prepMinutes: prepMinutes ?? this.prepMinutes,
    ingredients: ingredients ?? this.ingredients,
    instructions: instructions ?? this.instructions,
    isEaten: isEaten ?? this.isEaten,
    isSkipped: isSkipped ?? this.isSkipped,
    alternativesCount: alternativesCount ?? this.alternativesCount,
  );

  String get mealTypeLabel => switch (type) {
    'breakfast' => 'Frühstück',
    'lunch' => 'Mittagessen',
    'dinner' => 'Abendessen',
    _ => 'Snack',
  };
}

class ActivityEntry {
  final String activityType;
  final int durationMinutes;
  final double? distanceKm;
  final int calories;
  final int? avgHeartRate;
  final String intensityLevel;

  const ActivityEntry({
    required this.activityType,
    required this.durationMinutes,
    this.distanceKm,
    required this.calories,
    this.avgHeartRate,
    required this.intensityLevel,
  });

  factory ActivityEntry.fromJson(Map<String, dynamic> json) => ActivityEntry(
    activityType: json['activityType'] as String? ?? 'training',
    durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
    distanceKm: (json['distanceKm'] as num?)?.toDouble(),
    calories: (json['calories'] as num?)?.toInt() ?? 0,
    avgHeartRate: (json['avgHeartRate'] as num?)?.toInt(),
    intensityLevel: json['intensityLevel'] as String? ?? 'moderate',
  );
}

class TrainingDay {
  final String date;
  final String weekday;
  final bool hasTraining;
  final int durationMinutes;
  final String intensityLevel;
  final int estimatedCalories;
  final String activityType;
  final bool isActual;
  final double? distanceKm;
  final List<ActivityEntry> activities;

  const TrainingDay({
    required this.date,
    required this.weekday,
    required this.hasTraining,
    required this.durationMinutes,
    required this.intensityLevel,
    required this.estimatedCalories,
    required this.activityType,
    required this.isActual,
    this.distanceKm,
    this.activities = const [],
  });

  factory TrainingDay.fromJson(Map<String, dynamic> json) => TrainingDay(
    date: json['date'] as String,
    weekday: json['weekday'] as String,
    hasTraining: json['hasTraining'] as bool? ?? false,
    durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
    intensityLevel: json['intensityLevel'] as String? ?? 'rest',
    estimatedCalories: (json['estimatedCalories'] as num?)?.toInt() ?? 0,
    activityType: json['activityType'] as String? ?? 'training',
    isActual: json['isActual'] as bool? ?? true,
    distanceKm: (json['distanceKm'] as num?)?.toDouble(),
    activities: (json['activities'] as List<dynamic>?)
        ?.map((a) => ActivityEntry.fromJson(a as Map<String, dynamic>))
        .toList() ?? [],
  );
}

class WeekPlan {
  final String id;
  final String weekStart;
  final List<TrainingDay> trainingForecast;
  final Map<String, List<PlanMeal>> mealsByDay;
  final String weeklyLoadLevel;

  const WeekPlan({
    required this.id,
    required this.weekStart,
    required this.trainingForecast,
    required this.mealsByDay,
    required this.weeklyLoadLevel,
  });

  WeekPlan withMealSkipToggled(String mealId, bool isSkipped) {
    final updatedByDay = mealsByDay.map((day, meals) {
      final updated = meals
          .map((m) => m.id == mealId ? m.copyWith(isSkipped: isSkipped) : m)
          .toList();
      return MapEntry(day, updated);
    });
    return WeekPlan(
      id: id,
      weekStart: weekStart,
      trainingForecast: trainingForecast,
      mealsByDay: updatedByDay,
      weeklyLoadLevel: weeklyLoadLevel,
    );
  }

  WeekPlan withMealToggled(String mealId, bool isEaten) {
    final updatedByDay = mealsByDay.map((day, meals) {
      final updated = meals
          .map((m) => m.id == mealId ? m.copyWith(isEaten: isEaten) : m)
          .toList();
      return MapEntry(day, updated);
    });
    return WeekPlan(
      id: id,
      weekStart: weekStart,
      trainingForecast: trainingForecast,
      mealsByDay: updatedByDay,
      weeklyLoadLevel: weeklyLoadLevel,
    );
  }

  WeekPlan withMealReplaced(String mealId, Map<String, dynamic> recipeData, int newAlternativesCount) {
    final nutrients = recipeData['nutrients'] as Map<String, dynamic>? ?? {};
    final updatedByDay = mealsByDay.map((day, meals) {
      final updated = meals.map((m) {
        if (m.id != mealId) return m;
        return m.copyWith(
          recipeName: recipeData['title'] as String?,
          calories: (nutrients['calories'] as num?)?.toInt(),
          proteinG: (nutrients['protein'] as num?)?.toInt(),
          carbsG: (nutrients['carbs'] as num?)?.toInt(),
          fatG: (nutrients['fat'] as num?)?.toInt(),
          prepMinutes: recipeData['prepMinutes'] as int?,
          ingredients: (recipeData['ingredients'] as List<dynamic>?)?.cast<String>(),
          instructions: recipeData['instructions'] as String?,
          alternativesCount: newAlternativesCount,
        );
      }).toList();
      return MapEntry(day, updated);
    });
    return WeekPlan(
      id: id,
      weekStart: weekStart,
      trainingForecast: trainingForecast,
      mealsByDay: updatedByDay,
      weeklyLoadLevel: weeklyLoadLevel,
    );
  }
}

class ShoppingCategory {
  final String name;
  final List<ShoppingItem> items;
  const ShoppingCategory({required this.name, required this.items});
}

class ShoppingItem {
  final String name;
  final String amount;
  bool checked;
  ShoppingItem({required this.name, required this.amount, this.checked = false});
}

// --- Providers ---

final weekPlanProvider = AsyncNotifierProvider<WeekPlanNotifier, WeekPlan?>(() => WeekPlanNotifier());

class WeekPlanNotifier extends AsyncNotifier<WeekPlan?> {
  @override
  Future<WeekPlan?> build() => _fetchCurrentPlan();

  Future<WeekPlan?> _fetchCurrentPlan() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/plan/current');
      if (res.data == null) return null;
      return _parsePlan(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> resetAndRegenerate() async {
    final dio = ref.read(dioProvider);
    state = const AsyncValue.loading();
    try { await dio.delete('/plan/current'); } catch (_) {}
    state = await AsyncValue.guard(() async {
      final res = await dio.post('/plan/generate');
      return _parsePlan(res.data as Map<String, dynamic>);
    });
  }

  Future<void> generatePlan() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/plan/generate');
      return _parsePlan(res.data as Map<String, dynamic>);
    });
  }

  /// Strava-Sync auslösen, dann Plan mit frischem Forecast neu laden (mit Ladebalken)
  Future<void> syncAndRefresh() async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/strava/sync');
    } catch (_) {
      // Sync-Fehler ignorieren (kein Strava? Trotzdem Forecast neu laden)
    }
    state = await AsyncValue.guard(() => _fetchCurrentPlan());
  }

  /// Strava-Sync im Hintergrund — kein Ladebalken, Plan bleibt sichtbar
  /// Danach Portionen automatisch anpassen wenn Training stark abweicht
  Future<void> silentSync() async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/strava/sync');
      await dio.post('/plan/adjust-portions');
      final freshPlan = await _fetchCurrentPlan();
      state = AsyncData(freshPlan);
    } catch (_) {
      // Fehler ignorieren — bestehender Plan bleibt unverändert
    }
  }

  Future<void> toggleMealSkipped(String mealId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final currentMeal = current.mealsByDay.values
        .expand((m) => m)
        .where((m) => m.id == mealId)
        .firstOrNull;
    if (currentMeal == null) return;

    final newSkipped = !currentMeal.isSkipped;
    state = AsyncData(current.withMealSkipToggled(mealId, newSkipped));

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.put('/plan/meals/$mealId/toggle-skipped');
      final serverSkipped = res.data['skipped'] as bool? ?? newSkipped;
      state = AsyncData(current.withMealSkipToggled(mealId, serverSkipped));
    } catch (_) {
      state = AsyncData(current.withMealSkipToggled(mealId, currentMeal.isSkipped));
    }
  }

  Future<void> toggleMealEaten(String mealId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    // Optimistic update: toggle locally before server responds
    final currentMeal = current.mealsByDay.values
        .expand((meals) => meals)
        .where((m) => m.id == mealId)
        .firstOrNull;
    if (currentMeal == null) return;

    state = AsyncData(current.withMealToggled(mealId, !currentMeal.isEaten));

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.put('/plan/meals/$mealId/toggle-eaten');
      final serverIsEaten = res.data['is_eaten'] as bool? ?? !currentMeal.isEaten;
      // Sync with server value (in case of race condition)
      state = AsyncData(
        (state.valueOrNull ?? current).withMealToggled(mealId, serverIsEaten),
      );
    } catch (_) {
      // Revert on error
      state = AsyncData(current.withMealToggled(mealId, currentMeal.isEaten));
    }
  }

  Future<void> requestAlternative(String mealId, {bool goBack = false}) async {
    final current = state.valueOrNull;
    if (current == null) return;

    try {
      final dio = ref.read(dioProvider);
      final direction = goBack ? 'prev' : 'next';
      final res = await dio.post('/plan/meals/$mealId/alternative?direction=$direction');
      final recipeData = res.data['recipe_data'] as Map<String, dynamic>;
      final altCount = (res.data['alternatives_count'] as num?)?.toInt() ?? 0;
      state = AsyncData((state.valueOrNull ?? current).withMealReplaced(mealId, recipeData, altCount));
    } catch (_) {
      // Leave state unchanged on error
    }
  }

  WeekPlan _parsePlan(Map<String, dynamic> data) {
    final forecast = data['training_forecast'] as Map<String, dynamic>? ?? {};
    final forecastDays = (forecast['days'] as List<dynamic>? ?? [])
        .map((d) => TrainingDay.fromJson(d as Map<String, dynamic>))
        .toList();

    final mealsList = (data['meals'] as List<dynamic>? ?? [])
        .map((m) => PlanMeal.fromJson(m as Map<String, dynamic>))
        .toList();

    final Map<String, List<PlanMeal>> byDay = {};
    for (final meal in mealsList) {
      byDay.putIfAbsent(meal.date, () => []).add(meal);
    }

    return WeekPlan(
      id: data['id'] as String,
      weekStart: data['week_start'] as String,
      trainingForecast: forecastDays,
      mealsByDay: byDay,
      weeklyLoadLevel: forecast['weeklyLoadLevel'] as String? ?? 'moderate',
    );
  }
}

final shoppingProvider = AsyncNotifierProvider<ShoppingNotifier, List<ShoppingCategory>>(() => ShoppingNotifier());

class ShoppingNotifier extends AsyncNotifier<List<ShoppingCategory>> {
  @override
  Future<List<ShoppingCategory>> build() => _fetch();

  Future<List<ShoppingCategory>> _fetch() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/shopping');
      final cats = res.data?['categories'] as Map<String, dynamic>? ?? {};
      return cats.entries.map((e) {
        final items = (e.value as List<dynamic>).map((i) {
          final m = i as Map<String, dynamic>;
          return ShoppingItem(name: m['name'] as String, amount: m['amount'] as String? ?? '');
        }).toList();
        return ShoppingCategory(name: e.key, items: items);
      }).toList();
    } on DioException {
      return [];
    }
  }
}
