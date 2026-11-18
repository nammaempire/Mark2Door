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
  Future<Order> create(Order draft) async {
    final doc = _col.doc();
    await doc.set(draft.toMap());
    return draft.copyWith(id: doc.id);
  }

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
    });
  }

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
