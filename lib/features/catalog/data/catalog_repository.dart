import '../domain/product.dart';

abstract interface class CatalogRepository {
  Future<List<Category>> fetchCategories();

  /// [categoryId] and [query] are both optional filters.
  Future<List<Product>> fetchProducts({String? categoryId, String? query});

  /// One product read fresh from the store's records, for the moments
  /// that need the price and stock exactly right (checkout).
  Future<Product?> fetchProduct(String id);

  /// Fires when the store changes the catalogue (a price, stock, a new
  /// or removed product or category) after it was first loaded.
  Stream<void> get changes;
}
