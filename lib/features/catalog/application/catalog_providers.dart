import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../domain/product.dart';

typedef ProductQuery = ({String? categoryId, String query});

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(catalogRepositoryProvider).fetchCategories(),
);

final productsProvider =
    FutureProvider.autoDispose.family<List<Product>, ProductQuery>(
  (ref, q) => ref
      .watch(catalogRepositoryProvider)
      .fetchProducts(categoryId: q.categoryId, query: q.query),
);

final productProvider = FutureProvider.autoDispose.family<Product?, String>(
  (ref, id) => ref.watch(catalogRepositoryProvider).fetchProduct(id),
);
