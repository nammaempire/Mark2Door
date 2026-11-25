import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../cart/application/cart_controller.dart';
import '../domain/coupon.dart';

/// One coupon in the list at checkout: whether this shopper can use it on
/// this cart, and what it would take off.
@immutable
class CouponOffer {
  const CouponOffer(this.coupon, {this.problem, this.savingPaise = 0});

  final Coupon coupon;

  /// Why it cannot be used now; null when it can.
  final String? problem;

  /// What it takes off the current cart; 0 when it cannot be used.
  final int savingPaise;

  bool get usable => problem == null;
}

/// The store's coupons for the cart as it is now. Coupons that can be
/// used come first, biggest saving on top; the rest follow, to be shown
/// greyed out with the reason.
final couponOffersProvider =
    FutureProvider.autoDispose<List<CouponOffer>>((ref) async {
  final repo = ref.watch(couponRepositoryProvider);
  final subtotal = ref.watch(cartProvider.select((c) => c.subtotalPaise));
  final uid = ref.watch(currentUserProvider)?.uid ?? '';
  final now = DateTime.now();
  final offers = <CouponOffer>[];
  for (final coupon in await repo.fetchAll()) {
    var problem = coupon.problemFor(subtotal, now);
    if (problem == null &&
        coupon.oncePerCustomer &&
        await repo.alreadyUsed(coupon.code, uid)) {
      problem = 'You have already used this coupon.';
    }
    offers.add(
      CouponOffer(
        coupon,
        problem: problem,
        savingPaise: problem == null ? coupon.discountFor(subtotal) : 0,
      ),
    );
  }
  offers.sort((a, b) {
    if (a.usable != b.usable) return a.usable ? -1 : 1;
    final bySaving = b.savingPaise.compareTo(a.savingPaise);
    return bySaving != 0 ? bySaving : a.coupon.code.compareTo(b.coupon.code);
  });
  return offers;
});
