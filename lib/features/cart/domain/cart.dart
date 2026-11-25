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

/// The one product a shopper picked from a price slab offer: a single
/// unit at [pricePaise] instead of the product's selling price. It is
/// kept apart from the ordinary items, so the same product can also be
/// bought at its usual price, and it does not count towards the amount
/// that earns the offer.
@immutable
class CartOffer {
  const CartOffer({
    required this.offerId,
    required this.minOrderPaise,
    required this.pricePaise,
    required this.product,
  });

  final String offerId;

  /// The items in the cart must come to at least this much.
  final int minOrderPaise;
  final int pricePaise;
  final Product product;

  /// Shown struck through next to the offer price.
  int get sellingPricePaise => product.pricePaise;
  int get mrpPaise =>
      product.mrpPaise > product.pricePaise ? product.mrpPaise : product.pricePaise;

  Map<String, dynamic> toMap() => {
        'offerId': offerId,
        'minOrderPaise': minOrderPaise,
        'pricePaise': pricePaise,
        'id': product.id,
        'product': product.toMap(),
      };

  factory CartOffer.fromMap(Map<String, dynamic> map) => CartOffer(
        offerId: map['offerId'] as String? ?? '',
        minOrderPaise: (map['minOrderPaise'] as num?)?.toInt() ?? 0,
        pricePaise: (map['pricePaise'] as num?)?.toInt() ?? 0,
        product: Product.fromMap(
          map['id'] as String,
          Map<String, dynamic>.from(map['product'] as Map),
        ),
      );
}

/// Immutable cart snapshot. All totals are derived, never stored.
@immutable
class Cart {
  const Cart([
    this.items = const {},
    this.fees = StoreSettings.defaults,
    this.courier = false,
    this.offer,
  ]);

  /// The product picked from a price slab offer, if any.
  final CartOffer? offer;

  /// Keyed by product id; insertion order is display order.
  final Map<String, CartItem> items;

  /// Delivery pricing in force; set by the admin and injected by the
  /// cart controller so totals always reflect current settings.
  final StoreSettings fees;

  /// True for the Outstation cart: sent by courier, with the courier
  /// charge in place of the instant delivery charges.
  final bool courier;

  int get _freeAbovePaise => courier
      ? fees.courierFreeAbovePaise
      : fees.freeDeliveryThresholdPaise;

  bool get isEmpty => items.isEmpty;
  List<CartItem> get lines => items.values.toList(growable: false);
  int quantityOf(String productId) => items[productId]?.quantity ?? 0;

  int get totalQuantity =>
      items.values.fold(0, (sum, item) => sum + item.quantity) +
      (offer == null ? 0 : 1);

  /// The ordinary items only: what counts towards a price slab offer.
  int get itemsSubtotalPaise =>
      items.values.fold(0, (sum, item) => sum + item.lineTotalPaise);
  int get subtotalPaise => itemsSubtotalPaise + (offer?.pricePaise ?? 0);
  int get mrpTotalPaise =>
      items.values.fold(0, (sum, item) => sum + item.lineMrpPaise) +
      (offer?.mrpPaise ?? 0);
  int get savingsPaise => mrpTotalPaise - subtotalPaise;

  int get deliveryFeePaise =>
      isEmpty || subtotalPaise >= _freeAbovePaise
          ? 0
          : courier
              ? fees.courierFeePaise
              : fees.deliveryFeePaise;

  /// Admin-controlled extras; 0 while switched off or the cart is empty.
  int get handlingFeePaise =>
      isEmpty || courier || !fees.handlingFeeEnabled
          ? 0
          : fees.handlingFeePaise;
  int get rainFeePaise =>
      isEmpty || courier || !fees.rainFeeEnabled ? 0 : fees.rainFeePaise;

  int get totalPaise =>
      subtotalPaise + deliveryFeePaise + handlingFeePaise + rainFeePaise;

  /// How much more to add for free delivery; 0 once unlocked.
  int get toFreeDeliveryPaise {
    if (isEmpty) return 0;
    final gap = _freeAbovePaise - subtotalPaise;
    return gap > 0 ? gap : 0;
  }

  Map<String, dynamic> toMap() => {
        'items': items.values.map((i) => i.toMap()).toList(),
        if (offer != null) 'offer': offer!.toMap(),
      };

  factory Cart.fromMap(
    Map<String, dynamic> map, [
    StoreSettings fees = StoreSettings.defaults,
    bool courier = false,
  ]) {
    final list = (map['items'] as List?) ?? const [];
    final items = <String, CartItem>{};
    for (final raw in list) {
      final item = CartItem.fromMap(Map<String, dynamic>.from(raw as Map));
      items[item.product.id] = item;
    }
    CartOffer? offer;
    try {
      final raw = map['offer'];
      if (raw != null) {
        offer = CartOffer.fromMap(Map<String, dynamic>.from(raw as Map));
      }
    } catch (_) {
      // Unreadable offer: the cart carries on without it.
    }
    return Cart(items, fees, courier, offer);
  }
}
