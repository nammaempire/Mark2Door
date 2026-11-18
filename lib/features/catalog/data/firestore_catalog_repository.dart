import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/product.dart';
import 'catalog_repository.dart';

/// Collections: `categories/{id}`, `products/{id}` (written by the admin web).
class FirestoreCatalogRepository implements CatalogRepository {
  FirestoreCatalogRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Future<List<Category>> fetchCategories() async {
    final snap = await _db.collection('categories').orderBy('name').get();
    return snap.docs
        .map((d) => Category.fromMap(d.id, d.data()))
        .toList(growable: false);
  }

  @override
  Future<List<Product>> fetchProducts({String? categoryId, String? query}) async {
    Query<Map<String, dynamic>> ref = _db.collection('products');
    if (categoryId != null) {
      ref = ref.where('categoryId', isEqualTo: categoryId);
    }
    final snap = await ref.get();
    final q = query?.trim().toLowerCase() ?? '';
    // A single-area catalogue is small, so name search is filtered client
    // side. Move to Algolia/Typesense if the catalogue outgrows this.
    final items = snap.docs
        .map((d) => Product.fromMap(d.id, d.data()))
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  @override
  Future<Product?> fetchProduct(String id) async {
    final doc = await _db.collection('products').doc(id).get();
    final data = doc.data();
    return data == null ? null : Product.fromMap(doc.id, data);
  }
}
