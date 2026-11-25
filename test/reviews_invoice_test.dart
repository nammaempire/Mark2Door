import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mart2door/app.dart';
import 'package:mart2door/core/config/store_settings.dart';
import 'package:mart2door/core/providers.dart';
import 'package:mart2door/core/router/app_router.dart';
import 'package:mart2door/core/storage/local_store.dart';
import 'package:mart2door/features/cart/application/cart_controller.dart';
import 'package:mart2door/features/catalog/data/fake_catalog_repository.dart';
import 'package:mart2door/features/orders/application/invoice.dart';
import 'package:mart2door/features/orders/data/fake_order_repository.dart';
import 'package:mart2door/features/orders/domain/order.dart';
import 'package:mart2door/features/reviews/reviews.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _signedIn = <String, Object>{
  LocalStore.demoSessionKey: '+919876543210',
  LocalStore.pincodeKey: '560034',
  LocalStore.customerNameKey: 'Navi Kumar',
};

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  test('invoice amounts are written with Indian grouping', () {
    expect(invoiceMoney(4200), 'Rs. 42');
    expect(invoiceMoney(123456), 'Rs. 1,234.56');
    expect(invoiceMoney(12345600), 'Rs. 1,23,456');
    expect(invoiceMoney(-5000), '- Rs. 50');
  });

  test('review summary averages the stars', () {
    Review r(String uid, int stars) => Review(
          uid: uid,
          name: uid,
          rating: stars,
          text: '',
          createdAt: DateTime(2026),
        );
    final summary = ReviewSummary([r('a', 5), r('b', 4), r('c', 3)]);
    expect(summary.count, 3);
    expect(summary.average, 4);
    expect(summary.by('b')!.rating, 4);
    expect(summary.by('z'), isNull);
    expect(const ReviewSummary([]).average, 0);
  });

  testWidgets(
      'a delivered item can be reviewed, the review shows on the product, '
      'and the invoice downloads', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(_signedIn);
    final store = await SharedPreferences.getInstance();
    Uint8List? invoice;
    String? invoiceName;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(store),
          invoiceSharerProvider.overrideWithValue((bytes, name) async {
            invoice = bytes;
            invoiceName = name;
          }),
        ],
        child: const Mart2DoorApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(Mart2DoorApp)));
    final router = container.read(routerProvider);

    // Place a cash order for bananas and have it delivered.
    container.read(cartProvider.notifier).add(FakeCatalogRepository.products[0]);
    await tester.pumpAndSettle();
    router.push(Routes.checkout);
    await tester.pumpAndSettle();
    await tester.enterText(_key('line1-field'), '12, 4th Cross');
    await tester.scrollUntilVisible(_key('method-cod'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(_key('method-cod'));
    await tester.pumpAndSettle();
    await tester.tap(_key('method-cod'));
    await tester.pumpAndSettle();
    await tester.tap(_key('place-order-button'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    final repo = container.read(orderRepositoryProvider) as FakeOrderRepository;
    final order = (await repo.watchOrders('demo-+919876543210').first).single;

    // Not delivered yet: nothing to review.
    await tester.tap(_key('track-button'));
    await tester.pumpAndSettle();
    expect(_key('review-p01'), findsNothing);

    repo.deliver(order.id, riderName: 'Suresh');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(_key('review-p01'), 200,
        scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(_key('review-p01'));
    await tester.pumpAndSettle();
    await tester.tap(_key('review-p01'));
    await tester.pumpAndSettle();

    // Stars are required.
    await tester.tap(_key('review-submit'));
    await tester.pumpAndSettle();
    expect(_key('review-error'), findsOneWidget);
    await tester.tap(_key('review-star-4'));
    await tester.enterText(_key('review-text'), 'Sweet and fresh');
    await tester.tap(_key('review-submit'));
    await tester.pumpAndSettle();
    expect(find.text('Thanks. Your review is posted.'), findsOneWidget);

    final reviews =
        await container.read(reviewRepositoryProvider).fetch('p01');
    final mine = reviews.firstWhere((r) => r.uid == 'demo-+919876543210');
    expect(mine.rating, 4);
    expect(mine.text, 'Sweet and fresh');
    // Only the first name is shown to others.
    expect(mine.name, 'Navi');
    expect(mine.orderId, order.id);

    // Invoice.
    await tester.pump(const Duration(seconds: 5)); // snackbar goes away
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(_key('download-invoice-button'), 300,
        scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(_key('download-invoice-button'));
    await tester.pumpAndSettle();
    await tester.tap(_key('download-invoice-button'));
    for (var i = 0; i < 20 && invoice == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Could not make the invoice. Try again.'), findsNothing);
    expect(invoice, isNotNull);
    expect(String.fromCharCodes(invoice!.take(5)), '%PDF-');
    expect(invoiceName, startsWith('mart2door-invoice-'));
    expect(invoiceName, endsWith('.pdf'));

    // The product page shows the new review with the two sample ones.
    router.go(Routes.home);
    await tester.pumpAndSettle();
    router.push(Routes.product('p01'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(_key('product-reviews'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('3 reviews'), findsOneWidget);
    expect(find.text('Sweet and fresh'), findsOneWidget);
    expect(
      tester.widget<Text>(_key('review-average')).data,
      ((5 + 4 + 4) / 3).toStringAsFixed(1),
    );
  });

  test('invoice lines follow the bill', () async {
    final order = Order.fromMap('abc', {
      'userId': 'u',
      'items': [
        {'productId': 'p', 'name': 'Tea', 'unit': '250 g', 'pricePaise': 12500, 'quantity': 2},
      ],
      'subtotalPaise': 25000,
      'deliveryFeePaise': 6000,
      'totalPaise': 28500,
      'couponCode': 'SAVE10',
      'couponDiscountPaise': 2500,
      'address': {'name': 'Navi', 'phone': '9', 'line1': 'x', 'landmark': '', 'pincode': '600001'},
      'paymentMethod': 'online',
      'paymentStatus': 'paid',
      'status': 'delivered',
      'createdAt': 0,
      'deliveryType': 'courier',
    });
    expect(invoiceLines(order), [
      ('Item total', 25000),
      ('Delivery charge', 6000),
      ('Coupon SAVE10', -2500),
    ]);
    final bytes = await buildInvoicePdf(order, StoreSettings.defaults);
    expect(bytes.length, greaterThan(1000));
  });
}
