import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// A pincode the store delivers to instantly, with the area name the
/// admin typed for it (may be empty).
@immutable
class ServiceArea {
  const ServiceArea(this.pincode, [this.name = '']);

  final String pincode;
  final String name;

  /// "629001 - Nagercoil", or just the pincode when no name was given.
  String get label => name.isEmpty ? pincode : '$pincode - $name';
}

abstract interface class ServiceAreaRepository {
  Future<bool> isServiceable(String pincode);

  /// Every pincode with instant delivery switched on, lowest first.
  Future<List<ServiceArea>> fetchAreas();

  /// The store that delivers to [pincode], for a business with several
  /// stores; null with one shop, or when the pincode is not served.
  Future<String?> storeIdFor(String pincode);
}

class FakeServiceAreaRepository implements ServiceAreaRepository {
  /// Sample serviceable pincodes (Bengaluru).
  static const pincodes = {'560001', '560034', '560038', '560068', '560102'};

  static const _names = {
    '560001': 'MG Road',
    '560034': 'Koramangala',
    '560038': 'Indiranagar',
    '560068': 'Bommanahalli',
    '560102': 'HSR Layout',
  };

  @override
  Future<bool> isServiceable(String pincode) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return pincodes.contains(pincode);
  }

  @override
  Future<List<ServiceArea>> fetchAreas() async => [
        for (final p in pincodes) ServiceArea(p, _names[p] ?? ''),
      ];

  /// In the sample data, HSR Layout is served by a second store.
  static const secondStoreId = 'store-hsr';

  @override
  Future<String?> storeIdFor(String pincode) async =>
      pincode == '560102' ? secondStoreId : null;
}

/// Collection: `service_areas/{pincode}` with `{active: true, name}`,
/// maintained from the admin web.
class FirestoreServiceAreaRepository implements ServiceAreaRepository {
  FirestoreServiceAreaRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Future<bool> isServiceable(String pincode) async {
    final doc = await _db.collection('service_areas').doc(pincode).get();
    return doc.exists && (doc.data()?['active'] as bool? ?? false);
  }

  @override
  Future<List<ServiceArea>> fetchAreas() async {
    final snap = await _db.collection('service_areas').get();
    final areas = [
      for (final d in snap.docs)
        if (d.data()['active'] as bool? ?? false)
          ServiceArea(d.id, (d.data()['name'] as String? ?? '').trim()),
    ]..sort((a, b) => a.pincode.compareTo(b.pincode));
    return areas;
  }

  @override
  Future<String?> storeIdFor(String pincode) async {
    final doc = await _db.collection('service_areas').doc(pincode).get();
    final id = (doc.data()?['storeId'] as String? ?? '').trim();
    return id.isEmpty ? null : id;
  }
}
