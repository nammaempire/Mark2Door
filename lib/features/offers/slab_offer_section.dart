import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../cart/application/cart_controller.dart';
import '../cart/domain/cart.dart';
import '../catalog/application/catalog_providers.dart';
import '../catalog/domain/product.dart';
import '../catalog/presentation/product_widgets.dart';
import 'slab_offers.dart';

/// On the cart page: the store's price slab offers.
///
/// - A product already picked is shown with its offer price and a way to
///   remove it.
/// - Every offer's products are always listed. Below the offer's amount
///   the list is locked and says how much more to add; at the amount the
///   "Add for ₹9" buttons work. The shopper picks one in all.
class SlabOfferSection extends ConsumerWidget {
  const SlabOfferSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final picked = cart.offer;
    if (picked != null) return _PickedCard(offer: picked);

    final offers = ref.watch(slabOffersProvider).valueOrNull ?? const [];
    if (offers.isEmpty) return const SizedBox.shrink();
    // Only products this shopper can buy now: in their store, in stock.
    final catalogue =
        ref.watch(productsProvider(allProductsQuery)).valueOrNull ?? const [];
    final byId = {for (final p in catalogue) p.id: p};
    List<Product> productsOf(SlabOffer o) => [
          for (final id in o.productIds)
            if (byId[id] case final p?
                // Left out: sold out, or already cheaper than the offer.
                when p.inStock &&
                    p.pricePaise > o.offerPricePaise &&
                    p.maxPerOrder(1 << 20) > cart.quantityOf(p.id))
              p,
        ];

    // Every offer's list is always on show. Below its amount a list is
    // locked: greyed out, with how much more to add. At the amount it
    // unlocks and the buttons work.
    final items = cart.itemsSubtotalPaise;
    final shown = [
      for (final o in offers)
        if (productsOf(o).isNotEmpty) o,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();

    return Column(
      key: const ValueKey('slab-offers'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final o in shown)
          _OfferList(
            offer: o,
            products: productsOf(o),
            toAddPaise: o.unlockedBy(items) ? 0 : o.minOrderPaise - items,
            itemsPaise: items,
          ),
      ],
    );
  }
}

class _OfferList extends ConsumerWidget {
  const _OfferList({
    required this.offer,
    required this.products,
    required this.toAddPaise,
    required this.itemsPaise,
  });

  final SlabOffer offer;
  final List<Product> products;

  /// How much more the cart needs; 0 once the offer is unlocked.
  final int toAddPaise;
  final int itemsPaise;

  bool get locked => toAddPaise > 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: ValueKey('offer-list-${offer.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 0, 12),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                locked ? Icons.lock_rounded : Icons.redeem_rounded,
                size: 20,
                color: AppColors.accentDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  locked
                      ? 'Add ${formatPaise(toAddPaise)} more to unlock: pick '
                          'any one for ${formatPaise(offer.offerPricePaise)}'
                      : 'Offer unlocked: pick any one for '
                          '${formatPaise(offer.offerPricePaise)}',
                  key: locked ? ValueKey('offer-hint-${offer.id}') : null,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentDark,
                  ),
                ),
              ),
              const SizedBox(width: 14),
            ],
          ),
          if (locked) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (itemsPaise / offer.minOrderPaise).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.white,
                  color: AppColors.accentDark,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 14),
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final p = products[i];
                return Container(
                  width: 124,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Opacity(
                        opacity: locked ? 0.45 : 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            height: 56,
                            child: ProductImage(product: p, artSize: 28),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        p.unit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: _OfferPrice(
                          pricePaise: offer.offerPricePaise,
                          wasPaise: p.pricePaise,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 32,
                        child: FilledButton(
                          key: ValueKey('offer-pick-${offer.id}-${p.id}'),
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                          ),
                          // Off until the cart reaches the amount.
                          onPressed: locked
                              ? null
                              : () {
                            final problem = ref
                                .read(cartProvider.notifier)
                                .pickOffer(offer, p);
                            if (problem != null) {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(content: Text(problem)),
                                );
                            }
                          },
                          child: locked
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.lock_rounded, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Locked',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ],
                                )
                              : Text(
                                  'Add for '
                                  '${formatPaise(offer.offerPricePaise)}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferPrice extends StatelessWidget {
  const _OfferPrice({required this.pricePaise, required this.wasPaise});

  final int pricePaise;
  final int wasPaise;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatPaise(pricePaise),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        if (wasPaise > pricePaise) ...[
          const SizedBox(width: 6),
          Text(
            formatPaise(wasPaise),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      ],
    );
  }
}

/// The product the shopper picked, with the offer price.
class _PickedCard extends ConsumerWidget {
  const _PickedCard({required this.offer});

  final CartOffer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = offer.product;
    return Container(
      key: const ValueKey('offer-picked'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 56,
              height: 56,
              child: ProductImage(product: product, artSize: 28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'OFFER PRODUCT',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${product.name} · ${product.unit}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                _OfferPrice(
                  pricePaise: offer.pricePaise,
                  wasPaise: offer.sellingPricePaise,
                ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey('offer-remove'),
            onPressed: () => ref.read(cartProvider.notifier).removeOffer(),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
