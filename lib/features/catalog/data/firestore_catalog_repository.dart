import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/product.dart';
import 'catalog_repository.dart';
import 'live_list.dart';

/// Collections: `categories/{id}`, `products/{id}` (written by the admin web).
///
/// The product list and the categories are each read once and then kept
/// up to date by a live connection for as long as the app is open. Every
/// screen (home, categories, search, cart suggestions) filters that one
/// copy on the phone, so opening a page or typing a search costs no
/// database reads, and a change by the store (price, stock, a new
/// product) reaches the app in a moment.
class FirestoreCatalogRepository implements CatalogRepository {
  FirestoreCatalogRepository(this._db) {
    _products = LiveList(
      () => _live('products', (d) => Product.fromMap(d.id, d.data())),
      _changed,
    );
    _categories = LiveList(
      () => _live('categories', (d) => Category.fromMap(d.id, d.data())),
      _changed,
    );
  }

  /// A collection's live updates, each as the whole list.
  Stream<LiveSnapshot<T>> _live<T>(
    String collection,
    T Function(QueryDocumentSnapshot<Map<String, dynamic>>) parse,
  ) =>
      _db.collection(collection).snapshots(includeMetadataChanges: true).map(
            (snap) => LiveSnapshot(
              [for (final d in snap.docs) parse(d)],
              fromCache: snap.metadata.isFromCache,
              changed: snap.docChanges.isNotEmpty,
            ),
          );

  final FirebaseFirestore _db;
  late final LiveList<Product> _products;
  late final LiveList<Category> _categories;

  final _changes = StreamController<void>.broadcast();
  Timer? _settle;

  /// Many changes close together (a busy hour of orders moving stock)
  /// are passed on as one.
  void _changed() {
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 400), () {
      if (!_changes.isClosed) _changes.add(null);
    });
  }

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<Category>> fetchCategories() async =>
      [...await _categories.items()]..sort((a, b) => a.name.compareTo(b.name));

  @override
  Future<List<Product>> fetchProducts({String? categoryId, String? query}) async {
    final q = query?.trim().toLowerCase() ?? '';
    // Filtered on the phone from the one live copy of the catalogue.
    // Move name search to Algolia/Typesense if the catalogue outgrows it.
    return [
      for (final p in await _products.items())
        if ((categoryId == null || p.categoryId == categoryId) &&
            (q.isEmpty || p.name.toLowerCase().contains(q)))
          p,
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Always read from the server: checkout relies on this for the price
  /// and stock at that very moment.
  @override
  Future<Product?> fetchProduct(String id) async {
    final doc = await _db.collection('products').doc(id).get();
    final data = doc.data();
    return data == null ? null : Product.fromMap(doc.id, data);
  }
}
