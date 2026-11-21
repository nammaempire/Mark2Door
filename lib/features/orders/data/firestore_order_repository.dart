// Newer cloud_firestore versions export their own `Order` type.
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../domain/order.dart';
import 'order_repository.dart';

/// Collection: `orders/{id}`. The delivery app and admin web read and
/// advance `status` on the same documents.
class FirestoreOrderRepository implements OrderRepository {
  FirestoreOrderRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('orders');

  @override
  Future<Order> create(Order draft, {bool recordCouponUse = false}) async {
    final doc = _col.doc();
    final order = draft.copyWith(id: doc.id);
    final at = order.createdAt.millisecondsSinceEpoch;
    // Everything below happens together or not at all.
    final batch = _db.batch()..set(doc, order.toMap());
    if (order.walletAppliedPaise > 0) {
      // The security rules accept the order only if the same batch takes
      // exactly `walletAppliedPaise` out of the shopper's wallet.
      final wallet = _db.collection('wallets').doc(order.userId);
      batch
        ..update(wallet, {
          'balancePaise': FieldValue.increment(-order.walletAppliedPaise),
          'updatedAt': at,
        })
        ..set(wallet.collection('transactions').doc(doc.id), {
          'amountPaise': -order.walletAppliedPaise,
          'type': 'order_payment',
          'note': 'Paid for order ${order.displayId}',
          'orderId': doc.id,
          'createdAt': at,
        });
    }
    final code = order.couponCode;
    if (recordCouponUse && code != null) {
      // The rules refuse a second "uses" document for the same customer,
      // which makes the whole order fail if the code was already used.
      batch.set(
        _db
            .collection('coupons')
            .doc(code)
            .collection('uses')
            .doc(order.userId),
        {'orderId': doc.id, 'usedAt': at},
      );
    }
    await batch.commit();
    return order;
  }

  @override
  Future<void> cancel(String orderId) => _col.doc(orderId).update({
        'status': OrderStatus.cancelled.name,
        'cancelledBy': 'customer',
        'cancelledAt': DateTime.now().millisecondsSinceEpoch,
      });

  @override
  Future<void> updatePayment(
    String orderId, {
    required PaymentStatus paymentStatus,
    OrderStatus? status,
    String? paymentId,
  }) {
    return _col.doc(orderId).update({
      'paymentStatus': paymentStatus.name,
      if (status != null) 'status': status.name,
      if (paymentId != null) 'paymentId': paymentId,
      // Lets the server tell the shopper their payment is still pending.
      if (paymentStatus == PaymentStatus.pending)
        'paymentPendingAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> rateDelivery(String orderId, int stars) =>
      _col.doc(orderId).update({
        'riderRating': stars,
        'riderRatedAt': DateTime.now().millisecondsSinceEpoch,
      });

  @override
  Stream<List<Order>> watchOrders(String userId) {
    // Needs a composite index on (userId ASC, createdAt DESC).
    return _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Order.fromMap(d.id, d.data()))
            .toList(growable: false));
  }

  @override
  Stream<Order?> watchOrder(String orderId) {
    return _col.doc(orderId).snapshots().map((doc) {
      final data = doc.data();
      return data == null ? null : Order.fromMap(doc.id, data);
    });
  }
}
