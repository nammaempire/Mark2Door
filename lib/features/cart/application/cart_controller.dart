import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/storage/local_store.dart';
import '../../catalog/domain/product.dart';
import '../../store/application/store_providers.dart';
import '../domain/cart.dart';

final cartProvider = NotifierProvider<CartController, Cart>(CartController.new);

/// Owns the cart and persists every change so it survives app restarts.
class CartController extends Notifier<Cart> {
  LocalStore get _store => ref.read(localStoreProvider);

  @override
  Cart build() {
    // Rebuilds from storage whenever the admin changes delivery pricing,
    // so totals on screen update without the shopper doing anything.
    final fees = ref.watch(storeSettingsProvider);
    final saved = _store.readJson(LocalStore.cartKey);
    if (saved == null) return Cart(const {}, fees);
    try {
      return Cart.fromMap(saved, fees);
    } catch (_) {
      return Cart(const {}, fees); // schema changed: start clean
    }
  }

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
    _commit(Cart(Map.unmodifiable(next), state.fees));
  }

  void clear() => _commit(Cart(const {}, state.fees));

  void _commit(Cart cart) {
    state = cart;
    _store.writeJson(LocalStore.cartKey, cart.isEmpty ? null : cart.toMap());
  }
}
