import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/domain/app_user.dart';

/// The shopper's own details, kept with their account (`users/{uid}`) so
/// the name survives a reinstall and the store can see who the customer is.
abstract interface class CustomerProfileRepository {
  /// The saved name, or null when the shopper has not given one yet.
  Future<String?> fetchName(String uid);

  Future<void> saveName(AppUser user, String name);

  /// Removes what the app keeps about the shopper's account: their profile
  /// and their m2d wallet. Past orders stay with the store as sales records.
  Future<void> deleteData(AppUser user);
}

class FakeCustomerProfileRepository implements CustomerProfileRepository {
  final _names = <String, String>{};

  @override
  Future<String?> fetchName(String uid) async => _names[uid];

  @override
  Future<void> saveName(AppUser user, String name) async =>
      _names[user.uid] = name;

  /// Accounts deleted so far, by uid.
  final deleted = <String>{};

  @override
  Future<void> deleteData(AppUser user) async {
    _names.remove(user.uid);
    deleted.add(user.uid);
  }
}

class FirestoreCustomerProfileRepository implements CustomerProfileRepository {
  FirestoreCustomerProfileRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Future<String?> fetchName(String uid) async {
    final data = (await _db.collection('users').doc(uid).get()).data();
    final name = (data?['name'] as String? ?? '').trim();
    return name.isEmpty ? null : name;
  }

  @override
  Future<void> saveName(AppUser user, String name) =>
      _db.collection('users').doc(user.uid).set(
        {'name': name, 'phone': user.phone},
        SetOptions(merge: true),
      );

  /// One write, so either everything goes or nothing does. The
  /// `deleted_accounts` marker stops a deleted number from collecting
  /// invite rewards again after signing up afresh.
  @override
  Future<void> deleteData(AppUser user) {
    final batch = _db.batch()
      ..delete(_db.collection('users').doc(user.uid))
      ..delete(_db.collection('wallets').doc(user.uid))
      ..set(_db.collection('deleted_accounts').doc(user.phone), {
        'uid': user.uid,
        'deletedAt': DateTime.now().millisecondsSinceEpoch,
      });
    return batch.commit();
  }
}
