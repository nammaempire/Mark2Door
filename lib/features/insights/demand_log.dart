import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/storage/local_store.dart';

/// Why a search gave the shopper nothing to buy.
enum SearchMiss {
  /// No product matches what they typed.
  notFound,

  /// Products match, but every one of them is out of stock.
  outOfStock,
}

/// Where unmet demand is recorded for the store.
abstract interface class DemandRepository {
  /// A shopper asked for delivery to a pincode the store does not serve.
  Future<void> pincodeNotServed(String pincode);

  /// A shopper searched for [term] and found nothing they could buy.
  Future<void> searchMiss(String term, SearchMiss kind);
}

/// Sample-data stand-in that just remembers what was recorded.
class FakeDemandRepository implements DemandRepository {
  final pincodes = <String>[];
  final searches = <(String, SearchMiss)>[];

  @override
  Future<void> pincodeNotServed(String pincode) async => pincodes.add(pincode);

  @override
  Future<void> searchMiss(String term, SearchMiss kind) async =>
      searches.add((term, kind));
}

/// Collections `pincode_requests/{pincode}` and `search_misses/{term}`,
/// each a running count that the admin web lists under "Demand".
class FirestoreDemandRepository implements DemandRepository {
  FirestoreDemandRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Future<void> pincodeNotServed(String pincode) =>
      _db.collection('pincode_requests').doc(pincode).set({
        'pincode': pincode,
        'count': FieldValue.increment(1),
        'lastAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));

  @override
  Future<void> searchMiss(String term, SearchMiss kind) =>
      _db.collection('search_misses').doc(DemandLog.keyFor(term)).set({
        'term': term,
        'count': FieldValue.increment(1),
        // Counted separately, so the store sees which kind it mostly is.
        kind == SearchMiss.notFound ? 'notFound' : 'outOfStock':
            FieldValue.increment(1),
        'lastAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
}

/// Records unmet demand once per shopper: a pincode they could not get
/// delivery to, or a search that found nothing to buy. Counting each
/// shopper once keeps one person checking again and again from looking
/// like many customers.
///
/// Recording never gets in the shopper's way: it happens in the
/// background and a failure is ignored.
class DemandLog {
  DemandLog(this._repo, this._store);

  final DemandRepository _repo;
  final LocalStore _store;

  static const storeKey = 'demand_logged';

  /// Searches shorter than this are half-typed words, not real demand.
  static const minSearchLength = 3;

  /// Lower case, single spaces: "  Dragon  FRUIT " and "dragon fruit" are
  /// the same search.
  static String normalise(String term) =>
      term.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// The document id for a search term: letters and digits, with dashes.
  static String keyFor(String term) {
    final key = normalise(term)
        .replaceAll(RegExp(r'[^a-z0-9\u0080-￿]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final short = key.length > 60 ? key.substring(0, 60) : key;
    return short.isEmpty ? 'other' : short;
  }

  Set<String> _seen() {
    final saved = _store.readJson(storeKey)?['seen'];
    return saved is List ? saved.whereType<String>().toSet() : <String>{};
  }

  /// True the first time [tag] is seen on this phone.
  bool _firstTime(String tag) {
    final seen = _seen();
    if (!seen.add(tag)) return false;
    // Only the most recent few hundred are kept.
    final keep = seen.length > 300 ? seen.skip(seen.length - 300) : seen;
    unawaited(_store.writeJson(storeKey, {'seen': keep.toList()}));
    return true;
  }

  void pincodeNotServed(String pincode) {
    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(pincode)) return;
    if (!_firstTime('pin:$pincode')) return;
    unawaited(_repo.pincodeNotServed(pincode).catchError((Object _) {}));
  }

  void searchMiss(String term, SearchMiss kind) {
    final clean = normalise(term);
    if (clean.length < minSearchLength) return;
    if (!_firstTime('q:$clean')) return;
    unawaited(_repo.searchMiss(clean, kind).catchError((Object _) {}));
  }
}
