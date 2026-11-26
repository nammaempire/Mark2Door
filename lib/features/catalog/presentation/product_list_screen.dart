import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/shimmer.dart';
import '../application/catalog_providers.dart';
import '../../service_area/presentation/delivery_banner.dart';
import '../../requests/request_product_card.dart';
import 'product_widgets.dart';

class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProductQuery query = (categoryId: categoryId, query: '');
    final products = ref.watch(productsProvider(query));
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final title = categories
            .where((c) => c.id == categoryId)
            .map((c) => c.name)
            .firstOrNull ??
        'Products';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: AsyncValueView(
              value: products,
              loading: const CustomScrollView(
                physics: NeverScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: SizedBox(height: 12)),
                  ProductGridSkeleton(),
                ],
              ),
              onRetry: () => ref.invalidate(productsProvider(query)),
              data: (items) => items.isEmpty
                  ? const SingleChildScrollView(
                      child: Column(
                        children: [
                          EmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'Nothing here yet',
                            message:
                                'Products in this category will appear here.',
                          ),
                          RequestProductCard(),
                        ],
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        const SliverToBoxAdapter(
                          child: NotServiceableBanner(
                            margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                        ProductGrid(products: items),
                        // Not here? The shopper can ask the store for it.
                        const SliverToBoxAdapter(child: RequestProductCard()),
                      ],
                    ),
            ),
          ),
          const CartBar(),
        ],
      ),
    );
  }
}
