import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/coupon.dart';

abstract interface class CouponRepository {
  /// The coupon with this [code] (already normalised), or null when the
  /// store has no such code.
  Future<Coupon?> find(String code);

  /// Whether the customer [uid] has already used a once-only [code].
  Future<bool> alreadyUsed(String code, String uid);

  /// Every coupon the store has switched on, for the list at checkout.
  Future<List<Coupon>> fetchAll();
}

/// Sample coupons so the app can be tried without a backend.
class FakeCouponRepository implements CouponRepository {
  FakeCouponRepository();

  static final coupons = <String, Coupon>{
    'WELCOME50': const Coupon(
      code: 'WELCOME50',
      type: CouponType.flat,
      value: 5000,
      minOrderPaise: 19900,
      oncePerCustomer: true,
    ),
    'SAVE10': const Coupon(
      code: 'SAVE10',
      type: CouponType.percent,
      value: 10,
      maxDiscountPaise: 10000,
    ),
    'OLD20': Coupon(
      code: 'OLD20',
      type: CouponType.percent,
      value: 20,
      expiresAt: DateTime(2020),
    ),
  };

  /// "CODE|uid" for each once-only coupon a sample customer has used.
  final used = <String>{};

  @override
  Future<Coupon?> find(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return coupons[code];
  }

  @override
  Future<bool> alreadyUsed(String code, String uid) async =>
      used.contains('$code|$uid');

  @override
  Future<List<Coupon>> fetchAll() async =>
      coupons.values.where((c) => c.active).toList(growable: false);
}

/// Collection: `coupons/{CODE}`, with one `uses/{uid}` document for each
/// customer who has used a once-only code.
class FirestoreCouponRepository implements CouponRepository {
  FirestoreCouponRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Future<Coupon?> find(String code) async {
    // A code with a slash could not be a document id.
    if (code.isEmpty || code.contains('/')) return null;
    final doc = await _db.collection('coupons').doc(code).get();
    final data = doc.data();
    return data == null ? null : Coupon.fromMap(doc.id, data);
  }

  @override
  Future<bool> alreadyUsed(String code, String uid) async {
    final doc = await _db
        .collection('coupons')
        .doc(code)
        .collection('uses')
        .doc(uid)
        .get();
    return doc.exists;
  }

  @override
  Future<List<Coupon>> fetchAll() async {
    final snap = await _db.collection('coupons').get();
    return snap.docs
        .map((d) => Coupon.fromMap(d.id, d.data()))
        .where((c) => c.active)
        .toList(growable: false);
  }
}
