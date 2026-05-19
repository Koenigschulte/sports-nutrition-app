import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;

  // Form values
  String _dietType = 'all';
  String _nutritionGoal = 'maintain';
  int _householdSize = 3;
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentPage++);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/profile', data: {
        'dietType': _dietType,
        'nutritionGoal': _nutritionGoal,
        'householdSize': _householdSize,
        if (_weightCtrl.text.isNotEmpty) 'weightKg': double.tryParse(_weightCtrl.text),
        if (_heightCtrl.text.isNotEmpty) 'heightCm': int.tryParse(_heightCtrl.text),
      });
      if (mounted) context.go('/plan');
    } on DioException {
      if (mounted) context.go('/plan');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Einrichtung ${_currentPage + 1}/3'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_currentPage + 1) / 3),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [_dietPage(), _goalPage(), _bodyPage()],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _nextPage,
                    child: Text(_currentPage < 2 ? 'Weiter' : 'Los geht\'s'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _dietPage() {
    return _PageWrapper(
      title: 'Wie ernährst du dich?',
      subtitle: 'Dein Ernährungsplan wird entsprechend angepasst.',
      child: Column(
        children: [
          _ChoiceCard(label: 'Alles', value: 'all', selected: _dietType == 'all', icon: Icons.restaurant, onTap: () => setState(() => _dietType = 'all')),
          const SizedBox(height: 12),
          _ChoiceCard(label: 'Vegetarisch', value: 'vegetarian', selected: _dietType == 'vegetarian', icon: Icons.eco, onTap: () => setState(() => _dietType = 'vegetarian')),
          const SizedBox(height: 12),
          _ChoiceCard(label: 'Vegan', value: 'vegan', selected: _dietType == 'vegan', icon: Icons.grass, onTap: () => setState(() => _dietType = 'vegan')),
        ],
      ),
    );
  }

  Widget _goalPage() {
    final goals = [
      ('lose_weight', 'Gewicht abnehmen', Icons.trending_down),
      ('gain_weight', 'Gewicht zunehmen', Icons.trending_up),
      ('maintain', 'Gewicht halten', Icons.balance),
      ('muscle_gain', 'Muskelaufbau', Icons.fitness_center),
      ('performance', 'Performance steigern', Icons.bolt),
    ];
    return _PageWrapper(
      title: 'Was ist dein Ziel?',
      subtitle: 'Wähle dein aktuelles Hauptziel.',
      child: Column(
        children: goals.map((g) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ChoiceCard(label: g.$2, value: g.$1, selected: _nutritionGoal == g.$1, icon: g.$3, onTap: () => setState(() => _nutritionGoal = g.$1)),
        )).toList(),
      ),
    );
  }

  Widget _bodyPage() {
    return _PageWrapper(
      title: 'Dein Körper',
      subtitle: 'Optional — oder wir holen die Daten aus Garmin.',
      child: Column(
        children: [
          TextFormField(
            controller: _weightCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Gewicht (kg)', prefixIcon: Icon(Icons.monitor_weight_outlined)),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _heightCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Größe (cm)', prefixIcon: Icon(Icons.height)),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text('Haushaltsgröße:'),
              const SizedBox(width: 16),
              IconButton(icon: const Icon(Icons.remove), onPressed: () => setState(() => _householdSize = (_householdSize - 1).clamp(1, 20))),
              Text('$_householdSize', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.add), onPressed: () => setState(() => _householdSize = (_householdSize + 1).clamp(1, 20))),
              const Text('Personen'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageWrapper extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _PageWrapper({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const _ChoiceCard({required this.label, required this.value, required this.selected, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Theme.of(context).colorScheme.primary : Colors.grey),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
            const Spacer(),
            if (selected) Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
