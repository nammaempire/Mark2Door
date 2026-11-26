import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';

/// A product a shopper could not find and asked the store to get.
/// The store sees it in the admin web with the shopper's name, number
/// and delivery pincode, and calls back to say how long it will take.
/// Firestore: `product_requests/{id}`.
@immutable
class ProductRequest {
  const ProductRequest({
    required this.uid,
    required this.product,
    required this.quantity,
    required this.customerName,
    required this.phone,
    required this.pincode,
  });

  final String uid;
  final String product;

  /// As the shopper wrote it, for example "2" or "5 kg".
  final String quantity;
  final String customerName;
  final String phone;
  final String pincode;

  Map<String, dynamic> toMap(DateTime now) => {
        'uid': uid,
        'product': product,
        'quantity': quantity,
        'customerName': customerName,
        'phone': phone,
        'pincode': pincode,
        'status': 'new',
        'createdAt': now.millisecondsSinceEpoch,
      };
}

abstract interface class ProductRequestRepository {
  Future<void> send(ProductRequest request);
}

/// Sample mode: remembers what was sent.
class FakeProductRequestRepository implements ProductRequestRepository {
  final sent = <ProductRequest>[];

  @override
  Future<void> send(ProductRequest request) async => sent.add(request);
}

class FirestoreProductRequestRepository implements ProductRequestRepository {
  FirestoreProductRequestRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Future<void> send(ProductRequest request) => _db
      .collection('product_requests')
      .add(request.toMap(DateTime.now()));
}

final productRequestRepositoryProvider = Provider<ProductRequestRepository>(
  (ref) => Env.useFirebase
      ? FirestoreProductRequestRepository(FirebaseFirestore.instance)
      : FakeProductRequestRepository(),
);
