import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/shimmer.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/presentation/product_widgets.dart';
import '../../service_area/application/pincode_controller.dart';
import '../../service_area/presentation/delivery_banner.dart';
import '../application/cart_controller.dart';
import '../domain/cart.dart';
import 'bill_summary.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final canOrder = ref.watch(canOrderProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your cart')),
      body: cart.isEmpty
          ? EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Your cart is empty',
              message: 'Add items from the shop to get started.',
              actionLabel: 'Start shopping',
              onAction: () => context.go(Routes.home),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                    children: [
                      const NotServiceableBanner(
                        margin: EdgeInsets.fromLTRB(16, 0, 16, 12),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (cart.toFreeDeliveryPaise > 0)
                              _FreeDeliveryHint(cart: cart),
                            Card(
                              child: Column(
                                children: [
                                  for (final (i, line)
                                      in cart.lines.indexed) ...[
                                    if (i > 0)
                                      const Divider(indent: 16, endIndent: 16),
                                    _CartLine(item: line),
                                  ],
                                ],
                              ),
                            ),
                            const SectionLabel('Order summary'),
                            OrderSummaryCard(
                              subtotalPaise: cart.subtotalPaise,
                              mrpTotalPaise: cart.mrpTotalPaise,
                              deliveryFeePaise: cart.deliveryFeePaise,
                              handlingFeePaise: cart.handlingFeePaise,
                              rainFeePaise: cart.rainFeePaise,
                              totalPaise: cart.totalPaise,
                            ),
                          ],
                        ),
                      ),
                      _SimilarProducts(cart: cart),
                    ],
                  ),
                ),
                BottomActionBar(
                  child: FilledButton(
                    key: const ValueKey('checkout-button'),
                    // Outside the delivery area the banner above explains
                    // why ordering is off.
                    onPressed:
                        canOrder ? () => context.push(Routes.checkout) : null,
                    child: Text(
                      'Proceed to checkout  ·  ${formatPaise(cart.totalPaise)}',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// "You might also like": a sideways row of products that go with what
/// is in the cart, so the page offers something to add.
class _SimilarProducts extends ConsumerWidget {
  const _SimilarProducts({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const title = Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: SectionLabel('You might also like'),
    );
    return ref.watch(productsProvider(allProductsQuery)).when(
          loading: () => const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, ProductRailSkeleton()],
          ),
          // Suggestions are a bonus; the cart works without them.
          error: (_, __) => const SizedBox.shrink(),
          data: (all) {
            final similar =
                similarProducts(all, cart.lines.map((l) => l.product));
            if (similar.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                ProductRail(products: similar, keyPrefix: 'similar'),
              ],
            );
          },
        );
  }
}

class _FreeDeliveryHint extends StatelessWidget {
  const _FreeDeliveryHint({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_outlined,
              size: 20, color: AppColors.primaryDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Add ${formatPaise(cart.toFreeDeliveryPaise)} more for free '
              'delivery',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 60,
              height: 60,
              child: ProductImage(product: product, artSize: 30),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.unit,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatPaise(item.lineTotalPaise),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 96, child: QtyStepper(product: product)),
        ],
      ),
    );
  }
}
