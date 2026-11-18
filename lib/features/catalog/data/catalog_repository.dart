import '../domain/product.dart';

abstract interface class CatalogRepository {
  Future<List<Category>> fetchCategories();

  /// [categoryId] and [query] are both optional filters.
  Future<List<Product>> fetchProducts({String? categoryId, String? query});

  Future<Product?> fetchProduct(String id);
}
