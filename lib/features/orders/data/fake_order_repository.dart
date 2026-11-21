import 'dart:async';

import '../../checkout/data/coupon_repository.dart';
import '../../rewards/data/rewards_repository.dart';
import '../domain/order.dart';
import 'order_repository.dart';

/// Keeps orders in memory for the session (sample-data mode).
class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository({this.rewards, this.coupons}) {
    rewards?.hasOrders =
        (uid) => _orders.values.any((o) => o.userId == uid);
  }

  /// Sample wallet that wallet-paid orders are taken from.
  final FakeRewardsRepository? rewards;

  /// Sample coupons, so a once-only code is marked as used.
  final FakeCouponRepository? coupons;

  final _orders = <String, Order>{};
  final _changes = StreamController<void>.broadcast();
  int _seq = 1000;

  @override
  Future<Order> create(Order draft, {bool recordCouponUse = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final order = draft.copyWith(id: 'M2D${++_seq}');
    if (recordCouponUse && order.couponCode != null) {
      coupons?.used.add('${order.couponCode}|${order.userId}');
    }
    if (order.walletAppliedPaise > 0) {
      rewards?.spend(
        order.userId,
        order.walletAppliedPaise,
        'Paid for order ${order.displayId}',
      );
    }
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
    if (status == OrderStatus.cancelled) _releaseCoupon(order);
    _changes.add(null);
  }

  @override
  Future<void> cancel(String orderId) async {
    final order = _orders[orderId];
    if (order == null || !order.canCancel) return;
    _orders[orderId] = order.copyWith(
      status: OrderStatus.cancelled,
      cancelledBy: 'customer',
    );
    _releaseCoupon(order);
    // The server gives wallet money back; sample data does it here.
    if (order.walletAppliedPaise > 0) {
      rewards?.refund(
        order.userId,
        order.walletAppliedPaise,
        'Returned from cancelled order ${order.displayId}',
      );
    }
    _changes.add(null);
  }

  /// A cancelled order gives its once-only coupon back, as the server does.
  void _releaseCoupon(Order order) =>
      coupons?.used.remove('${order.couponCode}|${order.userId}');

  /// Moves an order along, as the admin and the delivery app do. Sample
  /// data has neither, so tests and demos call this.
  void advance(String orderId, OrderStatus status, {String? riderName}) {
    final order = _orders[orderId];
    if (order == null) return;
    _orders[orderId] = order.copyWith(status: status, riderName: riderName);
    _changes.add(null);
  }

  @override
  Future<void> rateDelivery(String orderId, int stars) async {
    final order = _orders[orderId];
    if (order == null) return;
    _orders[orderId] = order.copyWith(riderRating: stars);
    _changes.add(null);
  }

  /// Marks an order delivered by [riderName], as the delivery app does.
  /// Sample data has no delivery app, so tests and demos call this.
  void deliver(String orderId, {required String riderName}) {
    final order = _orders[orderId];
    if (order == null) return;
    _orders[orderId] = order.copyWith(
      status: OrderStatus.delivered,
      riderName: riderName,
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
