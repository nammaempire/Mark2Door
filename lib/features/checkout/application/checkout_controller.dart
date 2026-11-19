import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../cart/application/cart_controller.dart';
import '../../orders/domain/order.dart';
import '../../rewards/application/rewards_providers.dart';
import '../../store/application/store_providers.dart';
import '../data/payment_gateway.dart';
import '../domain/address.dart';
import 'address_book.dart';

@immutable
class CheckoutResult {
  const CheckoutResult({required this.orderId, required this.outcome});

  final String orderId;
  final PaymentOutcome outcome;
}

class CheckoutFailure implements Exception {
  const CheckoutFailure(this.message);
  final String message;
}

final checkoutControllerProvider =
    AsyncNotifierProvider.autoDispose<CheckoutController, void>(
  CheckoutController.new,
);

/// Orchestrates "place order": validate -> create order -> take payment ->
/// record the outcome. The UI only reacts to the returned [CheckoutResult].
class CheckoutController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns null when the order could not be placed; the reason is then
  /// available as this provider's error state.
  Future<CheckoutResult?> placeOrder({
    required Address address,
    required PaymentMethod method,
    bool useWallet = false,
  }) async {
    if (state.isLoading) return null; // guard against double taps
    state = const AsyncLoading();
    try {
      final result = await _placeOrder(address, method, useWallet);
      state = const AsyncData(null);
      return result;
    } on CheckoutFailure catch (e, st) {
      state = AsyncError(e, st);
      return null;
    } catch (e, st) {
      state = AsyncError(
        const CheckoutFailure('Could not place your order. Try again.'),
        st,
      );
      return null;
    }
  }

  Future<CheckoutResult> _placeOrder(
    Address address,
    PaymentMethod method,
    bool useWallet,
  ) async {
    final user = ref.read(currentUserProvider);
    final cart = ref.read(cartProvider);
    if (user == null) throw const CheckoutFailure('Log in to place an order.');
    if (cart.isEmpty) throw const CheckoutFailure('Your cart is empty.');

    // The pincode was checked earlier, but the admin may have changed the
    // service area since, so confirm again at the point of commitment.
    final serviceable = await ref
        .read(serviceAreaRepositoryProvider)
        .isServiceable(address.pincode);
    if (!serviceable) {
      throw CheckoutFailure("We don't deliver to ${address.pincode} yet.");
    }

    final orders = ref.read(orderRepositoryProvider);
    final now = DateTime.now();
    final walletApplied = useWallet
        ? walletAmountFor(cart.totalPaise, ref.read(walletBalanceProvider))
        : 0;
    final order = await orders.create(
      Order(
        id: '',
        userId: user.uid,
        items: cart.lines.map(OrderItem.fromCart).toList(growable: false),
        subtotalPaise: cart.subtotalPaise,
        deliveryFeePaise: cart.deliveryFeePaise,
        handlingFeePaise: cart.handlingFeePaise,
        rainFeePaise: cart.rainFeePaise,
        totalPaise: cart.totalPaise,
        walletAppliedPaise: walletApplied,
        address: address,
        paymentMethod: method,
        paymentStatus: PaymentStatus.pending,
        status: OrderStatus.placed,
        createdAt: now,
        etaAt: now.add(
          Duration(
            minutes: ref.read(storeSettingsProvider).deliveryEtaMinutes,
          ),
        ),
      ),
    );
    ref.read(addressBookProvider.notifier).use(address);

    if (method == PaymentMethod.cod) {
      ref.read(cartProvider.notifier).clear();
      return CheckoutResult(orderId: order.id, outcome: PaymentOutcome.success);
    }

    if (order.payablePaise == 0) {
      // The wallet covered everything, so there is nothing to charge.
      await orders.updatePayment(order.id, paymentStatus: PaymentStatus.paid);
      ref.read(cartProvider.notifier).clear();
      return CheckoutResult(orderId: order.id, outcome: PaymentOutcome.success);
    }

    final payment = await ref.read(paymentGatewayProvider).pay(
          PaymentRequest(
            orderId: order.id,
            amountPaise: order.payablePaise,
            phone: address.phone,
            description: 'Order ${order.displayId}',
          ),
        );

    switch (payment.outcome) {
      case PaymentOutcome.success:
        await orders.updatePayment(
          order.id,
          paymentStatus: PaymentStatus.paid,
          paymentId: payment.paymentId,
        );
        ref.read(cartProvider.notifier).clear();
      case PaymentOutcome.pending:
        await orders.updatePayment(
          order.id,
          paymentStatus: PaymentStatus.pending,
        );
        ref.read(cartProvider.notifier).clear();
      case PaymentOutcome.failed:
        // Keep the cart so the shopper can retry without rebuilding it.
        await orders.updatePayment(
          order.id,
          paymentStatus: PaymentStatus.failed,
          status: OrderStatus.cancelled,
        );
    }
    return CheckoutResult(orderId: order.id, outcome: payment.outcome);
  }
}

/// How much of [balancePaise] goes towards an order of [totalPaise]: all of
/// it, up to the order's value.
int walletAmountFor(int totalPaise, int balancePaise) {
  if (balancePaise <= 0 || totalPaise <= 0) return 0;
  return balancePaise < totalPaise ? balancePaise : totalPaise;
}
