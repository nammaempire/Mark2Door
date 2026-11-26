import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_value_view.dart';
import '../application/catalog_providers.dart';
import 'home_screen.dart';

/// The Categories tab: every category the store has, as a grid of
/// picture tiles. Tapping one opens that category's products.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: categories.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => EmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'Could not load the categories',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(categoriesProvider),
        ),
        data: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.category_outlined,
                title: 'No categories yet',
                message: 'The store has not added any categories.',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(categoriesProvider),
                child: GridView.builder(
                  key: const ValueKey('categories-grid'),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 104,
                    mainAxisExtent: 132,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) => Center(
                    child: CategoryTile(
                      key: ValueKey('category-tile-${items[i].id}'),
                      category: items[i],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
