import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../plan/plan_provider.dart';

class ShoppingScreen extends ConsumerWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shoppingAsync = ref.watch(shoppingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einkaufsliste'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(shoppingProvider),
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        onDestinationSelected: (i) {
          if (i == 0) context.go('/plan');
          if (i == 2) context.go('/profile');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'Plan'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), label: 'Einkauf'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
      body: shoppingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Fehler: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(shoppingProvider),
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Keine Einkaufsliste vorhanden.'),
                  SizedBox(height: 8),
                  Text('Generiere zuerst einen Wochenplan.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return _ShoppingList(categories: categories, ref: ref);
        },
      ),
    );
  }
}

class _ShoppingList extends StatefulWidget {
  final List<ShoppingCategory> categories;
  final WidgetRef ref;

  const _ShoppingList({required this.categories, required this.ref});

  @override
  State<_ShoppingList> createState() => _ShoppingListState();
}

class _ShoppingListState extends State<_ShoppingList> {
  @override
  Widget build(BuildContext context) {
    final total = widget.categories.fold(0, (sum, c) => sum + c.items.length);
    final checked = widget.categories.fold(0, (sum, c) => sum + c.items.where((i) => i.checked).length);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text('$checked / $total erledigt', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
              const Spacer(),
              if (checked > 0)
                TextButton(
                  onPressed: () => setState(() {
                    for (final cat in widget.categories) {
                      for (final item in cat.items) {
                        item.checked = false;
                      }
                    }
                  }),
                  child: const Text('Zurücksetzen'),
                ),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: total > 0 ? checked / total : 0,
          backgroundColor: Colors.grey.shade200,
        ),
        Expanded(
          child: ListView.builder(
            itemCount: widget.categories.length,
            itemBuilder: (context, i) => _CategorySection(
              category: widget.categories[i],
              onToggle: () => setState(() {}),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  final ShoppingCategory category;
  final VoidCallback onToggle;

  const _CategorySection({required this.category, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final unchecked = category.items.where((i) => !i.checked).length;
    return ExpansionTile(
      initiallyExpanded: unchecked > 0,
      title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('$unchecked von ${category.items.length} offen'),
      children: category.items.map((item) => _ShoppingItemTile(item: item, onToggle: onToggle)).toList(),
    );
  }
}

class _ShoppingItemTile extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onToggle;

  const _ShoppingItemTile({required this.item, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: item.checked,
      onChanged: (_) {
        item.checked = !item.checked;
        onToggle();
      },
      title: Text(
        item.name,
        style: item.checked ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey) : null,
      ),
      subtitle: item.amount.isNotEmpty ? Text(item.amount) : null,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
    );
  }
}
