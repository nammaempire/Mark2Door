import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/storage/local_store.dart';
import '../../catalog/domain/product.dart';
import '../../service_area/application/pincode_controller.dart';
import '../../store/application/store_providers.dart';
import '../../offers/slab_offers.dart';
import '../domain/cart.dart';

final cartProvider = NotifierProvider<CartController, Cart>(CartController.new);

/// Owns the cart and persists every change so it survives app restarts.
/// Instant and Outstation shopping each have their own cart, because one
/// order cannot go by delivery partner and by courier at once; this is
/// always the cart of the way the shopper is shopping now.
class CartController extends Notifier<Cart> {
  LocalStore get _store => ref.read(localStoreProvider);

  @override
  Cart build() {
    // Rebuilds from storage whenever the admin changes delivery pricing,
    // so totals on screen update without the shopper doing anything.
    final fees = ref.watch(storeSettingsProvider);
    final courier = ref.watch(shopModeProvider) == ShopMode.outstation;
    final saved = _store.readJson(_keyFor(courier));
    if (saved == null) return Cart(const {}, fees, courier);
    try {
      return Cart.fromMap(saved, fees, courier);
    } catch (_) {
      return Cart(const {}, fees, courier); // schema changed: start clean
    }
  }

  static String _keyFor(bool courier) =>
      courier ? LocalStore.outstationCartKey : LocalStore.cartKey;

  /// Adds one. Returns a message for the shopper when no more can be
  /// added (stock has run out, or the per-order limit is reached), and
  /// null when the item was added.
  String? add(Product product) {
    final have = state.quantityOf(product.id);
    final limit = product.maxPerOrder(AppConfig.maxQtyPerItem);
    if (have >= limit) return limitMessage(product);
    setQuantity(product, have + 1);
    return null;
  }

  /// Why no more of [product] can be added.
  static String limitMessage(Product product) {
    final left = product.stockQty;
    if (!product.inStock) return '${product.name} is out of stock.';
    if (left != null && left <= AppConfig.maxQtyPerItem) {
      return 'Only $left left in stock. You cannot add more.';
    }
    return 'You can add up to ${AppConfig.maxQtyPerItem} of one item '
        'per order.';
  }

  void remove(Product product) => setQuantity(
        product,
        state.quantityOf(product.id) - 1,
      );

  void setQuantity(Product product, int quantity) {
    if (!product.inStock) return;
    final clamped =
        quantity.clamp(0, product.maxPerOrder(AppConfig.maxQtyPerItem));
    final next = Map<String, CartItem>.of(state.items);
    if (clamped == 0) {
      next.remove(product.id);
    } else {
      next[product.id] = CartItem(product: product, quantity: clamped);
    }
    _commit(
      Cart(Map.unmodifiable(next), state.fees, state.courier, state.offer),
    );
  }

  /// Adds [product] as the shopper's pick from [offer], replacing any
  /// earlier pick. Returns a message when it cannot be picked.
  String? pickOffer(SlabOffer offer, Product product) {
    if (!offer.unlockedBy(state.itemsSubtotalPaise)) {
      return 'Add more items to use this offer.';
    }
    if (!product.inStock ||
        product.maxPerOrder(AppConfig.maxQtyPerItem) <=
            state.quantityOf(product.id)) {
      return '${product.name} is out of stock.';
    }
    _commit(
      Cart(
        state.items,
        state.fees,
        state.courier,
        CartOffer(
          offerId: offer.id,
          minOrderPaise: offer.minOrderPaise,
          pricePaise: offer.offerPricePaise,
          product: product,
        ),
      ),
    );
    return null;
  }

  void removeOffer() =>
      _commit(Cart(state.items, state.fees, state.courier));

  void clear() => _commit(Cart(const {}, state.fees, state.courier));

  void _commit(Cart next) {
    // The offer product goes when the items no longer earn it.
    final offer = next.offer;
    final cart = offer != null &&
            next.itemsSubtotalPaise < offer.minOrderPaise
        ? Cart(next.items, next.fees, next.courier)
        : next;
    state = cart;
    _store.writeJson(
      _keyFor(cart.courier),
      cart.isEmpty ? null : cart.toMap(),
    );
  }
}
