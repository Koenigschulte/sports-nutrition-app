import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'plan_provider.dart';

class WeekPlanScreen extends ConsumerWidget {
  const WeekPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(weekPlanProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mein Wochenplan'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (i) {
          if (i == 1) context.go('/shopping');
          if (i == 2) context.go('/profile');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'Plan'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), label: 'Einkauf'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showVoiceInput(context, ref),
        icon: const Icon(Icons.mic),
        label: const Text('Spracheingabe'),
      ),
      body: planAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Fehler: $e'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => ref.refresh(weekPlanProvider), child: const Text('Erneut versuchen')),
            ],
          ),
        ),
        data: (plan) {
          if (plan == null) {
            return _EmptyPlanView(onGenerate: () => ref.read(weekPlanProvider.notifier).generatePlan());
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(weekPlanProvider.notifier).syncAndRefresh(),
            child: _PlanView(plan: plan, ref: ref),
          );
        },
      ),
    );
  }

  void _showVoiceInput(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _VoiceInputSheet(),
    );
  }
}

class _EmptyPlanView extends StatelessWidget {
  final VoidCallback onGenerate;
  const _EmptyPlanView({required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant_menu, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            Text('Noch kein Wochenplan', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            const Text('Ich erstelle dir einen personalisierten Ernährungsplan basierend auf deinen Garmin-Daten.', textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Plan generieren'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanView extends StatelessWidget {
  final WeekPlan plan;
  final WidgetRef ref;

  const _PlanView({required this.plan, required this.ref});

  String _weekdayLabel(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      const names = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
      return '${names[date.weekday - 1]}, ${date.day}.${date.month}.';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = plan.mealsByDay.keys.toList()..sort();
    final forecastByDate = {for (final t in plan.trainingForecast) t.date: t};

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: days.length,
      itemBuilder: (context, i) {
        final day = days[i];
        final meals = plan.mealsByDay[day]!;
        final training = forecastByDate[day];
        return _DayCard(
          dayLabel: _weekdayLabel(day),
          meals: meals,
          training: training,
        );
      },
    );
  }
}

class _DayCard extends StatelessWidget {
  final String dayLabel;
  final List<PlanMeal> meals;
  final TrainingDay? training;

  const _DayCard({required this.dayLabel, required this.meals, this.training});

  @override
  Widget build(BuildContext context) {
    final hasTraining = training != null && training!.hasTraining;
    final totalCalories = meals.fold(0, (sum, m) => sum + m.calories);
    final eatenCalories = meals.where((m) => m.isEaten).fold(0, (sum, m) => sum + m.calories);
    final progress = totalCalories > 0 ? (eatenCalories / totalCalories).clamp(0.0, 1.0) : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                color: progress >= 1.0
                    ? Colors.green
                    : Theme.of(context).colorScheme.primary,
                strokeWidth: 4,
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            Text(dayLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (hasTraining) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _activityColor(training!.activityType).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_activityIcon(training!.activityType),
                        size: 12, color: _activityColor(training!.activityType)),
                    const SizedBox(width: 3),
                    Text(
                      _activityLabel(training!.activityType),
                      style: TextStyle(
                        fontSize: 11,
                        color: _activityColor(training!.activityType),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '$eatenCalories / $totalCalories kcal · ${meals.length} Mahlzeiten'
          '${hasTraining ? ' · ${training!.durationMinutes} min' : ''}',
        ),
        children: [
          if (hasTraining) _TrainingBanner(training: training!),
          ...meals.map((meal) => _MealTile(meal: meal)),
        ],
      ),
    );
  }

  IconData _activityIcon(String type) => switch (type) {
    'running' => Icons.directions_run,
    'cycling' => Icons.directions_bike,
    'swimming' => Icons.pool,
    'tennis' => Icons.sports_tennis,
    'strength' || 'crossfit' => Icons.fitness_center,
    'walking' || 'hiking' => Icons.hiking,
    'soccer' => Icons.sports_soccer,
    'rowing' || 'kayaking' => Icons.rowing,
    'skiing' => Icons.downhill_skiing,
    _ => Icons.sports,
  };

  Color _activityColor(String type) => switch (type) {
    'running' => Colors.orange,
    'cycling' => Colors.blue,
    'swimming' => Colors.teal,
    'tennis' => Colors.yellow.shade700,
    'strength' || 'crossfit' => Colors.red,
    'walking' || 'hiking' => Colors.green,
    _ => Colors.purple,
  };

  String _activityLabel(String type) => switch (type) {
    'running' => 'Laufen',
    'cycling' => 'Radfahren',
    'swimming' => 'Schwimmen',
    'tennis' => 'Tennis',
    'strength' || 'crossfit' => 'Kraft',
    'walking' => 'Spazieren',
    'hiking' => 'Wandern',
    'soccer' => 'Fußball',
    'rowing' => 'Rudern',
    'skiing' => 'Skifahren',
    _ => 'Training',
  };
}

class _TrainingBanner extends StatelessWidget {
  final TrainingDay training;
  const _TrainingBanner({required this.training});

  @override
  Widget build(BuildContext context) {
    final dominantColor = _color(training.activityType);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dominantColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dominantColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header-Zeile: Gesamt + kcal-Badge
          Row(
            children: [
              if (!training.isActual)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Text('Prognose', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                ),
              Text(
                training.isActual
                    ? '${training.durationMinutes} min · ${training.estimatedCalories} kcal'
                    : '${training.durationMinutes} min · ~${training.estimatedCalories} kcal',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: dominantColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${training.estimatedCalories} kcal',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: dominantColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Einzelne Aktivitäten (Strava) oder Prognose-Zeile
          if (training.isActual && training.activities.isNotEmpty)
            ...training.activities.map((act) => _ActivityRow(activity: act))
          else
            _ForecastRow(training: training),
          // Intensitätsbalken nur bei Prognose (bei echter Aktivität pro Zeile)
          if (!training.isActual) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(_intensityLabel(training.intensityLevel),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _intensityPct(training.intensityLevel),
                      backgroundColor: Colors.grey.shade200,
                      color: dominantColor,
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _color(String type) => switch (type) {
    'running' => Colors.orange,
    'cycling' => Colors.blue,
    'swimming' => Colors.teal,
    'tennis' => Colors.yellow.shade700,
    'strength' || 'crossfit' => Colors.red,
    'walking' || 'hiking' => Colors.green,
    _ => Colors.purple,
  };

  String _intensityLabel(String level) => switch (level) {
    'easy' => 'Leicht',
    'moderate' => 'Moderat',
    'hard' => 'Intensiv',
    'very_hard' => 'Sehr intensiv',
    _ => 'Ruhetag',
  };

  double _intensityPct(String level) => switch (level) {
    'easy' => 0.25,
    'moderate' => 0.55,
    'hard' => 0.80,
    'very_hard' => 1.0,
    _ => 0.0,
  };
}

// Einzelne echte Aktivität aus Strava
class _ActivityRow extends StatelessWidget {
  final ActivityEntry activity;
  const _ActivityRow({required this.activity});

  @override
  Widget build(BuildContext context) {
    final color = _color(activity.activityType);
    final parts = <String>[
      '${activity.durationMinutes} min',
      '${activity.calories} kcal',
      if (activity.distanceKm != null)
        '${activity.distanceKm!.toStringAsFixed(2).replaceAll('.', ',')} km',
      if (activity.avgHeartRate != null)
        '♥ ${activity.avgHeartRate} bpm',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(_icon(activity.activityType), color: color, size: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_label(activity.activityType),
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: color)),
                Text(parts.join('  ·  '),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          SizedBox(
            width: 56,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _intensityPct(activity.intensityLevel),
                backgroundColor: Colors.grey.shade200,
                color: color,
                minHeight: 5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon(String type) => switch (type) {
    'running' => Icons.directions_run,
    'cycling' => Icons.directions_bike,
    'swimming' => Icons.pool,
    'tennis' => Icons.sports_tennis,
    'strength' || 'crossfit' => Icons.fitness_center,
    'walking' || 'hiking' => Icons.hiking,
    'soccer' => Icons.sports_soccer,
    'rowing' || 'kayaking' => Icons.rowing,
    'skiing' => Icons.downhill_skiing,
    _ => Icons.sports,
  };

  Color _color(String type) => switch (type) {
    'running' => Colors.orange,
    'cycling' => Colors.blue,
    'swimming' => Colors.teal,
    'tennis' => Colors.yellow.shade700,
    'strength' || 'crossfit' => Colors.red,
    'walking' || 'hiking' => Colors.green,
    _ => Colors.purple,
  };

  String _label(String type) => switch (type) {
    'running' => 'Laufen',
    'cycling' => 'Radfahren',
    'swimming' => 'Schwimmen',
    'tennis' => 'Tennis',
    'strength' || 'crossfit' => 'Krafttraining',
    'walking' => 'Spazieren',
    'hiking' => 'Wandern',
    'soccer' => 'Fußball',
    'rowing' => 'Rudern',
    'skiing' => 'Skifahren',
    _ => 'Training',
  };

  double _intensityPct(String level) => switch (level) {
    'easy' => 0.25,
    'moderate' => 0.55,
    'hard' => 0.80,
    'very_hard' => 1.0,
    _ => 0.0,
  };
}

// Prognose-Zeile (keine echten Strava-Daten)
class _ForecastRow extends StatelessWidget {
  final TrainingDay training;
  const _ForecastRow({required this.training});

  @override
  Widget build(BuildContext context) {
    final color = _color(training.activityType);
    return Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(_icon(training.activityType), color: color, size: 13),
        ),
        const SizedBox(width: 8),
        Text(
          _label(training.activityType),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
        ),
        if (training.distanceKm != null) ...[
          Text('  ·  ${training.distanceKm!.toStringAsFixed(2).replaceAll('.', ',')} km',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ],
    );
  }

  IconData _icon(String type) => switch (type) {
    'running' => Icons.directions_run,
    'cycling' => Icons.directions_bike,
    'swimming' => Icons.pool,
    'strength' || 'crossfit' => Icons.fitness_center,
    'walking' || 'hiking' => Icons.hiking,
    _ => Icons.sports,
  };

  Color _color(String type) => switch (type) {
    'running' => Colors.orange,
    'cycling' => Colors.blue,
    'swimming' => Colors.teal,
    'strength' || 'crossfit' => Colors.red,
    'walking' || 'hiking' => Colors.green,
    _ => Colors.purple,
  };

  String _label(String type) => switch (type) {
    'running' => 'Laufen',
    'cycling' => 'Radfahren',
    'swimming' => 'Schwimmen',
    'tennis' => 'Tennis',
    'strength' || 'crossfit' => 'Krafttraining',
    'walking' => 'Spazieren',
    'hiking' => 'Wandern',
    _ => 'Training',
  };
}

class _MealTile extends ConsumerStatefulWidget {
  final PlanMeal meal;
  const _MealTile({required this.meal});

  @override
  ConsumerState<_MealTile> createState() => _MealTileState();
}

class _MealTileState extends ConsumerState<_MealTile> {
  bool _isLoading = false;

  Future<void> _requestAlternative({bool goBack = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(weekPlanProvider.notifier).requestAlternative(widget.meal.id, goBack: goBack);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _mealColor(meal.type),
        child: Icon(_mealIcon(meal.type), color: Colors.white, size: 18),
      ),
      title: Text(
        meal.recipeName,
        style: meal.isEaten
            ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)
            : null,
      ),
      subtitle: Text(
        '${meal.calories} kcal · ${meal.proteinG}g Protein · ⏱ ${meal.prepMinutes} min',
        style: meal.isEaten ? const TextStyle(color: Colors.grey) : null,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (meal.isTogo) const Chip(label: Text('To-Go')),
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: (meal.alternativesCount > 0 && !_isLoading)
                ? () => _requestAlternative(goBack: true)
                : null,
          ),
          if (_isLoading)
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: _requestAlternative,
            ),
          Checkbox(
            value: meal.isEaten,
            onChanged: (_) => ref.read(weekPlanProvider.notifier).toggleMealEaten(meal.id),
          ),
        ],
      ),
      onTap: () => _showMealDetail(context, meal),
    );
  }

  Color _mealColor(String type) {
    return switch (type) {
      'breakfast' => Colors.orange,
      'lunch' => Colors.green,
      'dinner' => Colors.blue,
      _ => Colors.grey,
    };
  }

  IconData _mealIcon(String type) {
    return switch (type) {
      'breakfast' => Icons.wb_sunny_outlined,
      'lunch' => Icons.lunch_dining,
      'dinner' => Icons.dinner_dining,
      _ => Icons.cookie_outlined,
    };
  }

  void _showMealDetail(BuildContext context, PlanMeal meal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => _MealDetailSheet(meal: meal, scrollCtrl: ctrl),
      ),
    );
  }
}

class _MealDetailSheet extends StatelessWidget {
  final PlanMeal meal;
  final ScrollController scrollCtrl;

  const _MealDetailSheet({required this.meal, required this.scrollCtrl});

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(24),
      children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Text(meal.recipeName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            Chip(label: Text('${meal.calories} kcal')),
            Chip(label: Text('${meal.proteinG}g Protein')),
            Chip(label: Text('${meal.carbsG}g Kohlenhydrate')),
            Chip(label: Text('${meal.fatG}g Fett')),
            if (meal.isTogo) const Chip(label: Text('To-Go')),
          ],
        ),
        const SizedBox(height: 16),
        Text('Zutaten', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...meal.ingredients.map((ing) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('• $ing'))),
        const SizedBox(height: 16),
        Text('Zubereitung', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(meal.instructions),
      ],
    );
  }
}

class _VoiceInputSheet extends ConsumerStatefulWidget {
  const _VoiceInputSheet();

  @override
  ConsumerState<_VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends ConsumerState<_VoiceInputSheet> {
  bool _listening = false;
  final String _transcript = '';
  String _response = '';

  void _toggleListening() {
    // Voice integration kommt in Phase 4
    setState(() {
      _listening = !_listening;
      if (!_listening && _transcript.isNotEmpty) {
        _response = 'Ich habe verstanden: "$_transcript". Ich passe deinen Plan entsprechend an.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Sprachassistent', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Sprich mit mir — ich passe deinen Plan an.', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _toggleListening,
            child: CircleAvatar(
              radius: 40,
              backgroundColor: _listening ? Colors.red : Theme.of(context).colorScheme.primary,
              child: Icon(_listening ? Icons.stop : Icons.mic, size: 36, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          if (_transcript.isNotEmpty) Text('"$_transcript"', style: const TextStyle(fontStyle: FontStyle.italic)),
          if (_response.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
              child: Text(_response),
            ),
          ],
          const SizedBox(height: 16),
          Text(_listening ? 'Höre zu...' : 'Tippe auf das Mikrofon', style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
