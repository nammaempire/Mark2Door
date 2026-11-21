import '../domain/order.dart';

abstract interface class OrderRepository {
  /// Persists [draft] (its `id` is ignored) and returns it with the real id.
  ///
  /// With [recordCouponUse], the order's coupon is marked as used by this
  /// customer in the same step, so a once-only code cannot be used twice.
  Future<Order> create(Order draft, {bool recordCouponUse = false});

  /// Cancels an order for the shopper. Allowed until the delivery partner
  /// has picked it up; see `Order.canCancel`.
  Future<void> cancel(String orderId);

  Future<void> updatePayment(
    String orderId, {
    required PaymentStatus paymentStatus,
    OrderStatus? status,
    String? paymentId,
  });

  /// Saves the shopper's rating (1 to 5 stars) for a delivered order's
  /// delivery partner. A delivery can be rated once.
  Future<void> rateDelivery(String orderId, int stars);

  /// Newest first.
  Stream<List<Order>> watchOrders(String userId);

  Stream<Order?> watchOrder(String orderId);
}
