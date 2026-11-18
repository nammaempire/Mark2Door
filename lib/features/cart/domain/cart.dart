import 'package:flutter/foundation.dart';

import '../../../core/config/store_settings.dart';
import '../../catalog/domain/product.dart';

@immutable
class CartItem {
  const CartItem({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  int get lineTotalPaise => product.pricePaise * quantity;
  int get lineMrpPaise => product.mrpPaise * quantity;

  CartItem copyWith({int? quantity}) =>
      CartItem(product: product, quantity: quantity ?? this.quantity);

  Map<String, dynamic> toMap() => {
        'id': product.id,
        'product': product.toMap(),
        'quantity': quantity,
      };

  factory CartItem.fromMap(Map<String, dynamic> map) => CartItem(
        product: Product.fromMap(
          map['id'] as String,
          Map<String, dynamic>.from(map['product'] as Map),
        ),
        quantity: (map['quantity'] as num).toInt(),
      );
}

/// Immutable cart snapshot. All totals are derived, never stored.
@immutable
class Cart {
  const Cart([this.items = const {}, this.fees = StoreSettings.defaults]);

  /// Keyed by product id; insertion order is display order.
  final Map<String, CartItem> items;

  /// Delivery pricing in force; set by the admin and injected by the
  /// cart controller so totals always reflect current settings.
  final StoreSettings fees;

  bool get isEmpty => items.isEmpty;
  List<CartItem> get lines => items.values.toList(growable: false);
  int quantityOf(String productId) => items[productId]?.quantity ?? 0;

  int get totalQuantity =>
      items.values.fold(0, (sum, item) => sum + item.quantity);
  int get subtotalPaise =>
      items.values.fold(0, (sum, item) => sum + item.lineTotalPaise);
  int get mrpTotalPaise =>
      items.values.fold(0, (sum, item) => sum + item.lineMrpPaise);
  int get savingsPaise => mrpTotalPaise - subtotalPaise;

  int get deliveryFeePaise =>
      isEmpty || subtotalPaise >= fees.freeDeliveryThresholdPaise
          ? 0
          : fees.deliveryFeePaise;

  int get totalPaise => subtotalPaise + deliveryFeePaise;

  /// How much more to add for free delivery; 0 once unlocked.
  int get toFreeDeliveryPaise {
    if (isEmpty) return 0;
    final gap = fees.freeDeliveryThresholdPaise - subtotalPaise;
    return gap > 0 ? gap : 0;
  }

  Map<String, dynamic> toMap() =>
      {'items': items.values.map((i) => i.toMap()).toList()};

  factory Cart.fromMap(
    Map<String, dynamic> map, [
    StoreSettings fees = StoreSettings.defaults,
  ]) {
    final list = (map['items'] as List?) ?? const [];
    final items = <String, CartItem>{};
    for (final raw in list) {
      final item = CartItem.fromMap(Map<String, dynamic>.from(raw as Map));
      items[item.product.id] = item;
    }
    return Cart(items, fees);
  }
}
