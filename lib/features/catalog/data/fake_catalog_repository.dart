import '../domain/product.dart';
import 'catalog_repository.dart';

/// In-memory catalogue so the app runs end to end without a backend.
class FakeCatalogRepository implements CatalogRepository {
  static const _latency = Duration(milliseconds: 350);

  static const categories = <Category>[
    Category(id: 'fruits', name: 'Fruits & Veg', icon: 'fruits'),
    Category(id: 'dairy', name: 'Dairy & Eggs', icon: 'dairy'),
    Category(id: 'staples', name: 'Atta, Rice & Dal', icon: 'staples'),
    Category(id: 'snacks', name: 'Snacks', icon: 'snacks'),
    Category(id: 'beverages', name: 'Beverages', icon: 'beverages'),
    Category(id: 'household', name: 'Household', icon: 'household'),
  ];

  static const products = <Product>[
    Product(id: 'p01', emoji: '🍌', name: 'Banana Robusta', categoryId: 'fruits', unit: '6 pcs', pricePaise: 4200, mrpPaise: 5000, description: 'Fresh, naturally ripened Robusta bananas sourced daily.', storeStock: {'store-hsr': (inStock: true, stockQty: 0)}),
    Product(id: 'p02', emoji: '🍅', name: 'Tomato Local', categoryId: 'fruits', unit: '500 g', pricePaise: 1800, mrpPaise: 2400, description: 'Firm, juicy local tomatoes. Great for curries and salads.'),
    Product(id: 'p03', emoji: '🧅', name: 'Onion', categoryId: 'fruits', unit: '1 kg', pricePaise: 3500, mrpPaise: 4500, description: 'Medium-size red onions, hand sorted.'),
    Product(id: 'p04', emoji: '🍎', name: 'Apple Shimla', categoryId: 'fruits', unit: '4 pcs', pricePaise: 12900, mrpPaise: 16000, subtitle: 'Hand-picked from Himachal orchards', description: 'Crisp and sweet Shimla apples.', stockQty: 8),
    Product(id: 'p05', emoji: '🥛', name: 'Toned Milk', categoryId: 'dairy', unit: '500 ml', pricePaise: 2700, mrpPaise: 2700, description: 'Pasteurised toned milk pouch.'),
    Product(id: 'p06', emoji: '🥣', name: 'Fresh Curd', categoryId: 'dairy', unit: '400 g', pricePaise: 3500, mrpPaise: 4000, description: 'Thick, creamy curd set fresh.'),
    Product(id: 'p07', emoji: '🥚', name: 'Farm Eggs', categoryId: 'dairy', unit: '6 pcs', pricePaise: 4800, mrpPaise: 5400, description: 'Farm fresh white eggs.'),
    Product(id: 'p08', emoji: '🧈', name: 'Salted Butter', categoryId: 'dairy', unit: '100 g', pricePaise: 5800, mrpPaise: 6000, description: 'Creamy salted table butter.', inStock: false),
    Product(id: 'p09', emoji: '🌾', name: 'Chakki Atta', categoryId: 'staples', unit: '5 kg', pricePaise: 23900, mrpPaise: 28500, description: '100% whole wheat chakki-ground atta.', shipsAllIndia: true),
    Product(id: 'p10', emoji: '🍚', name: 'Sona Masoori Rice', categoryId: 'staples', unit: '5 kg', pricePaise: 34900, mrpPaise: 42000, description: 'Aged Sona Masoori rice for everyday meals.'),
    Product(id: 'p11', emoji: '🫘', name: 'Toor Dal', categoryId: 'staples', unit: '1 kg', pricePaise: 15900, mrpPaise: 18500, description: 'Unpolished toor dal, rich in protein.'),
    Product(id: 'p12', emoji: '🌻', name: 'Sunflower Oil', categoryId: 'staples', unit: '1 L', pricePaise: 13900, mrpPaise: 16500, description: 'Refined sunflower oil pouch.'),
    Product(id: 'p13', emoji: '🥔', name: 'Potato Chips', categoryId: 'snacks', unit: '90 g', pricePaise: 3000, mrpPaise: 3500, description: 'Classic salted potato chips.'),
    Product(id: 'p14', emoji: '🍪', name: 'Marie Biscuits', categoryId: 'snacks', unit: '250 g', pricePaise: 3500, mrpPaise: 4000, description: 'Light, crisp tea-time biscuits.', shipsAllIndia: true),
    Product(id: 'p15', emoji: '🥜', name: 'Masala Peanuts', categoryId: 'snacks', unit: '200 g', pricePaise: 5500, mrpPaise: 6500, description: 'Crunchy spiced peanuts.', shipsAllIndia: true),
    Product(id: 'p16', emoji: '🍵', name: 'Assam Tea', categoryId: 'beverages', unit: '250 g', pricePaise: 12500, mrpPaise: 14500, description: 'Strong Assam CTC tea.', shipsAllIndia: true),
    Product(id: 'p17', emoji: '☕', name: 'Filter Coffee', categoryId: 'beverages', unit: '200 g', pricePaise: 14900, mrpPaise: 17000, description: 'South Indian filter coffee blend, 80:20.', shipsAllIndia: true),
    Product(id: 'p18', emoji: '🍊', name: 'Orange Juice', categoryId: 'beverages', unit: '1 L', pricePaise: 9900, mrpPaise: 12000, description: 'No added sugar orange juice.'),
    Product(id: 'p19', emoji: '🧴', name: 'Dishwash Liquid', categoryId: 'household', unit: '500 ml', pricePaise: 9900, mrpPaise: 11500, description: 'Lemon dishwash liquid, tough on grease.'),
    Product(id: 'p20', emoji: '🧺', name: 'Detergent Powder', categoryId: 'household', unit: '1 kg', pricePaise: 11900, mrpPaise: 14000, description: 'Front and top load detergent powder.'),
  ];

  @override
  Future<List<Category>> fetchCategories() async {
    await Future<void>.delayed(_latency);
    return categories;
  }

  @override
  Future<List<Product>> fetchProducts({String? categoryId, String? query}) async {
    await Future<void>.delayed(_latency);
    final q = query?.trim().toLowerCase() ?? '';
    return products.where((p) {
      if (categoryId != null && p.categoryId != categoryId) return false;
      if (q.isNotEmpty && !p.name.toLowerCase().contains(q)) return false;
      return true;
    }).toList(growable: false);
  }

  @override
  Future<Product?> fetchProduct(String id) async {
    await Future<void>.delayed(_latency);
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }
}
