import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../reviews/review_widgets.dart';
import '../../../core/config/env.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/shimmer.dart';
import '../../cart/application/cart_controller.dart';
import '../../service_area/application/pincode_controller.dart';
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
        loading: const DetailSkeleton(),
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
    final catalogue = ref.watch(productsProvider(allProductsQuery));
    final related = similarProducts(
      catalogue.valueOrNull ?? const <Product>[],
      [product],
    );
    final savedPaise = product.mrpPaise - product.pricePaise;
    final settings = ref.watch(storeSettingsProvider);
    final outstation = ref.watch(shopModeProvider) == ShopMode.outstation;

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
                        ProductImageCarousel(product: product),
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
                    if (product.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        product.subtitle,
                        key: const ValueKey('product-subtitle'),
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      product.unit,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (product.inStock &&
                        product.stockQty != null &&
                        product.stockQty! <= AppConfig.maxQtyPerItem) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Only ${product.stockQty} left in stock',
                        key: const ValueKey('low-stock'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentDark,
                        ),
                      ),
                    ],
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
                        outstation
                            ? _Perk(
                                Icons.local_shipping_rounded,
                                settings.courierEta,
                                'delivery',
                              )
                            : _Perk(
                                Icons.bolt_rounded,
                                '${settings.deliveryEtaMinutes} min',
                                'delivery',
                              ),
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
                    ProductReviews(productId: product.id),
                  ],
                ),
              ),
              if (catalogue.isLoading || related.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 10),
                  child: Text(
                    'Similar products',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                if (related.isEmpty)
                  const ProductRailSkeleton()
                else
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

/// Swipeable photos for the product page: up to [Product.maxImages], with
/// page dots and a counter. A product with one photo, or none, shows a
/// single picture with no controls.
class ProductImageCarousel extends StatefulWidget {
  const ProductImageCarousel({super.key, required this.product});

  final Product product;

  @override
  State<ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<ProductImageCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final images = product.imageUrls;
    if (images.length <= 1) {
      return ProductImage(product: product, artSize: 132);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          key: const ValueKey('product-image-carousel'),
          controller: _controller,
          itemCount: images.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) => Image.network(
            images[i],
            fit: BoxFit.cover,
            semanticLabel: '${product.name}, photo ${i + 1}',
            // A broken link falls back to the product's artwork.
            errorBuilder: (_, __, ___) =>
                ProductArt(product: product, artSize: 132),
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Shimmer(child: SkeletonBox(radius: 0)),
          ),
        ),
        Positioned(
          right: 12,
          top: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x99000000),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_page + 1}/${images.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < images.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _page ? Colors.white : const Color(0x99FFFFFF),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(color: Color(0x33000000), blurRadius: 3),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
