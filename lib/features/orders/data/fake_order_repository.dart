import 'dart:async';

import '../domain/order.dart';
import 'order_repository.dart';

/// Keeps orders in memory for the session (sample-data mode).
class FakeOrderRepository implements OrderRepository {
  final _orders = <String, Order>{};
  final _changes = StreamController<void>.broadcast();
  int _seq = 1000;

  @override
  Future<Order> create(Order draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final order = draft.copyWith(id: 'M2D${++_seq}');
    _orders[order.id] = order;
    _changes.add(null);
    return order;
  }

  @override
  Future<void> updatePayment(
    String orderId, {
    required PaymentStatus paymentStatus,
    OrderStatus? status,
    String? paymentId,
  }) async {
    final order = _orders[orderId];
    if (order == null) return;
    _orders[orderId] = order.copyWith(
      paymentStatus: paymentStatus,
      status: status,
      paymentId: paymentId,
    );
    _changes.add(null);
  }

  List<Order> _forUser(String userId) =>
      _orders.values.where((o) => o.userId == userId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Stream<List<Order>> watchOrders(String userId) async* {
    yield _forUser(userId);
    yield* _changes.stream.map((_) => _forUser(userId));
  }

  @override
  Stream<Order?> watchOrder(String orderId) async* {
    yield _orders[orderId];
    yield* _changes.stream.map((_) => _orders[orderId]);
  }
}
