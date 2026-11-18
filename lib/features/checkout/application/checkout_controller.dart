import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/storage/local_store.dart';
import '../../auth/application/auth_providers.dart';
import '../../cart/application/cart_controller.dart';
import '../../orders/domain/order.dart';
import '../../store/application/store_providers.dart';
import '../data/payment_gateway.dart';
import '../domain/address.dart';

/// Last delivery address used on this device; pre-fills the checkout form.
final savedAddressProvider =
    NotifierProvider<SavedAddressController, Address?>(
  SavedAddressController.new,
);

class SavedAddressController extends Notifier<Address?> {
  @override
  Address? build() {
    final map = ref.read(localStoreProvider).readJson(LocalStore.addressKey);
    return map == null ? null : Address.fromMap(map);
  }

  void save(Address address) {
    state = address;
    ref.read(localStoreProvider).writeJson(LocalStore.addressKey, address.toMap());
  }
}

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
  }) async {
    if (state.isLoading) return null; // guard against double taps
    state = const AsyncLoading();
    try {
      final result = await _placeOrder(address, method);
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
    final order = await orders.create(
      Order(
        id: '',
        userId: user.uid,
        items: cart.lines.map(OrderItem.fromCart).toList(growable: false),
        subtotalPaise: cart.subtotalPaise,
        deliveryFeePaise: cart.deliveryFeePaise,
        totalPaise: cart.totalPaise,
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
    ref.read(savedAddressProvider.notifier).save(address);

    if (method == PaymentMethod.cod) {
      ref.read(cartProvider.notifier).clear();
      return CheckoutResult(orderId: order.id, outcome: PaymentOutcome.success);
    }

    final payment = await ref.read(paymentGatewayProvider).pay(
          PaymentRequest(
            orderId: order.id,
            amountPaise: order.totalPaise,
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
