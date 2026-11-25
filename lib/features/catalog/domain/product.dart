import 'package:flutter/foundation.dart';

@immutable
class Category {
  const Category({
    required this.id,
    required this.name,
    this.icon = 'basket',
    this.imageUrl = '',
  });

  final String id;
  final String name;

  /// Older categories were given a drawn icon by this key. It is still
  /// used for the tile's background colour, and for the picture itself
  /// when a category has no image yet.
  final String icon;

  /// Picture for the category tile, linked or uploaded in the admin web.
  final String imageUrl;

  factory Category.fromMap(String id, Map<String, dynamic> map) => Category(
        id: id,
        name: map['name'] as String? ?? '',
        icon: map['icon'] as String? ?? 'basket',
        imageUrl: map['imageUrl'] as String? ?? '',
      );

  Map<String, dynamic> toMap() =>
      {'name': name, 'icon': icon, 'imageUrl': imageUrl};
}

@immutable
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.unit,
    required this.pricePaise,
    required this.mrpPaise,
    this.imageUrls = const [],
    this.emoji = '',
    this.subtitle = '',
    this.description = '',
    bool inStock = true,
    this.stockQty,
    this.shipsAllIndia = false,
    this.storeStock = const {},
  }) : available = inStock;

  final String id;
  final String name;
  final String categoryId;

  /// Pack size shown to the shopper, e.g. "500 g".
  final String unit;
  final int pricePaise;
  final int mrpPaise;

  /// Up to [maxImages] photos added in the admin web; the first is the
  /// main photo used in lists.
  final List<String> imageUrls;

  /// Optional artwork shown until a photo is uploaded, e.g. "🍌".
  final String emoji;

  /// Short line under the name on the product page, e.g. "Fresh from Ooty".
  final String subtitle;
  final String description;

  /// The admin's "In stock" switch.
  final bool available;

  /// Units the store has left. Null when the admin does not count stock
  /// for this product, which means there is no stock limit.
  final int? stockQty;

  /// The admin's "Deliver all over India" switch: sent by courier to
  /// pincodes outside the instant delivery area.
  final bool shipsAllIndia;

  /// Stock each store keeps for itself, by store id; see [forStore].
  final Map<String, ({bool inStock, int? stockQty})> storeStock;

  /// Can be ordered: switched on by the admin and not counted down to zero.
  bool get inStock => available && (stockQty == null || stockQty! > 0);

  /// The most one order may contain, given a per-order [cap].
  int maxPerOrder(int cap) {
    final left = stockQty;
    if (!inStock) return 0;
    return left == null || left > cap ? cap : left;
  }

  static const maxImages = 5;

  /// Main photo, or empty when the product only has artwork.
  String get imageUrl => imageUrls.isEmpty ? '' : imageUrls.first;

  int get discountPercent => mrpPaise <= pricePaise
      ? 0
      : (((mrpPaise - pricePaise) * 100) / mrpPaise).round();

  factory Product.fromMap(String id, Map<String, dynamic> map) => Product(
        id: id,
        name: map['name'] as String? ?? '',
        categoryId: map['categoryId'] as String? ?? '',
        unit: map['unit'] as String? ?? '',
        pricePaise: (map['pricePaise'] as num?)?.toInt() ?? 0,
        mrpPaise: (map['mrpPaise'] as num?)?.toInt() ?? 0,
        imageUrls: _readImages(map),
        emoji: map['emoji'] as String? ?? '',
        subtitle: map['subtitle'] as String? ?? '',
        description: map['description'] as String? ?? '',
        inStock: map['inStock'] as bool? ?? true,
        stockQty: (map['stockQty'] as num?)?.toInt(),
        shipsAllIndia: map['allIndia'] as bool? ?? false,
        storeStock: {
          for (final e in (map['storeStock'] as Map? ?? const {}).entries)
            if (e.value is Map)
              e.key as String: (
                inStock: (e.value as Map)['inStock'] as bool? ?? true,
                stockQty: ((e.value as Map)['stockQty'] as num?)?.toInt(),
              ),
        },
      );

  /// This product as the store [storeId] has it. A business with several
  /// stores keeps stock per store, so the same product can be available
  /// from one store and sold out at another. A store with no entry of its
  /// own, and a business with one shop ([storeId] null), use the
  /// product's own stock.
  Product forStore(String? storeId) {
    final own = storeStock[storeId];
    if (own == null) return this;
    return Product(
      id: id,
      name: name,
      categoryId: categoryId,
      unit: unit,
      pricePaise: pricePaise,
      mrpPaise: mrpPaise,
      imageUrls: imageUrls,
      emoji: emoji,
      subtitle: subtitle,
      description: description,
      inStock: own.inStock,
      stockQty: own.stockQty,
      shipsAllIndia: shipsAllIndia,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'nameLower': name.toLowerCase(),
        'categoryId': categoryId,
        'unit': unit,
        'pricePaise': pricePaise,
        'mrpPaise': mrpPaise,
        'imageUrl': imageUrl,
        'imageUrls': imageUrls,
        'emoji': emoji,
        'subtitle': subtitle,
        'description': description,
        'inStock': available,
        'stockQty': stockQty,
        'allIndia': shipsAllIndia,
      };

  @override
  bool operator ==(Object other) => other is Product && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Reads `imageUrls`, falling back to the single `imageUrl` of products
/// saved before several photos were supported.
List<String> _readImages(Map<String, dynamic> map) {
  final list = [
    for (final e in (map['imageUrls'] as List?) ?? const [])
      if (e is String && e.trim().isNotEmpty) e.trim(),
  ];
  if (list.isEmpty) {
    final single = (map['imageUrl'] as String? ?? '').trim();
    if (single.isNotEmpty) list.add(single);
  }
  return List.unmodifiable(list.take(Product.maxImages));
}
