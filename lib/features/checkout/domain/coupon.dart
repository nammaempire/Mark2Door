import 'package:flutter/foundation.dart';

import '../../../core/utils/formatters.dart';

enum CouponType { percent, flat }

/// A discount code created in the admin web (`coupons/{CODE}`).
@immutable
class Coupon {
  const Coupon({
    required this.code,
    required this.type,
    required this.value,
    this.minOrderPaise = 0,
    this.maxDiscountPaise = 0,
    this.expiresAt,
    this.active = true,
    this.oncePerCustomer = false,
  });

  /// Upper case, and also the document id.
  final String code;
  final CouponType type;

  /// Percent off (1 to 100) or paise off, depending on [type].
  final int value;

  /// Smallest item total the coupon works on; 0 for no minimum.
  final int minOrderPaise;

  /// Upper limit for a percent coupon's discount; 0 for no limit.
  final int maxDiscountPaise;

  /// The coupon works up to the end of this day; null means no expiry.
  final DateTime? expiresAt;
  final bool active;

  /// When true, each customer can use the code on one order only.
  final bool oncePerCustomer;

  /// "10% off" or "₹50 off", for the applied-coupon line.
  String get label =>
      type == CouponType.percent ? '$value% off' : '${formatPaise(value)} off';

  /// Why the coupon cannot be used on an item total of [subtotalPaise] at
  /// [now], or null when it can.
  String? problemFor(int subtotalPaise, DateTime now) {
    if (!active) return 'This coupon is no longer active.';
    final end = expiresAt;
    if (end != null && now.isAfter(end)) return 'This coupon has expired.';
    if (subtotalPaise < minOrderPaise) {
      return 'Add items worth ${formatPaise(minOrderPaise - subtotalPaise)} '
          'more to use this coupon.';
    }
    return null;
  }

  /// Paise taken off an item total of [subtotalPaise]. Never more than the
  /// items cost, so fees are not discounted.
  int discountFor(int subtotalPaise) {
    if (subtotalPaise <= 0) return 0;
    var off =
        type == CouponType.flat ? value : (subtotalPaise * value / 100).floor();
    if (type == CouponType.percent &&
        maxDiscountPaise > 0 &&
        off > maxDiscountPaise) {
      off = maxDiscountPaise;
    }
    if (off < 0) return 0;
    return off > subtotalPaise ? subtotalPaise : off;
  }

  /// Codes are matched without regard to case or surrounding spaces.
  static String normalise(String input) => input.trim().toUpperCase();

  factory Coupon.fromMap(String id, Map<String, dynamic> map) => Coupon(
        code: id,
        type: map['type'] == 'flat' ? CouponType.flat : CouponType.percent,
        value: (map['value'] as num?)?.toInt() ?? 0,
        minOrderPaise: (map['minOrderPaise'] as num?)?.toInt() ?? 0,
        maxDiscountPaise: (map['maxDiscountPaise'] as num?)?.toInt() ?? 0,
        expiresAt: map['expiresAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                (map['expiresAt'] as num).toInt(),
              ),
        active: map['active'] as bool? ?? true,
        oncePerCustomer: map['oncePerCustomer'] as bool? ?? false,
      );
}
