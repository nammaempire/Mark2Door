import '../domain/order.dart';

abstract interface class OrderRepository {
  /// Persists [draft] (its `id` is ignored) and returns it with the real id.
  Future<Order> create(Order draft);

  Future<void> updatePayment(
    String orderId, {
    required PaymentStatus paymentStatus,
    OrderStatus? status,
    String? paymentId,
  });

  /// Newest first.
  Stream<List<Order>> watchOrders(String userId);

  Stream<Order?> watchOrder(String orderId);
}
