import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mart2door/app.dart';
import 'package:mart2door/core/storage/local_store.dart';
import 'package:mart2door/features/catalog/presentation/product_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phones set to a large font size must not push text out of the product
/// cards (the yellow and black "overflowed" stripes).
void main() {
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('home has no overflow at font size x$scale', (tester) async {
      // A small phone, where space is tightest.
      tester.view.physicalSize = const Size(720, 1520);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      SharedPreferences.setMockInitialValues({
        LocalStore.demoSessionKey: '+919876543210',
        LocalStore.pincodeKey: '560034',
      });
      final store = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(store)],
          child: const Mart2DoorApp(),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Scroll through the whole home page; any overflow fails the test.
      final scroll = find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      for (var i = 0; i < 12; i++) {
        await tester.drag(scroll, const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      expect(find.byType(ProductCard), findsWidgets);
      expect(tester.takeException(), isNull);

      // The app never scales text past 1.2, however large the setting.
      final context = tester.element(find.byType(ProductCard).first);
      final applied = MediaQuery.textScalerOf(context).scale(100) / 100;
      expect(applied, lessThanOrEqualTo(1.2 + 0.001));
      expect(
        ProductCard.heightOf(context),
        greaterThanOrEqualTo(ProductCard.height),
      );
    });
  }
}
