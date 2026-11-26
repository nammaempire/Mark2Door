import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mart2door/app.dart';
import 'package:mart2door/core/providers.dart';
import 'package:mart2door/core/storage/local_store.dart';
import 'package:mart2door/features/requests/product_requests.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _signedIn = <String, Object>{
  LocalStore.demoSessionKey: '+919876543210',
  LocalStore.pincodeKey: '560034',
  LocalStore.customerNameKey: 'Navi',
};

Finder _key(String k) => find.byKey(ValueKey(k));

Future<FakeProductRequestRepository> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(_signedIn);
  final store = await SharedPreferences.getInstance();
  final requests = FakeProductRequestRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(store),
        productRequestRepositoryProvider.overrideWithValue(requests),
      ],
      child: const Mart2DoorApp(),
    ),
  );
  await tester.pump(const Duration(seconds: 3)); // splash
  await tester.pumpAndSettle();
  return requests;
}

void main() {
  testWidgets('a search that finds nothing offers to request the product; '
      'the request carries name, number and pincode', (tester) async {
    final requests = await _pumpApp(tester);
    await tester.enterText(_key('search-field'), 'Mysore sandal soap');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('No products found'), findsOneWidget);
    await tester.ensureVisible(_key('request-product-button'));
    await tester.pumpAndSettle();
    await tester.tap(_key('request-product-button'));
    await tester.pumpAndSettle();

    // The form starts with what was searched; both boxes are needed.
    expect(
      tester.widget<TextFormField>(_key('request-name')).controller!.text,
      'Mysore sandal soap',
    );
    await tester.tap(_key('request-submit'));
    await tester.pumpAndSettle();
    expect(find.text('Enter how many you need'), findsOneWidget);
    expect(requests.sent, isEmpty);

    await tester.enterText(_key('request-quantity'), '3');
    await tester.tap(_key('request-submit'));
    await tester.pumpAndSettle();
    final sent = requests.sent.single;
    expect(sent.product, 'Mysore sandal soap');
    expect(sent.quantity, '3');
    expect(sent.customerName, 'Navi');
    expect(sent.phone, '+919876543210');
    expect(sent.pincode, '560034');
    expect(sent.toMap(DateTime(2026, 11, 26))['status'], 'new');
    expect(_key('request-name'), findsNothing);
    expect(find.textContaining('Request sent'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a category page ends with the request card', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('category-tile-'),
    ).first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      _key('request-product-card'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text("Can't find what you want?"), findsOneWidget);
  });
}
