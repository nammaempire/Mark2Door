import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mart2door/app.dart';
import 'package:mart2door/core/config/env.dart';
import 'package:mart2door/core/location/location_service.dart';
import 'package:mart2door/core/network/network_status.dart';
import 'package:mart2door/core/providers.dart';
import 'package:mart2door/core/router/app_router.dart';
import 'package:mart2door/core/storage/local_store.dart';
import 'package:mart2door/features/cart/application/cart_controller.dart';
import 'package:mart2door/features/catalog/domain/product.dart';
import 'package:mart2door/features/checkout/data/coupon_repository.dart';
import 'package:mart2door/features/insights/demand_log.dart';
import 'package:mart2door/features/checkout/domain/address.dart';
import 'package:mart2door/features/checkout/domain/coupon.dart';
import 'package:mart2door/features/checkout/presentation/order_result_screen.dart';
import 'package:mart2door/features/orders/data/fake_order_repository.dart';
import 'package:mart2door/features/orders/domain/order.dart';
import 'package:mart2door/features/orders/presentation/live_order_card.dart';
import 'package:mart2door/features/orders/presentation/order_detail_screen.dart';
import 'package:mart2door/features/support/presentation/legal_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stock limit, subtitle, coupons, cancelling, the live order card and the
/// legal links on the login page.

const _uid = 'demo-+919876543210';

const _address = Address(
  name: 'Navi',
  phone: '9876543210',
  line1: '12, 4th Cross',
  landmark: '',
  pincode: '560034',
);

const _signedIn = <String, Object>{
  LocalStore.demoSessionKey: '+919876543210',
  LocalStore.pincodeKey: '560034',
};

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = _signedIn,
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

final _homeScroll = find
    .descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    )
    .first;

Finder _key(String key) => find.byKey(ValueKey(key));

/// Adds one banana (₹42) from the home page and opens checkout with the
/// address filled in.
Future<void> _openCheckoutWithBanana(WidgetTester tester) async {
  await tester.scrollUntilVisible(_key('add-p01'), 300,
      scrollable: _homeScroll);
  await tester.ensureVisible(_key('add-p01'));
  await tester.pumpAndSettle();
  await tester.tap(_key('add-p01'));
  await tester.pumpAndSettle();
  await tester.tap(_key('cart-bar'));
  await tester.pumpAndSettle();
  await tester.tap(_key('checkout-button'));
  await tester.pumpAndSettle();
  await tester.enterText(_key('name-field'), 'Navi');
  await tester.enterText(_key('line1-field'), '12, 4th Cross');
}

Future<void> _scrollTo(WidgetTester tester, Finder finder, [double by = 200]) =>
    tester.scrollUntilVisible(
      finder,
      by,
      scrollable: find.byType(Scrollable).first,
    );

/// Picks cash on delivery, places the order and waits for the result page.
Future<void> _placeCodOrder(WidgetTester tester) async {
  await _scrollTo(tester, _key('method-cod'), -200);
  await tester.ensureVisible(_key('method-cod'));
  await tester.pumpAndSettle();
  await tester.tap(_key('method-cod'));
  await tester.pumpAndSettle();
  await tester.tap(_key('place-order-button'));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  expect(find.byType(OrderResultScreen), findsOneWidget);
}

Future<Order> _onlyOrder(ProviderContainer container) async =>
    (await container.read(orderRepositoryProvider).watchOrders(_uid).first)
        .single;

class _SwitchableProbe implements NetworkProbe {
  _SwitchableProbe({required this.online});

  bool online;

  @override
  Future<bool> reachable() async => online;
}

void main() {
  group('stock limit', () {
    const apple = Product(
      id: 'apple',
      name: 'Apple',
      categoryId: 'fruits',
      unit: '4 pcs',
      pricePaise: 12900,
      mrpPaise: 16000,
      stockQty: 8,
    );

    test('an order can hold no more than the stock, or ten', () {
      expect(apple.maxPerOrder(10), 8);
      expect(apple.inStock, isTrue);

      const plenty = Product(
        id: 'p',
        name: 'P',
        categoryId: 'x',
        unit: '',
        pricePaise: 1,
        mrpPaise: 1,
        stockQty: 40,
      );
      expect(plenty.maxPerOrder(10), 10);

      // No count kept by the admin means no stock limit.
      const uncounted = Product(
        id: 'u',
        name: 'U',
        categoryId: 'x',
        unit: '',
        pricePaise: 1,
        mrpPaise: 1,
      );
      expect(uncounted.maxPerOrder(10), 10);

      // Counted down to nothing is out of stock, whatever the switch says.
      const none = Product(
        id: 'n',
        name: 'N',
        categoryId: 'x',
        unit: '',
        pricePaise: 1,
        mrpPaise: 1,
        stockQty: 0,
      );
      expect(none.inStock, isFalse);
      expect(none.maxPerOrder(10), 0);
    });

    test('stock and subtitle survive saving and loading', () {
      final back = Product.fromMap('apple', {
        ...apple.toMap(),
        'subtitle': 'Fresh from Ooty',
      });
      expect(back.stockQty, 8);
      expect(back.subtitle, 'Fresh from Ooty');
      expect(Product.fromMap('x', const {}).stockQty, isNull);
    });

    test('the cart refuses the ninth apple and says why', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final cart = container.read(cartProvider.notifier);

      for (var i = 0; i < 8; i++) {
        expect(cart.add(apple), isNull);
      }
      expect(
        cart.add(apple),
        'Only 8 left in stock. You cannot add more.',
      );
      expect(container.read(cartProvider).quantityOf('apple'), 8);
    });

    test('with enough stock the limit is ten per order', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final cart = container.read(cartProvider.notifier);
      const milk = Product(
        id: 'milk',
        name: 'Milk',
        categoryId: 'dairy',
        unit: '500 ml',
        pricePaise: 2700,
        mrpPaise: 3000,
      );
      for (var i = 0; i < AppConfig.maxQtyPerItem; i++) {
        expect(cart.add(milk), isNull);
      }
      expect(cart.add(milk), 'You can add up to 10 of one item per order.');
    });

    testWidgets('product page shows the subtitle and stops at the stock', (
      tester,
    ) async {
      final container = await _pumpApp(tester);
      container.read(routerProvider).push(Routes.product('p04'));
      await tester.pumpAndSettle();

      expect(_key('product-subtitle'), findsOneWidget);
      expect(find.text('Hand-picked from Himachal orchards'), findsOneWidget);
      expect(find.text('Only 8 left in stock'), findsOneWidget);

      await tester.tap(_key('detail-p04'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.byTooltip('Add one').last);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(container.read(cartProvider).quantityOf('p04'), 8);
      expect(
        find.text('Only 8 left in stock. You cannot add more.'),
        findsOneWidget,
      );
    });
  });

  group('coupons', () {
    final now = DateTime(2026, 11, 21);

    test('percent coupons stop at their maximum discount', () {
      const c = Coupon(
        code: 'SAVE10',
        type: CouponType.percent,
        value: 10,
        maxDiscountPaise: 10000,
      );
      expect(c.discountFor(4200), 420);
      expect(c.discountFor(250000), 10000);
      expect(c.label, '10% off');
      expect(c.problemFor(4200, now), isNull);
    });

    test('flat coupons never take off more than the items cost', () {
      const c = Coupon(
        code: 'FLAT50',
        type: CouponType.flat,
        value: 5000,
        minOrderPaise: 19900,
      );
      expect(c.discountFor(20000), 5000);
      expect(c.discountFor(3000), 3000);
      expect(c.label, '₹50 off');
      expect(
        c.problemFor(4200, now),
        'Add items worth ₹157 more to use this coupon.',
      );
    });

    test('expired and switched-off coupons are refused', () {
      final old = Coupon(
        code: 'OLD',
        type: CouponType.percent,
        value: 20,
        expiresAt: DateTime(2026, 11, 20, 23, 59, 59),
      );
      expect(old.problemFor(50000, now), 'This coupon has expired.');
      const off = Coupon(
        code: 'OFF',
        type: CouponType.flat,
        value: 100,
        active: false,
      );
      expect(off.problemFor(50000, now), 'This coupon is no longer active.');
    });

    test('codes are read from the database as saved by the admin', () {
      final c = Coupon.fromMap('WELCOME50', const {
        'type': 'flat',
        'value': 5000,
        'minOrderPaise': 19900,
        'oncePerCustomer': true,
        'expiresAt': 1795000000000,
      });
      expect(c.type, CouponType.flat);
      expect(c.oncePerCustomer, isTrue);
      expect(c.expiresAt, isNotNull);
      expect(Coupon.normalise('  save10 '), 'SAVE10');
    });

    testWidgets('a wrong code is refused and a right one cuts the bill', (
      tester,
    ) async {
      final container = await _pumpApp(tester);
      await _openCheckoutWithBanana(tester);

      await _scrollTo(tester, _key('coupon-field'));
      await tester.enterText(_key('coupon-field'), 'nope');
      await tester.tap(_key('apply-coupon-button'));
      await tester.pumpAndSettle();
      expect(find.text('This coupon code is not valid.'), findsOneWidget);

      // Typed in lower case; codes are matched in upper case.
      await tester.enterText(_key('coupon-field'), 'save10');
      await tester.tap(_key('apply-coupon-button'));
      await tester.pumpAndSettle();
      expect(_key('coupon-applied'), findsOneWidget);
      expect(find.text('SAVE10 applied'), findsOneWidget);
      expect(find.text('You save ₹4.20 (10% off)'), findsOneWidget);

      await _scrollTo(tester, _key('coupon-row'));
      expect(find.text('Coupon (SAVE10)'), findsOneWidget);
      expect(find.text('- ₹4.20'), findsOneWidget);
      // 42 + 30 delivery - 4.20 coupon.
      expect(find.textContaining('₹67.80'), findsWidgets);

      await _placeCodOrder(tester);
      final order = await _onlyOrder(container);
      expect(order.couponCode, 'SAVE10');
      expect(order.couponDiscountPaise, 420);
      expect(order.totalPaise, 6780);
      final saved = Order.fromMap(order.id, order.toMap());
      expect(saved.couponCode, 'SAVE10');
      expect(saved.couponDiscountPaise, 420);
    });

    testWidgets('a coupon can be removed again', (tester) async {
      await _pumpApp(tester);
      await _openCheckoutWithBanana(tester);
      await _scrollTo(tester, _key('coupon-field'));
      await tester.enterText(_key('coupon-field'), 'SAVE10');
      await tester.tap(_key('apply-coupon-button'));
      await tester.pumpAndSettle();
      await tester.tap(_key('remove-coupon-button'));
      await tester.pumpAndSettle();
      expect(_key('coupon-field'), findsOneWidget);
      expect(_key('coupon-row'), findsNothing);
    });

    testWidgets('a coupon with a minimum says how much more to add', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _openCheckoutWithBanana(tester);
      await _scrollTo(tester, _key('coupon-field'));
      await tester.enterText(_key('coupon-field'), 'WELCOME50');
      await tester.tap(_key('apply-coupon-button'));
      await tester.pumpAndSettle();
      expect(
        find.text('Add items worth ₹157 more to use this coupon.'),
        findsOneWidget,
      );
      expect(_key('coupon-applied'), findsNothing);
    });

    test('a once-only code is used up by an order and freed by cancelling',
        () async {
      final coupons = FakeCouponRepository();
      final orders = FakeOrderRepository(coupons: coupons);
      final order = await orders.create(
        Order(
          id: '',
          userId: _uid,
          items: const [],
          subtotalPaise: 30000,
          deliveryFeePaise: 0,
          totalPaise: 25000,
          couponCode: 'WELCOME50',
          couponDiscountPaise: 5000,
          address: _address,
          paymentMethod: PaymentMethod.cod,
          paymentStatus: PaymentStatus.pending,
          status: OrderStatus.placed,
          createdAt: DateTime(2026, 11, 21),
        ),
        recordCouponUse: true,
      );
      expect(await coupons.alreadyUsed('WELCOME50', _uid), isTrue);
      await orders.cancel(order.id);
      expect(await coupons.alreadyUsed('WELCOME50', _uid), isFalse);
    });
  });

  group('cancel order', () {
    test('allowed until the order is picked up', () {
      Order at(OrderStatus status) => Order(
            id: 'o1',
            userId: _uid,
            items: const [],
            subtotalPaise: 4200,
            deliveryFeePaise: 3000,
            totalPaise: 7200,
            address: _address,
            paymentMethod: PaymentMethod.cod,
            paymentStatus: PaymentStatus.pending,
            status: status,
            createdAt: DateTime(2026, 11, 21),
          );
      expect(at(OrderStatus.placed).canCancel, isTrue);
      expect(at(OrderStatus.accepted).canCancel, isTrue);
      expect(at(OrderStatus.pickedUp).canCancel, isFalse);
      expect(at(OrderStatus.delivered).canCancel, isFalse);
      expect(at(OrderStatus.cancelled).canCancel, isFalse);
    });

    testWidgets('the shopper cancels from the order page', (tester) async {
      final container = await _pumpApp(tester);
      await _openCheckoutWithBanana(tester);
      await _placeCodOrder(tester);

      await tester.tap(_key('track-button'));
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailScreen), findsOneWidget);
      expect(_key('order-status-card'), findsOneWidget);

      await tester.scrollUntilVisible(
        _key('cancel-order-button'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(_key('cancel-order-button'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel this order?'), findsOneWidget);
      await tester.tap(_key('confirm-cancel-button'));
      await tester.pumpAndSettle();

      final order = await _onlyOrder(container);
      expect(order.status, OrderStatus.cancelled);
      expect(order.cancelledBy, 'customer');
      expect(_key('cancel-order-button'), findsNothing);
      expect(_key('order-status-card'), findsNothing);
    });

    testWidgets('no cancel button once the order has left the store', (
      tester,
    ) async {
      final container = await _pumpApp(tester);
      await _openCheckoutWithBanana(tester);
      await _placeCodOrder(tester);
      final order = await _onlyOrder(container);
      (container.read(orderRepositoryProvider) as FakeOrderRepository)
          .advance(order.id, OrderStatus.pickedUp, riderName: 'Suresh');

      await tester.tap(_key('track-button'));
      await tester.pumpAndSettle();
      expect(find.text('Out for delivery'), findsWidgets);
      expect(find.text('Suresh is on the way to you.'), findsOneWidget);
      await tester.drag(
        find.byType(Scrollable).last,
        const Offset(0, -3000),
      );
      await tester.pumpAndSettle();
      expect(_key('cancel-order-button'), findsNothing);
    });
  });

  group('live order card', () {
    Order order(OrderStatus status, {String? rider}) => Order(
          id: 'o1',
          userId: _uid,
          items: const [],
          subtotalPaise: 4200,
          deliveryFeePaise: 3000,
          totalPaise: 7200,
          address: _address,
          paymentMethod: PaymentMethod.cod,
          paymentStatus: PaymentStatus.pending,
          status: status,
          createdAt: DateTime(2026, 11, 21),
          riderName: rider,
        );

    test('follows the order from placed to delivered', () {
      expect(OrderStage.of(order(OrderStatus.placed)), OrderStage.placed);
      expect(
        OrderStage.of(order(OrderStatus.placed, rider: 'Suresh')),
        OrderStage.assigned,
      );
      expect(
        OrderStageView.of(order(OrderStatus.placed, rider: 'Suresh')).headline,
        'Delivery partner assigned',
      );
      expect(
        OrderStageView.of(order(OrderStatus.accepted, rider: 'Suresh')).detail,
        'Suresh is collecting your order from the store.',
      );
      expect(OrderStage.of(order(OrderStatus.pickedUp)), OrderStage.onTheWay);
      expect(OrderStage.of(order(OrderStatus.delivered)), OrderStage.delivered);
      expect(order(OrderStatus.placed).isActive, isTrue);
      expect(order(OrderStatus.delivered).isActive, isFalse);
      expect(order(OrderStatus.cancelled).isActive, isFalse);
    });

    testWidgets('shows on the home page until the order is delivered', (
      tester,
    ) async {
      final container = await _pumpApp(tester);
      expect(_key('home-live-order'), findsNothing);

      await _openCheckoutWithBanana(tester);
      await _placeCodOrder(tester);
      // The "order placed" page shows the same live card.
      expect(_key('result-status-card'), findsOneWidget);
      expect(find.text('Order placed'), findsOneWidget);

      await tester.tap(find.text('Continue shopping'));
      await tester.pumpAndSettle();
      await tester.drag(_homeScroll, const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(_key('home-live-order'), findsOneWidget);
      expect(find.text('Order placed'), findsOneWidget);
      expect(find.textContaining('Arriving in'), findsOneWidget);

      final repo =
          container.read(orderRepositoryProvider) as FakeOrderRepository;
      final placed = await _onlyOrder(container);
      repo.advance(placed.id, OrderStatus.pickedUp, riderName: 'Suresh');
      await tester.pumpAndSettle();
      expect(find.text('Out for delivery'), findsOneWidget);

      repo.deliver(placed.id, riderName: 'Suresh');
      await tester.pumpAndSettle();
      expect(_key('home-live-order'), findsNothing);
    });
  });

  group('map pin for the address', () {
    test('the pin is saved with the address and read back', () {
      const pinned = Address(
        name: 'Navi',
        phone: '9876543210',
        line1: '12, 4th Cross',
        landmark: '',
        pincode: '560034',
        lat: 12.9352,
        lng: 77.6245,
      );
      final back = Address.fromMap(pinned.toMap());
      expect(back.hasPin, isTrue);
      expect(back.lat, 12.9352);
      expect(back.lng, 77.6245);
      // An address without a pin stores no coordinates at all.
      expect(_address.hasPin, isFalse);
      expect(_address.toMap().containsKey('lat'), isFalse);
      // Same text is the same address, pinned or not.
      expect(pinned, _address);
    });

    testWidgets('pinning at checkout puts the spot on the order', (
      tester,
    ) async {
      final container = await _pumpApp(tester);
      await _openCheckoutWithBanana(tester);

      await _scrollTo(tester, _key('pin-location-button'));
      expect(_key('location-pinned'), findsNothing);
      await tester.tap(_key('pin-location-button'));
      await tester.pumpAndSettle();
      expect(_key('location-pinned'), findsOneWidget);

      await _placeCodOrder(tester);
      final order = await _onlyOrder(container);
      expect(order.address.lat, 12.9352);
      expect(order.address.lng, 77.6245);
      // What the delivery app reads from the order.
      final saved = order.toMap()['address'] as Map<String, dynamic>;
      expect(saved['lat'], 12.9352);
      expect(saved['lng'], 77.6245);
    });

    testWidgets('a problem reading the location is explained', (tester) async {
      final container = await _pumpApp(tester);
      (container.read(locationServiceProvider) as FakeLocationService).failure =
          'Turn on location (GPS) on your phone and try again.';
      await _openCheckoutWithBanana(tester);
      await _scrollTo(tester, _key('pin-location-button'));
      await tester.tap(_key('pin-location-button'));
      await tester.pumpAndSettle();
      expect(
        find.text('Turn on location (GPS) on your phone and try again.'),
        findsOneWidget,
      );
      expect(_key('location-pinned'), findsNothing);

      // The order can still be placed without a pin.
      await _placeCodOrder(tester);
      expect((await _onlyOrder(container)).address.hasPin, isFalse);
    });
  });

  group('what customers could not get', () {
    test('searches are tidied into one entry per term', () {
      expect(DemandLog.normalise('  Dragon   FRUIT '), 'dragon fruit');
      expect(DemandLog.keyFor('Dragon  Fruit!'), 'dragon-fruit');
      expect(DemandLog.keyFor('a/b'), 'a-b');
      expect(DemandLog.keyFor('???'), 'other');
      expect(DemandLog.keyFor('x' * 90).length, 60);
    });

    test('each shopper is counted once, and half-typed words not at all',
        () async {
      SharedPreferences.setMockInitialValues({});
      final repo = FakeDemandRepository();
      final log = DemandLog(repo, LocalStore(await SharedPreferences.getInstance()));

      log
        ..pincodeNotServed('110001')
        ..pincodeNotServed('110001')
        ..pincodeNotServed('12') // not a pincode
        ..searchMiss('Paneer', SearchMiss.notFound)
        ..searchMiss(' paneer ', SearchMiss.notFound)
        ..searchMiss('pa', SearchMiss.notFound)
        ..searchMiss('butter', SearchMiss.outOfStock);
      await Future<void>.delayed(Duration.zero);

      expect(repo.pincodes, ['110001']);
      expect(repo.searches, [
        ('paneer', SearchMiss.notFound),
        ('butter', SearchMiss.outOfStock),
      ]);
    });

    testWidgets('a pincode outside the delivery area is recorded', (
      tester,
    ) async {
      final container = await _pumpApp(
        tester,
        prefs: const {
          LocalStore.demoSessionKey: '+919876543210',
          LocalStore.pincodeKey: '110001',
        },
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final repo =
          container.read(demandRepositoryProvider) as FakeDemandRepository;
      expect(repo.pincodes, ['110001']);
    });

    testWidgets('a pincode the store serves is not recorded', (tester) async {
      final container = await _pumpApp(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final repo =
          container.read(demandRepositoryProvider) as FakeDemandRepository;
      expect(repo.pincodes, isEmpty);
    });

    testWidgets('searches that find nothing to buy are recorded', (
      tester,
    ) async {
      final container = await _pumpApp(tester);
      final repo =
          container.read(demandRepositoryProvider) as FakeDemandRepository;

      Future<void> search(String text) async {
        await tester.enterText(_key('search-field'), text);
        // The shopper stops typing; the result is noted a moment later.
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      }

      // Nothing in the catalogue matches.
      await search('dragon fruit');
      expect(find.text('No products found'), findsOneWidget);
      // Matches, but the only match is out of stock.
      await search('butter');
      // Something to buy: not recorded.
      await search('milk');

      expect(repo.searches, [
        ('dragon fruit', SearchMiss.notFound),
        ('butter', SearchMiss.outOfStock),
      ]);
    });
  });

  test('a category carries its picture, and old ones still load', () {
    final withPicture = Category.fromMap('fruits', const {
      'name': 'Fruits',
      'icon': 'fruits',
      'imageUrl': 'https://example.com/fruits.jpg',
    });
    expect(withPicture.imageUrl, 'https://example.com/fruits.jpg');
    expect(withPicture.toMap()['imageUrl'], 'https://example.com/fruits.jpg');
    // Saved before pictures existed: no picture, drawn icon kept.
    final old = Category.fromMap('dairy', const {'name': 'Dairy'});
    expect(old.imageUrl, '');
    expect(old.icon, 'basket');
  });

  group('no internet', () {
    Future<void> pumpWith(WidgetTester tester, _SwitchableProbe probe) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(_signedIn);
      final store = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(store),
            networkProbeProvider.overrideWithValue(probe),
          ],
          child: const Mart2DoorApp(),
        ),
      );
    }

    testWidgets('shimmer first, then "please connect" after three seconds', (
      tester,
    ) async {
      final probe = _SwitchableProbe(online: false);
      await pumpWith(tester, probe);
      await tester.pump(const Duration(milliseconds: 500));

      // Nothing from the store is shown, only the placeholder.
      expect(_key('offline-cover'), findsOneWidget);
      expect(_key('offline-shimmer'), findsOneWidget);
      expect(_key('offline-message'), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      expect(_key('offline-message'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(_key('offline-message'), findsOneWidget);
      expect(find.text('No internet connection'), findsOneWidget);
      expect(_key('offline-shimmer'), findsNothing);

      // The network returns: the cover lifts by itself.
      probe.online = true;
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
      expect(_key('offline-cover'), findsNothing);

      // Stop the background checks before the test ends.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('"Try again" checks straight away', (tester) async {
      final probe = _SwitchableProbe(online: false);
      await pumpWith(tester, probe);
      await tester.pump(const Duration(seconds: 4));
      expect(_key('offline-message'), findsOneWidget);

      probe.online = true;
      await tester.tap(_key('offline-retry-button'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_key('offline-cover'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a connected phone never sees the cover', (tester) async {
      await pumpWith(tester, _SwitchableProbe(online: true));
      await tester.pump(const Duration(seconds: 4));
      expect(_key('offline-cover'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  testWidgets('login page links open the terms and the privacy policy', (
    tester,
  ) async {
    await _pumpApp(tester, prefs: const {});
    await tester.ensureVisible(_key('login-terms-link'));
    await tester.pumpAndSettle();
    await tester.tap(_key('login-terms-link'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalScreen), findsOneWidget);
    expect(find.text('Terms and conditions'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(_key('login-privacy-link'));
    await tester.pumpAndSettle();
    await tester.tap(_key('login-privacy-link'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalScreen), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
  });
}
