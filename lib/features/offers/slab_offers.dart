import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';

/// A price slab offer set by the admin: once the items in the cart reach
/// [minOrderPaise], the shopper may pick one product from [productIds]
/// at [offerPricePaise] instead of its selling price.
/// Firestore: `slab_offers/{id}`.
@immutable
class SlabOffer {
  const SlabOffer({
    required this.id,
    required this.minOrderPaise,
    required this.offerPricePaise,
    required this.productIds,
    this.active = true,
  });

  final String id;
  final int minOrderPaise;
  final int offerPricePaise;
  final List<String> productIds;
  final bool active;

  /// True when a cart whose items come to [itemsPaise] has earned it.
  bool unlockedBy(int itemsPaise) => itemsPaise >= minOrderPaise;

  factory SlabOffer.fromMap(String id, Map<String, dynamic> map) => SlabOffer(
        id: id,
        minOrderPaise: (map['minOrderPaise'] as num?)?.toInt() ?? 0,
        offerPricePaise: (map['offerPricePaise'] as num?)?.toInt() ?? 0,
        productIds: [
          for (final p in (map['productIds'] as List?) ?? const []) '$p',
        ],
        active: map['active'] as bool? ?? true,
      );
}

abstract interface class SlabOfferRepository {
  /// The offers that are switched on, lowest cart amount first.
  Future<List<SlabOffer>> fetchActive();
}

/// Sample mode: no offers unless a test or demo adds some.
class FakeSlabOfferRepository implements SlabOfferRepository {
  FakeSlabOfferRepository([List<SlabOffer>? offers]) : offers = offers ?? [];

  final List<SlabOffer> offers;

  @override
  Future<List<SlabOffer>> fetchActive() async => _sorted(offers);
}

class FirestoreSlabOfferRepository implements SlabOfferRepository {
  FirestoreSlabOfferRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Future<List<SlabOffer>> fetchActive() async {
    final snap = await _db.collection('slab_offers').get();
    return _sorted([
      for (final d in snap.docs) SlabOffer.fromMap(d.id, d.data()),
    ]);
  }
}

List<SlabOffer> _sorted(Iterable<SlabOffer> offers) => [
      for (final o in offers)
        if (o.active && o.minOrderPaise > 0 && o.productIds.isNotEmpty) o,
    ]..sort((a, b) => a.minOrderPaise.compareTo(b.minOrderPaise));

final slabOfferRepositoryProvider = Provider<SlabOfferRepository>(
  (ref) => Env.useFirebase
      ? FirestoreSlabOfferRepository(FirebaseFirestore.instance)
      : FakeSlabOfferRepository(),
);

/// Offers in force now. Read again each time the cart page opens, so a
/// change by the admin shows without restarting the app.
final slabOffersProvider = FutureProvider.autoDispose<List<SlabOffer>>(
  (ref) => ref.watch(slabOfferRepositoryProvider).fetchActive(),
);
