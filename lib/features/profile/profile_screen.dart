import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../auth/auth_provider.dart';

// ─── Preferences Provider ──────────────────────────────────────────────────

class FoodPreference {
  final String id;
  final String itemName;
  final String preferenceType; // like / dislike / allergy / intolerance

  const FoodPreference({required this.id, required this.itemName, required this.preferenceType});

  factory FoodPreference.fromJson(Map<String, dynamic> j) => FoodPreference(
        id: j['id'] as String,
        itemName: j['itemName'] as String,
        preferenceType: j['preferenceType'] as String,
      );
}

final preferencesProvider =
    AsyncNotifierProvider<PreferencesNotifier, List<FoodPreference>>(() => PreferencesNotifier());

class PreferencesNotifier extends AsyncNotifier<List<FoodPreference>> {
  @override
  Future<List<FoodPreference>> build() => _fetch();

  Future<List<FoodPreference>> _fetch() async {
    final res = await ref.read(dioProvider).get('/preferences');
    final list = (res.data['preferences'] as List<dynamic>? ?? []);
    return list.map((e) => FoodPreference.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> add(String itemName, String type) async {
    await ref.read(dioProvider).post('/preferences', data: {'itemName': itemName, 'preferenceType': type});
    ref.invalidateSelf();
  }

  Future<void> remove(String id) async {
    await ref.read(dioProvider).delete('/preferences?id=$id');
    // Optimistic remove
    state = AsyncData(state.valueOrNull?.where((p) => p.id != id).toList() ?? []);
  }
}

// ─── Profile Screen ────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late Future<Map<String, dynamic>> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
    // Always refresh preferences when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(preferencesProvider);
    });
  }

  Future<Map<String, dynamic>> _loadProfile() async {
    final res = await ref.read(dioProvider).get('/profile');
    return res.data as Map<String, dynamic>? ?? {};
  }

  void _refresh() => setState(() => _profileFuture = _loadProfile());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 2,
        onDestinationSelected: (i) {
          if (i == 0) context.go('/plan');
          if (i == 1) context.go('/shopping');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'Plan'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), label: 'Einkauf'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Profil konnte nicht geladen werden'));
          }

          final data = snapshot.data ?? {};
          final profile = data['profile'] as Map<String, dynamic>? ?? {};
          final garmin = data['garmin'] as Map<String, dynamic>? ?? {};
          final strava = data['strava'] as Map<String, dynamic>? ?? {};
          final stravaConnected =
              strava['syncStatus'] != null && strava['syncStatus'] != 'not_connected';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProfileCard(
                title: 'Persönliche Daten',
                icon: Icons.person,
                children: [
                  _InfoRow('Name', data['name'] as String? ?? '—'),
                  _InfoRow('E-Mail', data['email'] as String? ?? '—'),
                  _InfoRow('Gewicht',
                      profile['weightKg'] != null ? '${profile['weightKg']} kg' : '—'),
                  _InfoRow('Größe',
                      profile['heightCm'] != null ? '${profile['heightCm']} cm' : '—'),
                ],
              ),
              const SizedBox(height: 12),
              _ProfileCard(
                title: 'Ernährungseinstellungen',
                icon: Icons.restaurant,
                children: [
                  _InfoRow('Ziel', _goalLabel(profile['nutritionGoal'] as String? ?? '')),
                  _InfoRow('Ernährung', _dietLabel(profile['dietType'] as String? ?? '')),
                  _InfoRow('Haushalt', '${profile['householdSize'] ?? 3} Personen'),
                ],
              ),
              const SizedBox(height: 12),
              // ── Allergien & Vorlieben ──
              const _PreferencesCard(),
              const SizedBox(height: 12),
              // ── Strava ──
              _ProfileCard(
                title: 'Strava',
                icon: Icons.directions_run,
                action: stravaConnected
                    ? TextButton(
                        onPressed: () => _syncStrava(context),
                        child: const Text('Syncen'),
                      )
                    : TextButton(
                        onPressed: () => _connectStrava(context),
                        child: const Text('Verbinden'),
                      ),
                children: [
                  _InfoRow('Status',
                      _stravaStatusLabel(strava['syncStatus'] as String? ?? 'not_connected')),
                  if (stravaConnected && strava['athleteName'] != null)
                    _InfoRow('Athlet', strava['athleteName'] as String),
                  _InfoRow(
                    'Letzter Sync',
                    strava['lastSyncAt'] != null
                        ? _formatDate(strava['lastSyncAt'] as String)
                        : '—',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ProfileCard(
                title: 'Garmin',
                icon: Icons.watch,
                action: garmin['syncStatus'] == 'not_connected'
                    ? TextButton(
                        onPressed: () => _connectGarmin(context), child: const Text('Verbinden'))
                    : TextButton(
                        onPressed: () => _syncGarmin(context), child: const Text('Syncen')),
                children: [
                  _InfoRow(
                      'Status', _garminStatusLabel(garmin['syncStatus'] as String? ?? 'not_connected')),
                  _InfoRow('Letzter Sync',
                      garmin['lastSyncAt'] != null ? _formatDate(garmin['lastSyncAt'] as String) : '—'),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout),
                label: const Text('Abmelden'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _connectStrava(BuildContext context) async {
    try {
      final res = await ref.read(dioProvider).get('/strava/connect');
      final authUrl = res.data['authUrl'] as String;
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Strava verbinden'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tippe auf "Browser öffnen" um dich bei Strava anzumelden. '
                'Nach der Bestätigung komme zurück und tippe "Syncen".',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(authUrl, style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Browser öffnen'),
              onPressed: () async {
                Navigator.pop(context);
                final uri = Uri.parse(authUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      _refresh();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verbindung fehlgeschlagen')));
      }
    }
  }

  Future<void> _syncStrava(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ref.read(dioProvider).post('/strava/sync');
      final count = res.data['synced'] as int? ?? 0;
      messenger.showSnackBar(SnackBar(content: Text('$count Aktivitäten synchronisiert ✅')));
      _refresh();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Sync fehlgeschlagen')));
    }
  }

  Future<void> _connectGarmin(BuildContext context) async {
    try {
      final res = await ref.read(dioProvider).get('/garmin/connect');
      final authUrl = res.data['authUrl'] as String;
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Garmin Auth URL: $authUrl')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Verbindung fehlgeschlagen')));
      }
    }
  }

  Future<void> _syncGarmin(BuildContext context) async {
    try {
      await ref.read(dioProvider).post('/garmin/sync');
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Sync gestartet')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Sync fehlgeschlagen')));
      }
    }
  }

  String _goalLabel(String goal) => switch (goal) {
        'lose_weight' => 'Abnehmen',
        'gain_weight' => 'Zunehmen',
        'maintain' => 'Halten',
        'muscle_gain' => 'Muskelaufbau',
        'performance' => 'Performance',
        _ => '—',
      };

  String _dietLabel(String diet) => switch (diet) {
        'vegetarian' => 'Vegetarisch',
        'vegan' => 'Vegan',
        _ => 'Alles',
      };

  String _stravaStatusLabel(String status) => switch (status) {
        'connected' => '✅ Verbunden',
        'error' => '❌ Sync-Fehler',
        _ => 'Nicht verbunden',
      };

  String _garminStatusLabel(String status) => switch (status) {
        'success' => '✅ Verbunden',
        'syncing' => '🔄 Synchronisiert...',
        'error' => '❌ Fehler',
        _ => 'Nicht verbunden',
      };

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.day}.${dt.month}.${dt.year}';
  }
}

// ─── Preferences Card ──────────────────────────────────────────────────────

class _PreferencesCard extends ConsumerWidget {
  const _PreferencesCard();

  static const _types = [
    ('allergy', 'Allergie', Colors.red),
    ('intolerance', 'Unverträglichkeit', Colors.orange),
    ('dislike', 'Mag ich nicht', Colors.blueGrey),
    ('like', 'Mag ich gerne', Colors.green),
  ];

  Color _colorForType(String type) => switch (type) {
        'allergy' => Colors.red,
        'intolerance' => Colors.orange,
        'dislike' => Colors.blueGrey,
        'like' => Colors.green,
        _ => Colors.grey,
      };

  String _labelForType(String type) => switch (type) {
        'allergy' => 'Allergie',
        'intolerance' => 'Unverträglichkeit',
        'dislike' => 'Mag ich nicht',
        'like' => 'Mag ich gerne',
        _ => type,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(preferencesProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite_border,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Allergien & Vorlieben',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Hinzufügen',
                  onPressed: () => _showAddDialog(context, ref),
                ),
              ],
            ),
            const Divider(height: 16),
            prefsAsync.when(
              loading: () => const Center(
                  child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2))),
              error: (_, __) => const Text('Fehler beim Laden'),
              data: (prefs) {
                if (prefs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Noch keine Einträge. Tippe + um Allergien, Abneigungen oder Lieblingsessen einzutragen.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  );
                }

                // Group by type
                final grouped = <String, List<FoodPreference>>{};
                for (final p in prefs) {
                  grouped.putIfAbsent(p.preferenceType, () => []).add(p);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (typeKey, typeLabel, _) in _types)
                      if (grouped.containsKey(typeKey)) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Text(typeLabel,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _colorForType(typeKey))),
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: grouped[typeKey]!
                              .map((p) => _PrefChip(
                                    label: p.itemName,
                                    color: _colorForType(typeKey),
                                    onDelete: () =>
                                        ref.read(preferencesProvider.notifier).remove(p.id),
                                  ))
                              .toList(),
                        ),
                      ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    String selectedType = 'dislike';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Eintrag hinzufügen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Zutat / Gericht',
                  hintText: 'z.B. Nüsse, Laktose, Hähnchen...',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text('Kategorie:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _types.map((t) {
                  final (key, label, color) = t;
                  final selected = selectedType == key;
                  return ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    selectedColor: color.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: selected ? color : Colors.grey.shade700,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setDialogState(() => selectedType = key),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await ref.read(preferencesProvider.notifier).add(name, selectedType);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Fehler beim Speichern')));
                  }
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }
}

class _PrefChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onDelete;

  const _PrefChip({required this.label, required this.color, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 13)),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.4)),
      deleteIcon: Icon(Icons.close, size: 14, color: color),
      onDeleted: onDelete,
    );
  }
}

// ─── Shared Widgets ────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? action;

  const _ProfileCard(
      {required this.title, required this.icon, required this.children, this.action});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                if (action != null) action!,
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
