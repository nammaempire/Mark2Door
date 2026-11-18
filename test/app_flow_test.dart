import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mart2door/app.dart';
import 'package:mart2door/core/storage/local_store.dart';
import 'package:mart2door/features/auth/presentation/login_screen.dart';
import 'package:mart2door/features/catalog/presentation/home_screen.dart';
import 'package:mart2door/features/catalog/presentation/product_detail_screen.dart';
import 'package:mart2door/features/checkout/presentation/order_result_screen.dart';
import 'package:mart2door/features/orders/presentation/order_detail_screen.dart';
import 'package:mart2door/features/service_area/presentation/pincode_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// End-to-end journeys against the sample-data repositories.
Future<void> _pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
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
}

const _signedIn = <String, Object>{
  LocalStore.demoSessionKey: '+919876543210',
  LocalStore.pincodeKey: '560034',
};

Future<void> _addToCartAndOpenCheckout(WidgetTester tester) async {
  final addBanana = find.byKey(const ValueKey('add-p01'));
  await tester.scrollUntilVisible(
    addBanana,
    300,
    scrollable: find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(addBanana);
  await tester.pumpAndSettle();
  await tester.tap(addBanana);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('cart-bar')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('checkout-button')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('name-field')), 'Navi');
  await tester.enterText(
    find.byKey(const ValueKey('line1-field')),
    '12, 4th Cross, Koramangala',
  );
}

void main() {
  testWidgets('new user: login, OTP, pincode gate, then home', (tester) async {
    await _pumpApp(tester);
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('phone-field')), '12345');
    await tester.tap(find.text('Get OTP'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('phone-field')),
      '9876543210',
    );
    await tester.tap(find.text('Get OTP'));
    await tester.pumpAndSettle();
    expect(find.text('Enter OTP'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('otp-field')), '000000');
    await tester.pumpAndSettle();
    expect(find.textContaining('Incorrect OTP'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('otp-field')), '123456');
    await tester.pumpAndSettle();
    expect(find.byType(PincodeScreen), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('pincode-field')),
      '110001',
    );
    await tester.tap(find.text('Check availability'));
    await tester.pumpAndSettle();
    expect(find.textContaining("don't deliver to 110001"), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('pincode-field')),
      '560034',
    );
    await tester.tap(find.text('Check availability'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Pincode 560034'), findsOneWidget);
  });

  testWidgets('returning user skips login and lands on home', (tester) async {
    await _pumpApp(tester, prefs: _signedIn);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Shop by category'), findsOneWidget);
    expect(find.text('Deals of the day'), findsOneWidget);
  });

  testWidgets('cash on delivery order reaches success and order detail',
      (tester) async {
    await _pumpApp(tester, prefs: _signedIn);
    await _addToCartAndOpenCheckout(tester);

    await tester.ensureVisible(find.byKey(const ValueKey('method-cod')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('method-cod')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('place-order-button')));
    await tester.pumpAndSettle();

    expect(find.byType(OrderResultScreen), findsOneWidget);
    expect(find.text('Order placed'), findsOneWidget);
    expect(find.text('Arriving by'), findsOneWidget);
    expect(find.text('₹72'), findsOneWidget); // 42 + 30 delivery

    await tester.tap(find.byKey(const ValueKey('track-button')));
    await tester.pumpAndSettle();
    expect(find.byType(OrderDetailScreen), findsOneWidget);
    expect(find.textContaining('Arriving in'), findsOneWidget);
    expect(find.textContaining('Estimated delivery by'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Cash on delivery'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Cash on delivery'), findsOneWidget);
  });

  testWidgets('failed online payment keeps the cart for a retry',
      (tester) async {
    await _pumpApp(tester, prefs: _signedIn);
    await _addToCartAndOpenCheckout(tester);

    await tester.tap(find.byKey(const ValueKey('place-order-button')));
    // The pay button keeps spinning behind the sheet, so settle by time.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('simulate-failed')));
    await tester.pumpAndSettle();

    expect(find.text('Payment failed'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('retry-button')));
    await tester.pumpAndSettle();
    expect(find.text('Your cart'), findsOneWidget);
    expect(find.text('Banana Robusta'), findsOneWidget);
  });

  testWidgets('pending online payment shows the pending page', (tester) async {
    await _pumpApp(tester, prefs: _signedIn);
    await _addToCartAndOpenCheckout(tester);

    await tester.tap(find.byKey(const ValueKey('place-order-button')));
    // The pay button keeps spinning behind the sheet, so settle by time.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('simulate-pending')));
    await tester.pumpAndSettle();

    expect(find.text('Payment pending'), findsOneWidget);
  });

  testWidgets('product detail: stepper updates the cart badge', (tester) async {
    await _pumpApp(tester, prefs: _signedIn);
    final dealCard = find.text('Tomato Local').first;
    await tester.scrollUntilVisible(
      dealCard,
      200,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(dealCard);
    await tester.pumpAndSettle();
    await tester.tap(dealCard);
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('detail-p02')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add one').last);
    await tester.pumpAndSettle();
    expect(find.text('2'), findsWidgets);

    await tester.tap(find.text('Go to cart'));
    await tester.pumpAndSettle();
    expect(find.text('Your cart'), findsOneWidget);
    expect(find.text('₹36'), findsWidgets);
  });

  testWidgets('logging out returns to login', (tester) async {
    await _pumpApp(tester, prefs: _signedIn);
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('logout-tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
