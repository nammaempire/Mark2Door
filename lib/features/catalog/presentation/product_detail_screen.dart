import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../cart/application/cart_controller.dart';
import '../../store/application/store_providers.dart';
import '../application/catalog_providers.dart';
import '../domain/product.dart';
import 'product_widgets.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(productId));

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Cart',
            onPressed: () => context.push(Routes.cart),
            icon: Consumer(
              builder: (context, ref, _) {
                final count =
                    ref.watch(cartProvider.select((c) => c.totalQuantity));
                return Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.shopping_bag_outlined),
                );
              },
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AsyncValueView(
        value: product,
        onRetry: () => ref.invalidate(productProvider(productId)),
        data: (p) => p == null
            ? const EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Product not available',
                message: 'It may have been removed from the store.',
              )
            : _Body(product: p),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProductQuery relatedQuery =
        (categoryId: product.categoryId, query: '');
    final related = (ref.watch(productsProvider(relatedQuery)).valueOrNull ??
            const <Product>[])
        .where((p) => p.id != product.id)
        .toList(growable: false);
    final savedPaise = product.mrpPaise - product.pricePaise;
    final eta = ref.watch(storeSettingsProvider).deliveryEtaMinutes;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: AspectRatio(
                    aspectRatio: 1.3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ProductImage(product: product, artSize: 132),
                        if (product.discountPercent > 0)
                          Align(
                            alignment: Alignment.topLeft,
                            child: DiscountBadge(
                              percent: product.discountPercent,
                              large: true,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.unit,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        PriceRow(product: product, fontSize: 24),
                        if (savedPaise > 0) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Save ${formatPaise(savedPaise)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Inclusive of all taxes',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _Perk(Icons.bolt_rounded, '$eta min', 'delivery'),
                        const SizedBox(width: 10),
                        const _Perk(
                          Icons.verified_rounded,
                          'Quality',
                          'checked',
                        ),
                        const SizedBox(width: 10),
                        const _Perk(Icons.replay_rounded, 'Easy', 'returns'),
                      ],
                    ),
                    if (product.description.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      const Text(
                        'About this product',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.description,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (related.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 10),
                  child: Text(
                    'You might also like',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                ProductRail(products: related, keyPrefix: 'related'),
              ],
            ],
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 130,
                    child: QtyStepper(
                      product: product,
                      height: 52,
                      keyPrefix: 'detail',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => context.push(Routes.cart),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Go to cart'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
