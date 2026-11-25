import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../orders/domain/order.dart';
import '../data/payment_gateway.dart';

/// Pays online for an order that was placed but whose payment did not go
/// through (the shopper closed the payment screen, lost network, or the
/// bank is still deciding). The order stays as it is; only the payment is
/// tried again.
final payAgainProvider =
    AsyncNotifierProvider.autoDispose<PayAgainController, void>(
  PayAgainController.new,
);

class PayAgainController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Opens the payment screen for [order] and records the result. Never
  /// throws. A failed try leaves the order waiting for payment, so the
  /// shopper can simply try once more.
  Future<PaymentResult?> pay(Order order) async {
    if (state.isLoading) return null; // guard against double taps
    state = const AsyncLoading();
    // Read before the first wait: this provider may be gone afterwards.
    final gateway = ref.read(paymentGatewayProvider);
    final orders = ref.read(orderRepositoryProvider);
    PaymentResult result;
    try {
      result = await gateway.pay(
        PaymentRequest(
          orderId: order.id,
          amountPaise: order.payablePaise,
          phone: order.address.phone,
          description: 'Order ${order.displayId}',
        ),
      );
      if (result.outcome == PaymentOutcome.success &&
          !gateway.confirmsOnServer) {
        await orders.updatePayment(
          order.id,
          paymentStatus: PaymentStatus.paid,
          paymentId: result.paymentId,
        );
      }
    } catch (_) {
      result = const PaymentResult(
        PaymentOutcome.failed,
        message: 'Could not take the payment. Try again.',
      );
    }
    state = const AsyncData(null);
    return result;
  }
}
