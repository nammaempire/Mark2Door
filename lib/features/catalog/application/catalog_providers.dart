import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../service_area/application/pincode_controller.dart';
import '../domain/product.dart';

typedef ProductQuery = ({String? categoryId, String query});

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(catalogRepositoryProvider).fetchCategories(),
);

final productsProvider =
    FutureProvider.autoDispose.family<List<Product>, ProductQuery>(
  (ref, q) async {
    // The Outstation tab only offers what the store sends by courier.
    final outstation = ref.watch(shopModeProvider) == ShopMode.outstation;
    final found = await ref
        .watch(catalogRepositoryProvider)
        .fetchProducts(categoryId: q.categoryId, query: q.query);
    if (outstation) {
      return found.where((p) => p.shipsAllIndia).toList(growable: false);
    }
    // With several stores, show the stock of the store that serves the
    // shopper's pincode.
    final storeId = await ref.watch(storeIdProvider.future);
    return storeId == null
        ? found
        : found.map((p) => p.forStore(storeId)).toList(growable: false);
  },
);

/// The whole catalogue, unfiltered. Shared by the home sections and the
/// "similar products" rows so they load it once.
const ProductQuery allProductsQuery = (categoryId: null, query: '');

/// In-stock products to suggest next to [basis], best matches first:
/// same category as something in [basis], then the rest. Never repeats a
/// product that is already in [basis].
List<Product> similarProducts(
  List<Product> catalogue,
  Iterable<Product> basis, {
  int limit = 10,
}) {
  final ids = {for (final p in basis) p.id};
  final categories = {for (final p in basis) p.categoryId};
  final candidates = catalogue
      .where((p) => p.inStock && !ids.contains(p.id))
      .toList(growable: false);
  return [
    ...candidates.where((p) => categories.contains(p.categoryId)),
    ...candidates.where((p) => !categories.contains(p.categoryId)),
  ].take(limit).toList(growable: false);
}

final productProvider = FutureProvider.autoDispose.family<Product?, String>(
  (ref, id) async {
    final product =
        await ref.watch(catalogRepositoryProvider).fetchProduct(id);
    final storeId = await ref.watch(storeIdProvider.future);
    return product?.forStore(storeId);
  },
);
