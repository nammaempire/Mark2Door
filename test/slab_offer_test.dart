import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mart2door/app.dart';
import 'package:mart2door/core/providers.dart';
import 'package:mart2door/core/router/app_router.dart';
import 'package:mart2door/core/storage/local_store.dart';
import 'package:mart2door/features/cart/application/cart_controller.dart';
import 'package:mart2door/features/cart/domain/cart.dart';
import 'package:mart2door/features/catalog/data/fake_catalog_repository.dart';
import 'package:mart2door/features/catalog/domain/product.dart';
import 'package:mart2door/features/checkout/presentation/order_result_screen.dart';
import 'package:mart2door/features/offers/slab_offers.dart';
import 'package:mart2door/features/orders/domain/order.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _signedIn = <String, Object>{
  LocalStore.demoSessionKey: '+919876543210',
  LocalStore.pincodeKey: '560034',
};

Finder _key(String k) => find.byKey(ValueKey(k));

// Order above ₹299: pick Banana or Toned Milk for ₹9.
const _offer = SlabOffer(
  id: 'o1',
  minOrderPaise: 29900,
  offerPricePaise: 900,
  productIds: ['p01', 'p05'],
);

Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  FakeSlabOfferRepository offers,
) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(_signedIn);
  final store = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(store),
        slabOfferRepositoryProvider.overrideWithValue(offers),
      ],
      child: const Mart2DoorApp(),
    ),
  );
  await tester.pump(const Duration(seconds: 3)); // splash
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Mart2DoorApp)));
}

void main() {
  final apple = FakeCatalogRepository.products[3]; // ₹129
  final banana = FakeCatalogRepository.products[0]; // ₹42

  test('the offer product is priced apart and does not earn the offer', () {
    final cart = Cart(
      {apple.id: CartItem(product: apple, quantity: 3)},
      const Cart().fees,
      false,
      CartOffer(
        offerId: 'o1',
        minOrderPaise: 29900,
        pricePaise: 900,
        product: banana,
      ),
    );
    expect(cart.itemsSubtotalPaise, 38700);
    expect(cart.subtotalPaise, 38700 + 900);
    expect(cart.totalQuantity, 4);
    // Saved against MRP: apples 3 x (160 - 129), banana 50 - 9.
    expect(cart.savingsPaise, 3 * 3100 + 4100);
    final again = Cart.fromMap(cart.toMap());
    expect(again.offer!.pricePaise, 900);
    expect(again.offer!.product.id, banana.id);
  });

  test('the main In stock switch turns a product off at every store', () {
    // The store's own switch is on and it has 5 units.
    final map = {
      ...banana.toMap(),
      'storeStock': {
        'store-a': {'inStock': true, 'stockQty': 5},
      },
    };
    final on = Product.fromMap(banana.id, {...map, 'inStock': true});
    expect(on.forStore('store-a').inStock, isTrue);
    expect(on.forStore('store-a').stockQty, 5);
    // Switched off for all stores by the admin.
    final off = Product.fromMap(banana.id, {...map, 'inStock': false});
    expect(off.forStore('store-a').inStock, isFalse);
    // A store's own switch still turns it off for that store alone.
    final storeOff = Product.fromMap(banana.id, {
      ...map,
      'inStock': true,
      'storeStock': {
        'store-a': {'inStock': false, 'stockQty': 5},
      },
    });
    expect(storeOff.forStore('store-a').inStock, isFalse);
    expect(storeOff.forStore('store-b').inStock, isTrue);
  });

  testWidgets('cart shows how much to add, then the list; one pick at the '
      'offer price goes on the order', (tester) async {
    final container =
        await _pumpApp(tester, FakeSlabOfferRepository([_offer]));
    final cart = container.read(cartProvider.notifier);
    final router = container.read(routerProvider);

    // ₹258 of apples: ₹41 short.
    cart.setQuantity(apple, 2);
    router.push(Routes.cart);
    await tester.pumpAndSettle();
    // The list is on show but locked: the buttons do nothing.
    expect(_key('offer-hint-o1'), findsOneWidget);
    expect(find.textContaining('Add ₹41 more to unlock'), findsOneWidget);
    expect(_key('offer-list-o1'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(_key('offer-pick-o1-p01')).onPressed,
      isNull,
    );
    expect(find.text('Locked'), findsWidgets);

    // A third apple reaches ₹387: the list opens.
    cart.setQuantity(apple, 3);
    await tester.pumpAndSettle();
    expect(_key('offer-hint-o1'), findsNothing);
    expect(_key('offer-list-o1'), findsOneWidget);
    expect(find.text('Locked'), findsNothing);
    await tester.tap(_key('offer-pick-o1-p01'));
    await tester.pumpAndSettle();
    expect(_key('offer-picked'), findsOneWidget);
    expect(_key('offer-list-o1'), findsNothing);
    expect(container.read(cartProvider).subtotalPaise, 38700 + 900);

    // Dropping below the amount takes the offer product away.
    cart.setQuantity(apple, 2);
    await tester.pumpAndSettle();
    expect(container.read(cartProvider).offer, isNull);
    expect(_key('offer-picked'), findsNothing);
    expect(_key('offer-hint-o1'), findsOneWidget);

    // Back up, pick again, and place the order.
    cart.setQuantity(apple, 3);
    await tester.pumpAndSettle();
    await tester.tap(_key('offer-pick-o1-p05'));
    await tester.pumpAndSettle();
    await tester.tap(_key('checkout-button'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('name-field'), 'Navi');
    await tester.enterText(_key('line1-field'), '12, 4th Cross');
    await tester.ensureVisible(_key('method-cod'));
    await tester.pumpAndSettle();
    await tester.tap(_key('method-cod'));
    await tester.pumpAndSettle();
    await tester.tap(_key('place-order-button'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byType(OrderResultScreen), findsOneWidget);

    final order = (await container
            .read(orderRepositoryProvider)
            .watchOrders('demo-+919876543210')
            .first)
        .first;
    final offerLine = order.items.singleWhere((i) => i.isOffer);
    expect(offerLine.name, 'Toned Milk (Offer)');
    expect(offerLine.pricePaise, 900);
    expect(offerLine.quantity, 1);
    expect(order.subtotalPaise, 38700 + 900);
    expect(OrderItem.fromMap(offerLine.toMap()).isOffer, isTrue);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('an offer the admin changed after it was picked stops the order',
      (tester) async {
    final offers = FakeSlabOfferRepository([_offer]);
    final container = await _pumpApp(tester, offers);
    final cart = container.read(cartProvider.notifier);
    cart.setQuantity(apple, 3);
    expect(cart.pickOffer(_offer, banana), isNull);
    // Switched off by the admin.
    offers.offers.clear();

    container.read(routerProvider).push(Routes.cart);
    await tester.pumpAndSettle();
    await tester.tap(_key('checkout-button'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('name-field'), 'Navi');
    await tester.enterText(_key('line1-field'), '12, 4th Cross');
    await tester.ensureVisible(_key('method-cod'));
    await tester.pumpAndSettle();
    await tester.tap(_key('method-cod'));
    await tester.pumpAndSettle();
    await tester.tap(_key('place-order-button'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(OrderResultScreen), findsNothing);
    expect(find.textContaining('The offer has changed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
