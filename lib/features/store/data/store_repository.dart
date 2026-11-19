import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/store_settings.dart';
import '../../catalog/domain/promo.dart';

/// Storefront content managed from the admin web.
abstract interface class StoreRepository {
  /// Emits the current settings, then every change.
  Stream<StoreSettings> watchSettings();

  /// Active banners in display order.
  Future<List<Promo>> fetchBanners();
}

class FakeStoreRepository implements StoreRepository {
  static const banners = <Promo>[
    Promo(
      title: 'Farm fresh\nfruits & veggies',
      subtitle: 'Up to 25% off today',
      emoji: '🥦',
      theme: 'maroon',
      categoryId: 'fruits',
    ),
    Promo(
      title: 'Monthly staples\nat mart prices',
      subtitle: 'Atta, rice, dal and oil',
      emoji: '🛒',
      theme: 'rose',
      categoryId: 'staples',
    ),
    Promo(
      title: 'Snack time\nfavourites',
      subtitle: 'Chips, biscuits and more',
      emoji: '🍿',
      theme: 'plum',
      categoryId: 'snacks',
    ),
  ];

  @override
  Stream<StoreSettings> watchSettings() => Stream.value(StoreSettings.defaults);

  @override
  Future<List<Promo>> fetchBanners() async => banners;
}

/// `settings/store` (one document) and `banners/{id}`.
class FirestoreStoreRepository implements StoreRepository {
  FirestoreStoreRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<StoreSettings> watchSettings() =>
      _db.collection('settings').doc('store').snapshots().map((doc) {
        final data = doc.data();
        return data == null
            ? StoreSettings.defaults
            : StoreSettings.fromMap(data);
      });

  @override
  Future<List<Promo>> fetchBanners() async {
    final snap = await _db.collection('banners').orderBy('sortOrder').get();
    // "active" is filtered here so no composite index is needed.
    return snap.docs
        .where((d) => d.data()['active'] as bool? ?? true)
        .map((d) => Promo.fromMap(d.data()))
        .toList(growable: false);
  }
}
