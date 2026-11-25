import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mart2door/app.dart';
import 'package:mart2door/core/providers.dart';
import 'package:mart2door/core/storage/local_store.dart';
import 'package:mart2door/features/service_area/data/service_area_repository.dart';
import 'package:mart2door/features/catalog/application/catalog_providers.dart';
import 'package:mart2door/features/cart/application/cart_controller.dart';
import 'package:mart2door/features/checkout/presentation/order_result_screen.dart';
import 'package:mart2door/features/orders/data/fake_order_repository.dart';
import 'package:mart2door/features/orders/domain/order.dart';
import 'package:mart2door/features/service_area/application/pincode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Signed in, with a pincode the sample store does not deliver to.
const _outOfArea = <String, Object>{
  LocalStore.demoSessionKey: '+919876543210',
  LocalStore.pincodeKey: '600001',
};

const _inArea = <String, Object>{
  LocalStore.demoSessionKey: '+919876543210',
  LocalStore.pincodeKey: '560034',
};

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = _outOfArea,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(store)],
      child: const Mart2DoorApp(),
    ),
  );
  await tester.pump(const Duration(seconds: 3)); // splash
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Mart2DoorApp)));
}

Finder _key(String key) => find.byKey(ValueKey(key));

final _homeScroll = find
    .descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _add(WidgetTester tester, String productId) async {
  final button = _key('add-$productId');
  await tester.scrollUntilVisible(button, 300, scrollable: _homeScroll);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _openCheckout(WidgetTester tester) async {
  await tester.tap(_key('cart-bar'));
  await tester.pumpAndSettle();
  await tester.tap(_key('checkout-button'));
  await tester.pumpAndSettle();
  await tester.enterText(_key('name-field'), 'Amma');
  await tester.enterText(_key('line1-field'), '7, Beach Road');
}

Future<void> _wait(WidgetTester tester, [int seconds = 4]) async {
  for (var i = 0; i < seconds; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> _pickPincode(WidgetTester tester, String label) async {
  await tester.tap(_key('service-pincode-dropdown'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('with several stores, the pincode decides whose stock shows', (
    tester,
  ) async {
    // 560034 is served by the first shop: bananas can be bought.
    var container = await _pumpApp(tester, prefs: _inArea);
    expect(await container.read(storeIdProvider.future), isNull);
    await tester.scrollUntilVisible(_key('add-p01'), 300,
        scrollable: _homeScroll);
    expect(_key('add-p01'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));

    // 560102 is served by the second store, where bananas are sold out
    // but everything else is available.
    container = await _pumpApp(
      tester,
      prefs: const {
        LocalStore.demoSessionKey: '+919876543210',
        LocalStore.pincodeKey: '560102',
      },
    );
    expect(
      await container.read(storeIdProvider.future),
      FakeServiceAreaRepository.secondStoreId,
    );
    final products =
        await container.read(productsProvider(allProductsQuery).future);
    final banana = products.firstWhere((p) => p.id == 'p01');
    expect(banana.inStock, isFalse);
    expect(products.firstWhere((p) => p.id == 'p02').inStock, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(_key('add-p01'), findsNothing);

    // An order from this pincode is recorded against that store.
    await _add(tester, 'p02');
    await _openCheckout(tester);
    await tester.scrollUntilVisible(_key('method-cod'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(_key('method-cod'));
    await tester.pumpAndSettle();
    await tester.tap(_key('method-cod'));
    await tester.pumpAndSettle();
    await tester.tap(_key('place-order-button'));
    await _wait(tester);
    final repo = container.read(orderRepositoryProvider) as FakeOrderRepository;
    final order = (await repo.watchOrders('demo-+919876543210').first).single;
    expect(order.storeId, FakeServiceAreaRepository.secondStoreId);
    expect(order.toMap()['storeId'], FakeServiceAreaRepository.secondStoreId);
  });

  testWidgets('inside the delivery area there are no tabs', (tester) async {
    final container = await _pumpApp(tester, prefs: _inArea);
    expect(_key('shop-tabs'), findsNothing);
    expect(_key('instant-unavailable'), findsNothing);
    expect(container.read(shopModeProvider), ShopMode.instant);
    // The full store, not just what goes by courier.
    await tester.scrollUntilVisible(_key('add-p01'), 300,
        scrollable: _homeScroll);
    expect(_key('add-p01'), findsOneWidget);
  });

  testWidgets(
      'Instant tab: sorry, pick a pincode we serve, then order for a home '
      'there', (tester) async {
    final container = await _pumpApp(tester);
    expect(_key('shop-tabs'), findsOneWidget);
    expect(
      find.text('Sorry, we do not deliver instantly to 600001 yet'),
      findsOneWidget,
    );
    expect(_key('cart-bar'), findsNothing);

    await _pickPincode(tester, '560034 - Koramangala');
    expect(_key('instant-unavailable'), findsNothing);
    expect(find.text('Instant delivery to 560034'), findsOneWidget);
    expect(find.text('Pincode 560034'), findsOneWidget);
    expect(_key('outstation-hero'), findsNothing);
    expect(find.text('Shop by category'), findsOneWidget);

    // The whole store is open, and it is an instant (not courier) cart.
    await _add(tester, 'p01');
    expect(container.read(cartProvider).courier, isFalse);
    await _openCheckout(tester);
    // The pincode picked on the Instant tab is filled in, and checked.
    expect(
      tester
          .widget<TextFormField>(_key('checkout-pincode-field'))
          .controller!
          .text,
      '560034',
    );
    // The phone is in another town: no "use my location", a call instead.
    expect(_key('pin-location-button'), findsNothing);
    expect(_key('receiver-call-note'), findsOneWidget);

    // Cash on delivery is allowed: the family at home can pay.
    await tester.scrollUntilVisible(_key('method-cod'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(_key('method-cod'));
    await tester.pumpAndSettle();
    await tester.tap(_key('method-cod'));
    await tester.pumpAndSettle();
    await tester.tap(_key('place-order-button'));
    await _wait(tester);
    expect(find.byType(OrderResultScreen), findsOneWidget);

    final repo = container.read(orderRepositoryProvider) as FakeOrderRepository;
    final order = (await repo.watchOrders('demo-+919876543210').first).single;
    expect(order.isCourier, isFalse);
    expect(order.address.pincode, '560034');
    expect(order.address.name, 'Amma');
    expect(order.paymentMethod, PaymentMethod.cod);
  });

  testWidgets('"Change" on the Instant tab brings the pincode list back', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _pickPincode(tester, '560102 - HSR Layout');
    expect(find.text('Instant delivery to 560102'), findsOneWidget);
    await tester.tap(_key('change-instant-pincode'));
    await tester.pumpAndSettle();
    expect(_key('instant-unavailable'), findsOneWidget);
    // Let the store's product list finish loading.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
      'Outstation tab: courier products only, courier charge, online '
      'payment only, tracking number', (tester) async {
    final container = await _pumpApp(tester);
    await tester.tap(_key('tab-outstation'));
    await tester.pumpAndSettle();
    expect(find.text('Outstation delivery to 600001'), findsOneWidget);
    // The Outstation page has its own look: a courier banner and one
    // plain list, with none of the instant store's sections.
    expect(_key('outstation-hero'), findsOneWidget);
    expect(find.text('Delivered all\nover India'), findsOneWidget);
    expect(find.text('Shop by category'), findsNothing);
    expect(find.text('Deals of the day'), findsNothing);

    // Assam Tea is sent all over India; bananas are not.
    await _add(tester, 'p16');
    expect(_key('add-p01'), findsNothing);
    final cart = container.read(cartProvider);
    expect(cart.courier, isTrue);
    expect(cart.subtotalPaise, 12500);
    expect(cart.deliveryFeePaise, 6000);
    expect(cart.handlingFeePaise + cart.rainFeePaise, 0);
    expect(cart.totalPaise, 18500);

    await _openCheckout(tester);
    expect(find.text('Pincode 600001'), findsOneWidget);
    expect(_key('pin-location-button'), findsNothing);
    await tester.scrollUntilVisible(_key('courier-hint'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(_key('method-cod'), findsNothing);
    await tester.scrollUntilVisible(find.text('Delivery charge'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Delivery charge'), findsOneWidget);

    await tester.tap(_key('place-order-button'));
    await _wait(tester);
    await tester.tap(_key('simulate-success'));
    await _wait(tester);
    expect(_key('result-success'), findsOneWidget);

    final repo = container.read(orderRepositoryProvider) as FakeOrderRepository;
    var order = (await repo.watchOrders('demo-+919876543210').first).single;
    expect(order.isCourier, isTrue);
    expect(order.courierEta, '3 to 5 days');
    expect(order.etaAt, isNull);
    expect(order.deliveryFeePaise, 6000);
    expect(order.address.pincode, '600001');
    expect(order.paymentMethod, PaymentMethod.online);
    expect(order.toMap()['deliveryType'], 'courier');
    expect(order.canCancel, isTrue);

    // The store packs it, then ships it with a tracking number.
    repo.advance(order.id, OrderStatus.accepted);
    order = (await repo.watchOrders('demo-+919876543210').first).single;
    expect(order.statusLabel, 'Packed');
    expect(order.canCancel, isTrue);
    repo.ship(order.id, courier: 'DTDC', tracking: 'D123456789');
    order = (await repo.watchOrders('demo-+919876543210').first).single;
    expect(order.statusLabel, 'Shipped');
    expect(order.canCancel, isFalse);

    await tester.tap(_key('track-button'));
    await tester.pumpAndSettle();
    expect(find.text('Shipped'), findsWidgets);
    await tester.scrollUntilVisible(_key('courier-tile'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('DTDC'), findsOneWidget);
    expect(find.text('Tracking number D123456789'), findsOneWidget);
    expect(_key('cancel-order-button'), findsNothing);
  });

  testWidgets(
      'checkout: a pincode we do not deliver to switches off paying, a '
      'served one switches it back on', (tester) async {
    final container = await _pumpApp(tester, prefs: _inArea);
    await _add(tester, 'p02');
    await _openCheckout(tester);
    FilledButton button() =>
        tester.widget<FilledButton>(_key('place-order-button'));
    await _wait(tester, 1);
    expect(button().onPressed, isNotNull);
    expect(_key('pincode-not-served'), findsNothing);

    // Change to a pincode outside the delivery area.
    await tester.ensureVisible(_key('checkout-pincode-field'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('checkout-pincode-field'), '600001');
    await _wait(tester, 1);
    await tester.pumpAndSettle();
    expect(_key('pincode-not-served'), findsOneWidget);
    expect(
      find.textContaining('Sorry, we do not deliver to 600001 yet.'),
      findsOneWidget,
    );
    expect(button().onPressed, isNull);
    expect(find.text('We do not deliver to this pincode'), findsOneWidget);

    // Back to one we serve: paying works again, and the order goes there.
    await tester.enterText(_key('checkout-pincode-field'), '560038');
    await _wait(tester, 1);
    await tester.pumpAndSettle();
    expect(_key('pincode-not-served'), findsNothing);
    expect(button().onPressed, isNotNull);
    await tester.scrollUntilVisible(_key('method-cod'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(_key('method-cod'));
    await tester.pumpAndSettle();
    await tester.tap(_key('method-cod'));
    await tester.pumpAndSettle();
    await tester.tap(_key('place-order-button'));
    await _wait(tester);
    final repo = container.read(orderRepositoryProvider) as FakeOrderRepository;
    final order = (await repo.watchOrders('demo-+919876543210').first).single;
    expect(order.address.pincode, '560038');
  });

  testWidgets('each tab keeps its own cart', (tester) async {
    final container = await _pumpApp(tester);
    await tester.tap(_key('tab-outstation'));
    await tester.pumpAndSettle();
    await _add(tester, 'p16');
    expect(container.read(cartProvider).totalQuantity, 1);

    // Instant has nothing in it, and the outstation item stays put.
    await tester.tap(_key('tab-instant'));
    await tester.pumpAndSettle();
    expect(container.read(cartProvider).isEmpty, isTrue);
    await _pickPincode(tester, '560034 - Koramangala');
    await _add(tester, 'p01');
    await _add(tester, 'p02');
    expect(container.read(cartProvider).totalQuantity, 2);
    expect(container.read(cartProvider).courier, isFalse);

    await tester.tap(_key('tab-outstation'));
    await tester.pumpAndSettle();
    final outstation = container.read(cartProvider);
    expect(outstation.courier, isTrue);
    expect(outstation.items.keys, ['p16']);
  });
}
