import 'package:flutter/foundation.dart';

import '../../../core/utils/formatters.dart';
import '../../cart/domain/cart.dart';
import '../../checkout/domain/address.dart';

enum PaymentMethod {
  online('Pay online'),
  cod('Cash on delivery');

  const PaymentMethod(this.label);
  final String label;
}

enum PaymentStatus { pending, paid, failed, refunded }

/// Lifecycle shared with the delivery app and admin web.
enum OrderStatus {
  placed('Order placed'),
  accepted('Accepted'),
  pickedUp('Out for delivery'),
  delivered('Delivered'),
  cancelled('Cancelled');

  const OrderStatus(this.label);
  final String label;
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

enum EtaKind { onTime, late, onHold, delivered }

/// Customer-facing arrival message derived from an [Order].
@immutable
class OrderEta {
  const OrderEta(this.headline, {this.detail, required this.kind});

  final String headline;
  final String? detail;
  final EtaKind kind;
}

@immutable
class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.unit,
    required this.pricePaise,
    required this.quantity,
    this.mrpPaise = 0,
  });

  final String productId;
  final String name;
  final String unit;

  /// Price snapshot at purchase time; later catalogue edits must not alter it.
  final int pricePaise;
  final int quantity;

  /// MRP at purchase time; 0 on orders placed before it was recorded.
  final int mrpPaise;

  int get lineTotalPaise => pricePaise * quantity;

  /// Never below the price paid, so savings cannot go negative.
  int get lineMrpPaise =>
      (mrpPaise > pricePaise ? mrpPaise : pricePaise) * quantity;

  factory OrderItem.fromCart(CartItem item) => OrderItem(
        productId: item.product.id,
        name: item.product.name,
        unit: item.product.unit,
        pricePaise: item.product.pricePaise,
        quantity: item.quantity,
        mrpPaise: item.product.mrpPaise,
      );

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'unit': unit,
        'pricePaise': pricePaise,
        'quantity': quantity,
        'mrpPaise': mrpPaise,
      };

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        productId: map['productId'] as String? ?? '',
        name: map['name'] as String? ?? '',
        unit: map['unit'] as String? ?? '',
        pricePaise: (map['pricePaise'] as num?)?.toInt() ?? 0,
        quantity: (map['quantity'] as num?)?.toInt() ?? 0,
        mrpPaise: (map['mrpPaise'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class Order {
  const Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.subtotalPaise,
    required this.deliveryFeePaise,
    required this.totalPaise,
    required this.address,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    required this.createdAt,
    this.handlingFeePaise = 0,
    this.rainFeePaise = 0,
    this.walletAppliedPaise = 0,
    this.couponCode,
    this.couponDiscountPaise = 0,
    this.etaAt,
    this.paymentId,
    this.riderName,
    this.riderPhone,
    this.riderRating,
    this.cancelledBy,
  });

  final String id;
  final String userId;
  final List<OrderItem> items;
  final int subtotalPaise;
  final int deliveryFeePaise;

  /// Extra charges that were switched on when the order was placed.
  final int handlingFeePaise;
  final int rainFeePaise;

  /// Value of the order: items plus every fee, less any coupon discount.
  final int totalPaise;

  /// Coupon used on this order, and what it took off; null and 0 when no
  /// coupon was used.
  final String? couponCode;
  final int couponDiscountPaise;

  /// Part of [totalPaise] paid from the shopper's m2d wallet.
  final int walletAppliedPaise;
  final Address address;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final OrderStatus status;
  final DateTime createdAt;

  /// Estimated delivery time. Set when the order is placed and refined by
  /// the delivery app; null on orders created before ETAs existed.
  final DateTime? etaAt;
  final String? paymentId;

  /// Delivery partner assigned from the admin web; null until assigned.
  final String? riderName;
  final String? riderPhone;

  /// Stars (1 to 5) the shopper gave this delivery; null until rated.
  final int? riderRating;

  /// "customer" when the shopper cancelled it themselves; null otherwise.
  final String? cancelledBy;

  /// The shopper can cancel until the delivery partner has picked the
  /// order up from the store.
  bool get canCancel =>
      status == OrderStatus.placed || status == OrderStatus.accepted;

  /// Still on its way: shown as a live card on the home page.
  bool get isActive =>
      status != OrderStatus.delivered &&
      status != OrderStatus.cancelled &&
      paymentStatus != PaymentStatus.failed;

  /// A delivered order whose delivery partner has not been rated yet.
  bool get canRateDelivery =>
      status == OrderStatus.delivered &&
      riderName != null &&
      riderRating == null;

  /// Short code shown to the customer and the delivery partner.
  String get displayId =>
      '#${(id.length <= 6 ? id : id.substring(id.length - 6)).toUpperCase()}';

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  /// What is left to pay online or in cash after the wallet.
  int get payablePaise => totalPaise - walletAppliedPaise;

  /// MRP value of the items, for the struck-through total and savings.
  int get mrpTotalPaise => items.fold(0, (sum, i) => sum + i.lineMrpPaise);

  /// The money for this order has been returned to the customer.
  bool get isRefunded => paymentStatus == PaymentStatus.refunded;

  /// Paid online, then cancelled, and the refund is not recorded yet.
  bool get refundInProgress =>
      status == OrderStatus.cancelled &&
      paymentMethod == PaymentMethod.online &&
      paymentStatus == PaymentStatus.paid;

  bool get awaitingPayment =>
      paymentMethod == PaymentMethod.online &&
      paymentStatus == PaymentStatus.pending;

  /// What to tell the customer about arrival at time [now]; null when an
  /// ETA does not apply (cancelled, or no estimate recorded).
  OrderEta? eta(DateTime now) {
    if (status == OrderStatus.cancelled) return null;
    if (status == OrderStatus.delivered) {
      return const OrderEta('Delivered', kind: EtaKind.delivered);
    }
    if (awaitingPayment) {
      return const OrderEta(
        'Waiting for payment',
        detail: 'Delivery time is confirmed once payment goes through.',
        kind: EtaKind.onHold,
      );
    }
    final at = etaAt;
    if (at == null) return null;
    final remaining = at.difference(now);
    if (remaining <= Duration.zero) {
      return const OrderEta(
        'Arriving soon',
        detail: 'Running a little late. Sorry for the wait.',
        kind: EtaKind.late,
      );
    }
    // Round up so "0 min" is never shown while time remains.
    final minutes = (remaining.inSeconds / 60).ceil();
    return OrderEta(
      'Arriving in $minutes min',
      detail: 'Estimated delivery by ${formatTime(at)}',
      kind: EtaKind.onTime,
    );
  }

  Order copyWith({
    String? id,
    PaymentStatus? paymentStatus,
    OrderStatus? status,
    String? paymentId,
    DateTime? etaAt,
    String? riderName,
    int? riderRating,
    String? cancelledBy,
  }) =>
      Order(
        id: id ?? this.id,
        userId: userId,
        items: items,
        subtotalPaise: subtotalPaise,
        deliveryFeePaise: deliveryFeePaise,
        handlingFeePaise: handlingFeePaise,
        rainFeePaise: rainFeePaise,
        totalPaise: totalPaise,
        walletAppliedPaise: walletAppliedPaise,
        couponCode: couponCode,
        couponDiscountPaise: couponDiscountPaise,
        address: address,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        status: status ?? this.status,
        createdAt: createdAt,
        etaAt: etaAt ?? this.etaAt,
        paymentId: paymentId ?? this.paymentId,
        riderName: riderName ?? this.riderName,
        riderPhone: riderPhone,
        riderRating: riderRating ?? this.riderRating,
        cancelledBy: cancelledBy ?? this.cancelledBy,
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'items': items.map((i) => i.toMap()).toList(),
        'subtotalPaise': subtotalPaise,
        'deliveryFeePaise': deliveryFeePaise,
        'handlingFeePaise': handlingFeePaise,
        'rainFeePaise': rainFeePaise,
        'totalPaise': totalPaise,
        'walletAppliedPaise': walletAppliedPaise,
        if (couponCode != null) 'couponCode': couponCode,
        if (couponCode != null) 'couponDiscountPaise': couponDiscountPaise,
        'address': address.toMap(),
        'paymentMethod': paymentMethod.name,
        'paymentStatus': paymentStatus.name,
        'status': status.name,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'etaAt': etaAt?.millisecondsSinceEpoch,
        'paymentId': paymentId,
      };

  factory Order.fromMap(String id, Map<String, dynamic> map) => Order(
        id: id,
        userId: map['userId'] as String? ?? '',
        items: ((map['items'] as List?) ?? const [])
            .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
        subtotalPaise: (map['subtotalPaise'] as num?)?.toInt() ?? 0,
        deliveryFeePaise: (map['deliveryFeePaise'] as num?)?.toInt() ?? 0,
        handlingFeePaise: (map['handlingFeePaise'] as num?)?.toInt() ?? 0,
        rainFeePaise: (map['rainFeePaise'] as num?)?.toInt() ?? 0,
        totalPaise: (map['totalPaise'] as num?)?.toInt() ?? 0,
        walletAppliedPaise: (map['walletAppliedPaise'] as num?)?.toInt() ?? 0,
        couponCode: map['couponCode'] as String?,
        couponDiscountPaise:
            (map['couponDiscountPaise'] as num?)?.toInt() ?? 0,
        address: Address.fromMap(
          Map<String, dynamic>.from((map['address'] as Map?) ?? const {}),
        ),
        paymentMethod: _enumByName(
          PaymentMethod.values,
          map['paymentMethod'],
          PaymentMethod.cod,
        ),
        paymentStatus: _enumByName(
          PaymentStatus.values,
          map['paymentStatus'],
          PaymentStatus.pending,
        ),
        status: _enumByName(
          OrderStatus.values,
          map['status'],
          OrderStatus.placed,
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['createdAt'] as num?)?.toInt() ?? 0,
        ),
        etaAt: map['etaAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch((map['etaAt'] as num).toInt()),
        paymentId: map['paymentId'] as String?,
        riderName: map['riderName'] as String?,
        riderPhone: map['riderPhone'] as String?,
        riderRating: (map['riderRating'] as num?)?.toInt(),
        cancelledBy: map['cancelledBy'] as String?,
      );
}
