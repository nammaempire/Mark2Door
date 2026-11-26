import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../service_area/application/pincode_controller.dart';
import '../domain/product.dart';

typedef ProductQuery = ({String? categoryId, String query});

/// Counts the store's changes to the catalogue. The lists below watch
/// it, so a new price, stock level or product shows without the shopper
/// doing anything.
final catalogVersionProvider = StreamProvider<int>((ref) {
  var version = 0;
  return ref.watch(catalogRepositoryProvider).changes.map((_) => ++version);
});

final categoriesProvider = FutureProvider<List<Category>>((ref) {
  ref.watch(catalogVersionProvider);
  return ref.watch(catalogRepositoryProvider).fetchCategories();
});

final productsProvider =
    FutureProvider.autoDispose.family<List<Product>, ProductQuery>(
  (ref, q) async {
    // The Outstation tab only offers what the store sends by courier.
    final outstation = ref.watch(shopModeProvider) == ShopMode.outstation;
    ref.watch(catalogVersionProvider);
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
    ref.watch(catalogVersionProvider);
    final repo = ref.watch(catalogRepositoryProvider);
    // From the catalogue already on the phone; read from the server only
    // for a product that is not in it.
    final product =
        (await repo.fetchProducts()).where((p) => p.id == id).firstOrNull ??
            await repo.fetchProduct(id);
    final storeId = await ref.watch(storeIdProvider.future);
    return product?.forStore(storeId);
  },
);
