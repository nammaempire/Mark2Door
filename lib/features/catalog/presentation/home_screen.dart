import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/shimmer.dart';
import '../../insights/demand_log.dart';
import '../../orders/application/order_providers.dart';
import '../../orders/presentation/live_order_card.dart';
import '../../service_area/application/pincode_controller.dart';
import '../../service_area/presentation/delivery_banner.dart';
import '../../store/application/store_providers.dart';
import '../application/catalog_providers.dart';
import '../domain/product.dart';
import 'product_widgets.dart';
import 'promo_carousel.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  Timer? _missTimer;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _missTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
    // Once the shopper has stopped typing, note a search that found
    // nothing to buy, for the store to see in the admin web.
    _missTimer?.cancel();
    _missTimer = Timer(_missDelay, () => _recordMiss(value.trim()));
  }

  /// Long enough that half-typed words are not counted as searches.
  static const _missDelay = Duration(milliseconds: 1500);

  Future<void> _recordMiss(String term) async {
    if (!mounted || term.length < DemandLog.minSearchLength) return;
    try {
      final ProductQuery query = (categoryId: null, query: term);
      final found = await ref.read(productsProvider(query).future);
      if (!mounted) return;
      if (found.isEmpty) {
        ref.read(demandLogProvider).searchMiss(term, SearchMiss.notFound);
      } else if (found.every((p) => !p.inStock)) {
        ref.read(demandLogProvider).searchMiss(term, SearchMiss.outOfStock);
      }
    } catch (_) {
      // The search itself failed to load: nothing to learn from it.
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _missTimer?.cancel();
    _searchController.clear();
    setState(() => _query = '');
  }

  /// Best in-stock discounts first; drives the "Deals of the day" rail.
  static List<Product> _deals(List<Product> all) {
    final deals = all
        .where((p) => p.inStock && p.discountPercent >= 15)
        .toList()
      ..sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
    return deals.take(6).toList(growable: false);
  }

  /// Cheapest in-stock items at or under ₹99, for the "Budget buys" rail.
  static List<Product> _budget(List<Product> all) {
    final cheap = all
        .where((p) => p.inStock && p.pricePaise <= 9900)
        .toList()
      ..sort((a, b) => a.pricePaise.compareTo(b.pricePaise));
    return cheap.take(8).toList(growable: false);
  }

  /// One rail per category that has at least two products, in the
  /// categories' own order. Small catalogues simply get fewer rails.
  static List<({Category category, List<Product> products})> _byCategory(
    List<Category> categories,
    List<Product> all,
  ) {
    return [
      for (final c in categories)
        (
          category: c,
          products: all
              .where((p) => p.categoryId == c.id && p.inStock)
              .take(8)
              .toList(growable: false),
        ),
    ].where((r) => r.products.length >= 2).take(4).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final ProductQuery query = (categoryId: null, query: _query);
    final products = ref.watch(productsProvider(query));
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final searching = _query.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          body: Column(
            children: [
              _Header(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onClear: _clearSearch,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(categoriesProvider);
                    return ref.refresh(productsProvider(query).future);
                  },
                  child: CustomScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      if (searching)
                        SliverToBoxAdapter(
                          child: _SectionTitle('Results for "$_query"'),
                        )
                      else ...const [
                        SliverToBoxAdapter(
                          child: NotServiceableBanner(
                            margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
                          ),
                        ),
                        SliverToBoxAdapter(child: _LiveOrderSection()),
                        SliverToBoxAdapter(child: SizedBox(height: 16)),
                        SliverToBoxAdapter(child: _PromoSection()),
                        SliverToBoxAdapter(
                          child: _SectionTitle('Shop by category'),
                        ),
                        SliverToBoxAdapter(child: _CategoryStrip()),
                        SliverToBoxAdapter(child: _FreeDeliveryStrip()),
                        SliverToBoxAdapter(child: _PerksStrip()),
                      ],
                      ...products.when(
                        data: (items) => [
                          if (items.isEmpty)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: EmptyState(
                                icon: Icons.search_off_rounded,
                                title: 'No products found',
                                message: 'Try a different name or category.',
                              ),
                            )
                          else ...[
                            if (!searching && _deals(items).isNotEmpty) ...[
                              const SliverToBoxAdapter(
                                child: _SectionTitle(
                                  'Deals of the day',
                                  icon: Icons.local_fire_department_rounded,
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: ProductRail(
                                  products: _deals(items),
                                  keyPrefix: 'deal',
                                ),
                              ),
                            ],
                            if (!searching) ...[
                              for (final rail in _byCategory(categories, items))
                                ...[
                                  SliverToBoxAdapter(
                                    child: _SectionTitle(
                                      rail.category.name,
                                      topPadding: 0,
                                      actionLabel: 'See all',
                                      onAction: () => context.push(
                                        Routes.category(rail.category.id),
                                      ),
                                    ),
                                  ),
                                  SliverToBoxAdapter(
                                    child: ProductRail(
                                      products: rail.products,
                                      keyPrefix: 'cat-${rail.category.id}',
                                    ),
                                  ),
                                ],
                              if (_budget(items).length >= 2) ...[
                                const SliverToBoxAdapter(
                                  child: _SectionTitle(
                                    'Budget buys under ₹99',
                                    icon: Icons.savings_rounded,
                                    topPadding: 0,
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: ProductRail(
                                    products: _budget(items),
                                    keyPrefix: 'budget',
                                  ),
                                ),
                              ],
                              const SliverToBoxAdapter(
                                child: _SectionTitle(
                                  'All products',
                                  topPadding: 0,
                                ),
                              ),
                            ],
                            ProductGrid(products: items),
                          ],
                        ],
                        loading: () => [
                          if (!searching) ...const [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(16, 26, 16, 16),
                                child: Shimmer(
                                  child: SkeletonBox.line(
                                    width: 150,
                                    height: 18,
                                  ),
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(child: ProductRailSkeleton()),
                          ],
                          const ProductGridSkeleton(),
                        ],
                        error: (_, __) => [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: EmptyState(
                              icon: Icons.cloud_off_rounded,
                              title: 'Something went wrong',
                              message: 'Check your connection and try again.',
                              actionLabel: 'Retry',
                              onAction: () =>
                                  ref.invalidate(productsProvider(query)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const CartBar(),
            ],
          ),
        ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pincode = ref.watch(pincodeProvider) ?? '';
    final eta = ref.watch(storeSettingsProvider).deliveryEtaMinutes;
    final palette = context.palette;
    final topInset = MediaQuery.paddingOf(context).top;
    const searchBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide.none,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.primaryLight, palette.primaryDark],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => context.push(Routes.pincode),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0x2EFFFFFF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Delivering to',
                              style: TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontSize: 12,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Pincode $pincode',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$eta min',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => TextField(
              key: const ValueKey('search-field'),
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search milk, atta, fruits',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: palette.primary,
                ),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: onClear,
                      ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: searchBorder,
                enabledBorder: searchBorder,
                focusedBorder: searchBorder,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner carousel fed by the admin-managed banners. Collapses when there
/// are none or they cannot be loaded, so the page never shows a gap.
class _PromoSection extends ConsumerWidget {
  const _PromoSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(promosProvider).when(
          data: (promos) => promos.isEmpty
              ? const SizedBox.shrink()
              : PromoCarousel(promos: promos),
          // Same height as the carousel so content below does not jump.
          loading: () => const BannerSkeleton(),
          error: (_, __) => const SizedBox.shrink(),
        );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(
    this.text, {
    this.icon,
    this.topPadding = 22,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final IconData? icon;
  final double topPadding;

  /// Optional link on the right, e.g. "See all".
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22, color: AppColors.accent),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: AppColors.textDark,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: context.palette.primary,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: context.palette.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Three short promises under the free-delivery strip.
class _PerksStrip extends ConsumerWidget {
  const _PerksStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eta = ref.watch(storeSettingsProvider).deliveryEtaMinutes;
    Widget perk(IconData icon, String title, String subtitle) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: context.palette.elevation,
            ),
            child: Column(
              children: [
                Icon(icon, size: 22, color: context.palette.primary),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          perk(Icons.bolt_rounded, '$eta min', 'delivery'),
          const SizedBox(width: 10),
          perk(Icons.verified_rounded, 'Fresh', 'quality checked'),
          const SizedBox(width: 10),
          perk(Icons.sell_rounded, 'Best prices', 'every day'),
        ],
      ),
    );
  }
}

class _CategoryStrip extends ConsumerWidget {
  const _CategoryStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return SizedBox(
      height: 124,
      child: categories.when(
        loading: () => const CategoryStripSkeleton(),
        error: (_, __) => const SizedBox.shrink(),
        data: (items) => ListView.separated(
          scrollDirection: Axis.horizontal,
          // Bottom room so tile shadows are not clipped by the list.
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) => _CategoryTile(category: items[i]),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(category.icon);
    final palette = context.palette;
    final artColors = palette.artColors;
    return InkWell(
      onTap: () => context.push(Routes.category(category.id)),
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 78,
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: artColors != null
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: artColors,
                      )
                    : style.gradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: palette.elevation,
              ),
              // The store's picture for the category. A category saved
              // before pictures existed, or whose picture fails to load,
              // keeps its drawn icon.
              child: category.imageUrl.isEmpty
                  ? EmojiText(style.emoji, size: 34)
                  : Image.network(
                      category.imageUrl,
                      key: ValueKey('category-image-${category.id}'),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          EmojiText(style.emoji, size: 34),
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : EmojiText(style.emoji, size: 34),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeDeliveryStrip extends ConsumerWidget {
  const _FreeDeliveryStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threshold =
        ref.watch(storeSettingsProvider).freeDeliveryThresholdPaise;
    final strip = context.palette.stripColors ??
        const [Color(0xFFFFA94D), Color(0xFFF2600C)];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: strip),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: strip.last.withAlpha(70),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x38FFFFFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const EmojiText('🛵', size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Free delivery',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'On orders above ${formatPaise(threshold)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xF2FFFFFF),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

/// The shopper's order that is on its way, as a live animated card at the
/// top of the home page. It disappears once the order is delivered (or
/// cancelled), so the page goes back to normal on its own.
class _LiveOrderSection extends ConsumerWidget {
  const _LiveOrderSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider).valueOrNull ?? const [];
    final active = orders.where((o) => o.isActive).toList(growable: false);
    final more = active.length - 1;
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: active.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: LiveOrderCard(
                key: const ValueKey('home-live-order'),
                order: active.first,
                onTap: () => context.push(Routes.order(active.first.id)),
                footer: more <= 0
                    ? null
                    : 'and $more more ${more == 1 ? 'order' : 'orders'} on '
                        'the way. See them under Orders.',
              ),
            ),
    );
  }
}
