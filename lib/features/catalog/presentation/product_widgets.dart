import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../cart/application/cart_controller.dart';
import '../../service_area/application/pincode_controller.dart';
import '../../store/application/store_providers.dart';
import '../application/catalog_providers.dart';
import '../domain/product.dart';

/// Visual identity of a category: artwork and a pastel tint. Keyed by the
/// category's `icon` value so Firestore stays UI-agnostic.
@immutable
class CategoryStyle {
  const CategoryStyle(this.emoji, this.tint, this.deep);

  final String emoji;

  /// Light and deeper shade of the category colour.
  final Color tint;
  final Color deep;

  /// Diagonal gradient for artwork tiles.
  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [tint, deep],
      );

  /// Soft top-to-bottom wash for whole cards; stays light so text reads well.
  LinearGradient get cardGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.surface, Color.lerp(AppColors.surface, deep, 0.55)!],
      );

  static const _fallback =
      CategoryStyle('🛒', AppColors.primarySoft, Color(0xFFF4BECA));
  static const _styles = <String, CategoryStyle>{
    'fruits': CategoryStyle('🥬', Color(0xFFEAF8E8), Color(0xFFB9E6B4)),
    'dairy': CategoryStyle('🥛', Color(0xFFE8F2FF), Color(0xFFB5D4FF)),
    'staples': CategoryStyle('🌾', Color(0xFFFFF6DC), Color(0xFFFFDD8F)),
    'snacks': CategoryStyle('🍿', Color(0xFFFFEDE3), Color(0xFFFFC3A6)),
    'beverages': CategoryStyle('🧃', Color(0xFFF4ECFF), Color(0xFFD5BDFF)),
    'household': CategoryStyle('🧼', Color(0xFFE4F7F6), Color(0xFFAEE4E0)),
    'bakery': CategoryStyle('🍞', Color(0xFFFFF1DE), Color(0xFFF6CF9B)),
    'meat': CategoryStyle('🍗', Color(0xFFFFE8E8), Color(0xFFFFB9B9)),
    'frozen': CategoryStyle('🍦', Color(0xFFE6F6FF), Color(0xFFAEDCF7)),
    'personal': CategoryStyle('🧴', Color(0xFFFFEAF3), Color(0xFFFFBBD6)),
    'baby': CategoryStyle('🍼', Color(0xFFEFF0FF), Color(0xFFC3C7FF)),
    'pets': CategoryStyle('🐾', Color(0xFFF3EEE6), Color(0xFFDCC9AE)),
  };

  static CategoryStyle of(String key) => _styles[key] ?? _fallback;
}

/// Style for a product's category. Admin-created categories have their own
/// ids, so the artwork key is looked up from the category record; the id
/// itself is the fallback while categories are still loading.
final categoryStyleProvider = Provider.family<CategoryStyle, String>((
  ref,
  categoryId,
) {
  final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
  for (final c in categories) {
    if (c.id == categoryId) return CategoryStyle.of(c.icon);
  }
  return CategoryStyle.of(categoryId);
});

/// Emoji artwork. The explicit fallback keeps rendering deterministic on
/// desktop and in tests; Android uses its system emoji font regardless.
class EmojiText extends StatelessWidget {
  const EmojiText(this.emoji, {super.key, required this.size});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      emoji,
      style: TextStyle(
        fontSize: size,
        height: 1.1,
        fontFamilyFallback: const ['Noto Color Emoji'],
      ),
    );
  }
}

/// Tinted artwork for a product: its emoji, or its category's, on a soft
/// gradient. Stands in for a photo that is missing, loading or broken.
class ProductArt extends ConsumerWidget {
  const ProductArt({super.key, required this.product, this.artSize = 56});

  final Product product;
  final double artSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(categoryStyleProvider(product.categoryId));
    final artColors = context.palette.artColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: artColors != null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: artColors,
              )
            : style.gradient,
      ),
      child: Center(
        child: EmojiText(
          product.emoji.isEmpty ? style.emoji : product.emoji,
          size: artSize,
        ),
      ),
    );
  }
}

/// Product photo, with [ProductArt] while loading, on error, or when the
/// admin has not added a photo yet.
class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.product, this.artSize = 56});

  final Product product;
  final double artSize;

  @override
  Widget build(BuildContext context) {
    final placeholder = ProductArt(product: product, artSize: artSize);
    if (product.imageUrl.isEmpty) return placeholder;
    return Image.network(
      product.imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : placeholder,
    );
  }
}

class PriceRow extends StatelessWidget {
  const PriceRow({super.key, required this.product, this.fontSize = 16});

  final Product product;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    // Shrinks to fit instead of running off the card when the price and
    // MRP are long or the phone's font is large.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: _row(),
    );
  }

  Widget _row() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          formatPaise(product.pricePaise),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        if (product.discountPercent > 0) ...[
          const SizedBox(width: 6),
          Text(
            formatPaise(product.mrpPaise),
            style: TextStyle(
              fontSize: fontSize - 4,
              color: AppColors.textMuted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      ],
    );
  }
}

/// "ADD" button that turns into a - n + stepper once the item is in the cart.
class QtyStepper extends ConsumerWidget {
  const QtyStepper({
    super.key,
    required this.product,
    this.height = 36,
    this.keyPrefix = 'add',
  });

  final Product product;
  final double height;

  /// Distinguishes the same product shown in two lists on one screen.
  final String keyPrefix;

  static const _shadow = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 3)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = ref.watch(
      cartProvider.select((cart) => cart.quantityOf(product.id)),
    );
    final cart = ref.read(cartProvider.notifier);
    final palette = context.palette;
    final radius = BorderRadius.circular(height / 3.2);

    // Tells the shopper when stock or the per-order limit stops them.
    void add() {
      final message = cart.add(product);
      if (message == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    if (!product.inStock) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: radius,
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Sold out',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      );
    }

    if (qty == 0 && !ref.watch(canOrderProvider)) {
      // Outside the delivery area: browsing only.
      return Material(
        color: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('$keyPrefix-${product.id}'),
          onTap: () => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text("Sorry, we don't deliver to your pincode yet."),
              ),
            ),
          child: SizedBox(
            height: height,
            child: const Center(
              child: Text(
                'ADD',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (qty == 0) {
      return DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: _shadow),
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: palette.primary, width: 1.4),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('$keyPrefix-${product.id}'),
            onTap: add,
            child: SizedBox(
              height: height,
              child: Center(
                child: Text(
                  'ADD',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: palette.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget button(IconData icon, String tooltip, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: Tooltip(
            message: tooltip,
            child: SizedBox.expand(
              child: Icon(icon, size: 18, color: Colors.white),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: _shadow),
      child: Material(
        color: palette.primary,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              button(Icons.remove_rounded, 'Remove one',
                  () => cart.remove(product)),
              Text(
                '$qty',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              button(Icons.add_rounded, 'Add one', add),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft elevated surface used for product cards and promo tiles.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.radius = 20,
    this.gradient,
  });

  final Widget child;
  final double radius;

  /// Optional background wash; plain white when null.
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? AppColors.surface : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: context.palette.elevation,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.product, this.keyPrefix = 'add'});

  /// Card height at the normal font size.
  static const double height = 250;

  /// Card height on this phone: taller when the phone's font size setting
  /// is larger, so the name and price always fit.
  static double heightOf(BuildContext context) {
    // About 86 pixels of the card are lines of text.
    final scale = MediaQuery.textScalerOf(context).scale(100) / 100;
    return height + (scale > 1 ? 86 * (scale - 1) : 0);
  }

  final Product product;
  final String keyPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardColors = context.palette.cardColors;
    return SoftCard(
      // A themed screen colours every card alike; otherwise each card takes
      // its category's tint.
      gradient: cardColors != null
          ? LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: cardColors,
            )
          : ref.watch(categoryStyleProvider(product.categoryId)).cardGradient,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => context.push(Routes.product(product.id)),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 124,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Opacity(
                            opacity: product.inStock ? 1 : 0.45,
                            child: ProductImage(product: product),
                          ),
                        ),
                      ),
                      if (product.discountPercent > 0)
                        Positioned(
                          left: 0,
                          top: 0,
                          child: DiscountBadge(percent: product.discountPercent),
                        ),
                      Positioned(
                        right: 6,
                        bottom: -10,
                        width: 78,
                        child: QtyStepper(
                          product: product,
                          height: 34,
                          keyPrefix: keyPrefix,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _DeliveryTag(),
                      const SizedBox(height: 4),
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
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
                      const SizedBox(height: 6),
                      PriceRow(product: product),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeliveryTag extends ConsumerWidget {
  const _DeliveryTag();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(storeSettingsProvider);
    final outstation = ref.watch(shopModeProvider) == ShopMode.outstation;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          outstation ? Icons.local_shipping_rounded : Icons.bolt_rounded,
          size: 13,
          color: outstation ? AppColors.outstation : AppColors.accent,
        ),
        const SizedBox(width: 3),
        Text(
          outstation
              ? settings.courierEta.toUpperCase()
              : '${settings.deliveryEtaMinutes} MIN',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: AppColors.accentDark,
          ),
        ),
      ],
    );
  }
}

class DiscountBadge extends StatelessWidget {
  const DiscountBadge({super.key, required this.percent, this.large = false});

  final int percent;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 10 : 7,
        vertical: large ? 5 : 4,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF9D3C), Color(0xFFF2600C)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(14),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Text(
        '$percent% OFF',
        style: TextStyle(
          fontSize: large ? 12 : 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Two-column product grid used on home, search and category screens.
class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key, required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          mainAxisExtent: ProductCard.heightOf(context),
        ),
        itemCount: products.length,
        itemBuilder: (context, i) => ProductCard(product: products[i]),
      ),
    );
  }
}

/// Horizontally scrolling row of product cards (deals, related items).
class ProductRail extends StatelessWidget {
  const ProductRail({
    super.key,
    required this.products,
    required this.keyPrefix,
  });

  final List<Product> products;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Extra room so card shadows are not clipped by the list viewport.
      height: ProductCard.heightOf(context) + 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) => SizedBox(
          width: 156,
          child: ProductCard(product: products[i], keyPrefix: keyPrefix),
        ),
      ),
    );
  }
}

/// Sticky summary bar shown above the bottom edge while the cart has items.
class CartBar extends ConsumerWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    if (cart.isEmpty) return const SizedBox.shrink();
    final count = cart.totalQuantity;
    final palette = context.palette;
    final radius = BorderRadius.circular(18);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              colors: [palette.primary, palette.primaryDark],
            ),
            boxShadow: [
              BoxShadow(
                color: palette.primary.withAlpha(64),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: const ValueKey('cart-bar'),
              borderRadius: radius,
              onTap: () => context.push(Routes.cart),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFFFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$count ${count == 1 ? 'item' : 'items'}',
                            style: const TextStyle(
                              color: Color(0xD9FFFFFF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            formatPaise(cart.subtotalPaise),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'View cart',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
