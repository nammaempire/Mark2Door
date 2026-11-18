import 'package:flutter/foundation.dart';

@immutable
class Category {
  const Category({required this.id, required this.name, required this.icon});

  final String id;
  final String name;

  /// Key resolved to an icon by `CategoryIcon`; lets Firestore stay UI-agnostic.
  final String icon;

  factory Category.fromMap(String id, Map<String, dynamic> map) => Category(
        id: id,
        name: map['name'] as String? ?? '',
        icon: map['icon'] as String? ?? 'basket',
      );

  Map<String, dynamic> toMap() => {'name': name, 'icon': icon};
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
    this.imageUrl = '',
    this.emoji = '',
    this.description = '',
    this.inStock = true,
  });

  final String id;
  final String name;
  final String categoryId;

  /// Pack size shown to the shopper, e.g. "500 g".
  final String unit;
  final int pricePaise;
  final int mrpPaise;
  final String imageUrl;

  /// Optional artwork shown until a photo is uploaded, e.g. "🍌".
  final String emoji;
  final String description;
  final bool inStock;

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
        imageUrl: map['imageUrl'] as String? ?? '',
        emoji: map['emoji'] as String? ?? '',
        description: map['description'] as String? ?? '',
        inStock: map['inStock'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'nameLower': name.toLowerCase(),
        'categoryId': categoryId,
        'unit': unit,
        'pricePaise': pricePaise,
        'mrpPaise': mrpPaise,
        'imageUrl': imageUrl,
        'emoji': emoji,
        'description': description,
        'inStock': inStock,
      };

  @override
  bool operator ==(Object other) => other is Product && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
