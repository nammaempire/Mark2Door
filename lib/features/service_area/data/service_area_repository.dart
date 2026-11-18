import 'package:cloud_firestore/cloud_firestore.dart';

abstract interface class ServiceAreaRepository {
  Future<bool> isServiceable(String pincode);
}

class FakeServiceAreaRepository implements ServiceAreaRepository {
  /// Sample serviceable pincodes (Bengaluru).
  static const pincodes = {'560001', '560034', '560038', '560068', '560102'};

  @override
  Future<bool> isServiceable(String pincode) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return pincodes.contains(pincode);
  }
}

/// Collection: `service_areas/{pincode}` with `{active: true}`,
/// maintained from the admin web.
class FirestoreServiceAreaRepository implements ServiceAreaRepository {
  FirestoreServiceAreaRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Future<bool> isServiceable(String pincode) async {
    final doc = await _db.collection('service_areas').doc(pincode).get();
    return doc.exists && (doc.data()?['active'] as bool? ?? false);
  }
}
