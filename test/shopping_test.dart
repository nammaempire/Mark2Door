import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mart2door/app.dart';
import 'package:mart2door/core/config/store_settings.dart';
import 'package:mart2door/core/providers.dart';
import 'package:mart2door/core/storage/local_store.dart';
import 'package:mart2door/core/theme/app_theme.dart';
import 'package:mart2door/core/widgets/shimmer.dart';
import 'package:mart2door/features/auth/application/auth_providers.dart';
import 'package:mart2door/features/auth/domain/app_user.dart';
import 'package:mart2door/features/cart/domain/cart.dart';
import 'package:mart2door/features/cart/presentation/bill_summary.dart';
import 'package:mart2door/features/catalog/application/catalog_providers.dart';
import 'package:mart2door/features/catalog/domain/product.dart';
import 'package:mart2door/features/catalog/domain/promo.dart';
import 'package:mart2door/features/catalog/presentation/home_screen.dart';
import 'package:mart2door/features/catalog/presentation/product_detail_screen.dart';
import 'package:mart2door/features/checkout/application/address_book.dart';
import 'package:mart2door/features/checkout/application/checkout_controller.dart';
import 'package:mart2door/features/checkout/domain/address.dart';
import 'package:mart2door/features/checkout/presentation/order_result_screen.dart';
import 'package:mart2door/features/checkout/presentation/result_animation.dart';
import 'package:mart2door/features/orders/domain/order.dart';
import 'package:mart2door/features/rewards/data/rewards_repository.dart';
import 'package:mart2door/features/rewards/domain/rewards.dart';
import 'package:mart2door/features/store/data/store_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Store whose admin has switched on both extra charges.
class _ChargingStore implements StoreRepository {
  static const settings = StoreSettings(
    deliveryFeePaise: 3000,
    freeDeliveryThresholdPaise: 49900,
    deliveryEtaMinutes: 30,
    handlingFeeEnabled: true,
    handlingFeePaise: 500,
    rainFeeEnabled: true,
    rainFeePaise: 1500,
  );

  @override
  Stream<StoreSettings> watchSettings() => Stream.value(settings);

  @override
  Future<List<Promo>> fetchBanners() async => const [];
}

Future<void> _pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(store),
        ...overrides,
      ],
      child: const Mart2DoorApp(),
    ),
  );
  await tester.pump(const Duration(seconds: 3)); // splash
}

const _signedIn = <String, Object>{
  LocalStore.demoSessionKey: '+919876543210',
  LocalStore.pincodeKey: '560034',
};

final _homeScroll = find
    .descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _addBananaAndOpenCart(WidgetTester tester) async {
  final addBanana = find.byKey(const ValueKey('add-p01'));
  await tester.scrollUntilVisible(addBanana, 300, scrollable: _homeScroll);
  await tester.ensureVisible(addBanana);
  await tester.pumpAndSettle();
  await tester.tap(addBanana);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('cart-bar')));
  await tester.pumpAndSettle();
}

Future<void> _placeCodOrder(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('method-cod')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('method-cod')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('place-order-button')));
  // The result page keeps animating, so advance by time.
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 2));
  expect(find.byType(OrderResultScreen), findsOneWidget);
}

const _milk = Product(
  id: 'milk',
  name: 'Milk',
  categoryId: 'dairy',
  unit: '500 ml',
  pricePaise: 2700,
  mrpPaise: 3000,
);

void main() {
  group('extra charges', () {
    test('are added to the total only while the admin has them on', () {
      const items = {'milk': CartItem(product: _milk, quantity: 2)};

      const off = Cart(items);
      expect(off.handlingFeePaise, 0);
      expect(off.rainFeePaise, 0);
      expect(off.totalPaise, 5400 + 3000);

      const on = Cart(items, _ChargingStore.settings);
      expect(on.handlingFeePaise, 500);
      expect(on.rainFeePaise, 1500);
      expect(on.totalPaise, 5400 + 3000 + 500 + 1500);
      expect(on.savingsPaise, 600);

      // An empty cart is never charged anything.
      expect(const Cart({}, _ChargingStore.settings).totalPaise, 0);
    });

    test('settings read from Firestore default to off', () {
      final settings = StoreSettings.fromMap(const {'deliveryFeePaise': 2000});
      expect(settings.handlingFeeEnabled, isFalse);
      expect(settings.rainFeeEnabled, isFalse);
      expect(
        StoreSettings.fromMap(const {
          'rainFeeEnabled': true,
          'rainFeePaise': 1500,
        }).rainFeePaise,
        1500,
      );
    });

    testWidgets('order summary hides switched-off charges', (tester) async {
      Future<void> pump(int handling, int rain) => tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: OrderSummaryCard(
                  subtotalPaise: 5400,
                  mrpTotalPaise: 6000,
                  deliveryFeePaise: 3000,
                  handlingFeePaise: handling,
                  rainFeePaise: rain,
                  totalPaise: 8400 + handling + rain,
                ),
              ),
            ),
          );

      await pump(0, 0);
      expect(find.text('Handling fee'), findsNothing);
      expect(find.text('Rain charge'), findsNothing);
      // MRP is struck through beside the price, and the saving is shown.
      final mrp = tester.widget<Text>(find.text('₹60'));
      expect(mrp.style!.decoration, TextDecoration.lineThrough);
      expect(find.text('₹54'), findsOneWidget);
      expect(find.text('You save ₹6 on this order'), findsOneWidget);

      await pump(500, 1500);
      expect(find.text('Handling fee'), findsOneWidget);
      expect(find.text('₹5'), findsOneWidget);
      expect(find.text('Rain charge'), findsOneWidget);
      expect(find.text('₹15'), findsOneWidget);
      expect(find.text('₹104'), findsOneWidget);
    });

    testWidgets('are charged on a placed order and shown on its page', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        prefs: _signedIn,
        overrides: [
          storeRepositoryProvider.overrideWithValue(_ChargingStore()),
        ],
      );
      await tester.pumpAndSettle();
      await _addBananaAndOpenCart(tester);

      expect(find.text('Order summary'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Rain charge'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Handling fee'), findsOneWidget);
      // 42 + 30 delivery + 5 handling + 15 rain
      expect(find.textContaining('₹92'), findsWidgets);
      expect(find.text('You save ₹8 on this order'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('checkout-button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('name-field')), 'Navi');
      await tester.enterText(
        find.byKey(const ValueKey('line1-field')),
        '12, 4th Cross',
      );
      await _placeCodOrder(tester);
      expect(find.text('₹92'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(OrderResultScreen)),
      );
      final order = (await container
              .read(orderRepositoryProvider)
              .watchOrders(container.read(currentUserProvider)!.uid)
              .first)
          .single;
      expect(order.handlingFeePaise, 500);
      expect(order.rainFeePaise, 1500);
      expect(order.totalPaise, 9200);
      expect(order.mrpTotalPaise, 5000);
      // Survives the trip through Firestore's map form.
      final read = Order.fromMap(order.id, order.toMap());
      expect(read.rainFeePaise, 1500);
      expect(read.items.single.mrpPaise, 5000);
    });
  });

  group('cart', () {
    testWidgets('suggests similar products that are not already in it', (
      tester,
    ) async {
      await _pumpApp(tester, prefs: _signedIn);
      await tester.pumpAndSettle();
      await _addBananaAndOpenCart(tester);

      await tester.scrollUntilVisible(
        find.text('You might also like'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // Other fruit comes first; the banana already in the cart is left out.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('similar-p02')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('similar-p01')), findsNothing);

      await tester.ensureVisible(find.byKey(const ValueKey('similar-p02')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('similar-p02')));
      await tester.pumpAndSettle();
      // Tomato moved from the suggestions into the cart lines.
      expect(find.byKey(const ValueKey('similar-p02')), findsNothing);
      expect(find.text('Tomato Local'), findsOneWidget);
    });

    test('similarProducts puts the same category first and skips sold out',
        () {
      const all = [
        Product(id: 'a', name: 'A', categoryId: 'x', unit: '', pricePaise: 1, mrpPaise: 1),
        Product(id: 'b', name: 'B', categoryId: 'y', unit: '', pricePaise: 1, mrpPaise: 1),
        Product(id: 'c', name: 'C', categoryId: 'x', unit: '', pricePaise: 1, mrpPaise: 1),
        Product(id: 'd', name: 'D', categoryId: 'x', unit: '', pricePaise: 1, mrpPaise: 1, inStock: false),
      ];
      expect(
        similarProducts(all, [all[0]]).map((p) => p.id),
        ['c', 'b'],
      );
      expect(similarProducts(all, all), isEmpty);
    });
  });

  group('saved addresses', () {
    testWidgets('second order reuses the address; a new one can be added', (
      tester,
    ) async {
      await _pumpApp(tester, prefs: _signedIn);
      await tester.pumpAndSettle();
      await _addBananaAndOpenCart(tester);
      await tester.tap(find.byKey(const ValueKey('checkout-button')));
      await tester.pumpAndSettle();

      // First order: nothing saved yet, so the form is shown.
      expect(find.byKey(const ValueKey('saved-address-card')), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('name-field')), 'Navi');
      await tester.enterText(
        find.byKey(const ValueKey('line1-field')),
        '12, 4th Cross, Koramangala',
      );
      await _placeCodOrder(tester);
      await tester.tap(find.text('Continue shopping'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      // Second order: the saved address is there, with no fields to fill.
      await _addBananaAndOpenCart(tester);
      await tester.tap(find.byKey(const ValueKey('checkout-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('saved-address-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('name-field')), findsNothing);
      expect(find.text('Navi'), findsOneWidget);
      expect(find.text('12, 4th Cross, Koramangala, 560034'), findsOneWidget);

      // Add a different address and deliver there instead.
      await tester.tap(find.byKey(const ValueKey('change-address-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-address-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-address-button')));
      await tester.pumpAndSettle();
      expect(find.text('Enter your name'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('new-name-field')),
        'Office',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-line1-field')),
        '80 Feet Road',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-address-pincode-field')),
        '560038',
      );
      await tester.tap(find.byKey(const ValueKey('save-address-button')));
      await tester.pumpAndSettle();
      expect(find.text('Office'), findsOneWidget);
      expect(find.text('80 Feet Road, 560038'), findsOneWidget);

      await _placeCodOrder(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OrderResultScreen)),
      );
      final orders = await container
          .read(orderRepositoryProvider)
          .watchOrders(container.read(currentUserProvider)!.uid)
          .first;
      expect(orders.first.address.name, 'Office');
      expect(orders.last.address.name, 'Navi');
      expect(container.read(addressBookProvider).addresses, hasLength(2));
    });

    test('book selects, replaces, removes and migrates the old single entry',
        () async {
      const home = Address(
        name: 'Navi',
        phone: '9876543210',
        line1: '12, 4th Cross',
        landmark: '',
        pincode: '560034',
      );
      const office = Address(
        name: 'Office',
        phone: '9876543210',
        line1: '80 Feet Road',
        landmark: 'Near park',
        pincode: '560038',
      );
      // An address saved by the version that kept only one.
      SharedPreferences.setMockInitialValues({
        LocalStore.addressKey:
            '{"name":"Navi","phone":"9876543210","line1":"12, 4th Cross",'
                '"landmark":"","pincode":"560034"}',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final book = container.read(addressBookProvider.notifier);

      expect(container.read(addressBookProvider).selected, home);

      book.use(office);
      expect(container.read(addressBookProvider).selected, office);
      // Using a saved address again selects it without a duplicate.
      book.use(home);
      expect(container.read(addressBookProvider).addresses, hasLength(2));
      expect(container.read(addressBookProvider).selected, home);

      book.remove(0);
      expect(container.read(addressBookProvider).selected, office);
      expect(
        AddressBook.fromMap(container.read(addressBookProvider).toMap())
            .addresses,
        [office],
      );
      book.remove(0);
      expect(container.read(addressBookProvider).selected, isNull);
      expect(prefs.getString(LocalStore.addressBookKey), isNull);
    });
  });

  group('product photos', () {
    test('up to five are read, with the old single photo as a fallback', () {
      expect(Product.fromMap('p', const {}).imageUrls, isEmpty);
      expect(
        Product.fromMap('p', const {'imageUrl': 'https://a/1.jpg'}).imageUrls,
        ['https://a/1.jpg'],
      );
      final many = Product.fromMap('p', {
        'imageUrl': 'https://a/0.jpg',
        'imageUrls': [for (var i = 0; i < 8; i++) 'https://a/$i.jpg'],
      });
      expect(many.imageUrls, hasLength(Product.maxImages));
      expect(many.imageUrl, 'https://a/0.jpg');
    });

    testWidgets('detail page shows a slider only for several photos', (
      tester,
    ) async {
      Future<void> pump(List<String> urls) => tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: AppTheme.light,
                home: Scaffold(
                  body: SizedBox(
                    width: 320,
                    height: 240,
                    child: ProductImageCarousel(
                      product: Product(
                        id: 'p',
                        name: 'Mango',
                        categoryId: 'fruits',
                        unit: '1 kg',
                        pricePaise: 9900,
                        mrpPaise: 12000,
                        emoji: '🥭',
                        imageUrls: urls,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

      await pump(const []);
      expect(find.byType(PageView), findsNothing);
      expect(find.text('🥭'), findsOneWidget);

      await pump([for (var i = 1; i <= 3; i++) 'https://example.com/$i.jpg']);
      // Test network images fail to load, which shows the artwork fallback.
      await tester.pump();
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);
    });
  });

  group('loading and results', () {
    testWidgets('home shows shimmer placeholders until products arrive', (
      tester,
    ) async {
      await _pumpApp(tester, prefs: _signedIn);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(Shimmer), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byType(Shimmer), findsNothing);
      expect(find.text('Shop by category'), findsOneWidget);
      // Let the delivery-area check finish before the test ends.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('every result kind draws through its whole animation', (
      tester,
    ) async {
      for (final kind in ResultKind.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: ResultAnimation(key: ValueKey(kind), kind: kind),
            ),
          ),
        );
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull, reason: kind.name);
      }
      // Stop the looping animation before the test ends.
      await tester.pumpWidget(const SizedBox());
    });

    test('refund state follows payment and order status', () {
      Order order(PaymentStatus payment, OrderStatus status) => Order(
            id: 'M2D1001',
            userId: 'u',
            items: const [],
            subtotalPaise: 0,
            deliveryFeePaise: 0,
            totalPaise: 9900,
            address: const Address(
              name: '',
              phone: '',
              line1: '',
              landmark: '',
              pincode: '',
            ),
            paymentMethod: PaymentMethod.online,
            paymentStatus: payment,
            status: status,
            createdAt: DateTime(2026),
          );

      final paid = order(PaymentStatus.paid, OrderStatus.placed);
      expect(paid.refundInProgress, isFalse);
      expect(paid.isRefunded, isFalse);

      final cancelled = order(PaymentStatus.paid, OrderStatus.cancelled);
      expect(cancelled.refundInProgress, isTrue);

      // Written by the admin web as `paymentStatus: 'refunded'`.
      final refunded = Order.fromMap('M2D1001', {
        ...cancelled.toMap(),
        'paymentStatus': 'refunded',
      });
      expect(refunded.isRefunded, isTrue);
      expect(refunded.refundInProgress, isFalse);
    });

    testWidgets('refund page shows the refund amount', (tester) async {
      await _pumpApp(tester, prefs: _signedIn);
      await tester.pumpAndSettle();
      await _addBananaAndOpenCart(tester);
      await tester.tap(find.byKey(const ValueKey('checkout-button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('name-field')), 'Navi');
      await tester.enterText(
        find.byKey(const ValueKey('line1-field')),
        '12, 4th Cross',
      );
      await _placeCodOrder(tester);

      final context = tester.element(find.byType(OrderResultScreen));
      final container = ProviderScope.containerOf(context);
      final order = (await container
              .read(orderRepositoryProvider)
              .watchOrders(container.read(currentUserProvider)!.uid)
              .first)
          .single;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: OrderResultScreen(
              orderId: order.id,
              outcome: ResultKind.refunded,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const ValueKey('result-refunded')), findsOneWidget);
      expect(find.text('Refund sent'), findsOneWidget);
      expect(find.text('Refund amount'), findsOneWidget);
      expect(find.text('₹72'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('invite and earn', () {
    const me = AppUser(uid: 'demo-+919876543210', phone: '+919876543210');
    AppUser friend(int n) =>
        AppUser(uid: 'friend-$n', phone: '+9198000000${n.toString().padLeft(2, '0')}');

    test('rewards are paid at 1, 3, 6, 10 and 15 friends', () {
      expect(ReferralRules.maxRewardPaise, 12500);
      expect(
        [for (var n = 0; n <= 16; n++) ReferralRules.milestonesReached(n)],
        [0, 1, 1, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 4, 5, 5],
      );
      expect(ReferralRules.invitesToNextReward(0), 1);
      expect(ReferralRules.invitesToNextReward(1), 2);
      expect(ReferralRules.invitesToNextReward(6), 4);
      expect(ReferralRules.invitesToNextReward(15), 0);
      expect(maskPhone('+919876543210'), '98••••3210');
    });

    test('fifteen friends with delivered first orders earn the full ₹125',
        () async {
      final repo = FakeRewardsRepository();
      final code = await repo.inviteCode(me);
      expect(code, hasLength(6));
      expect(await repo.inviteCode(me), code); // stable

      // Bad codes are refused with a reason.
      await expectLater(
        repo.applyCode(friend(1), 'ZZZZZZ'),
        throwsA(isA<RewardsFailure>()),
      );
      await expectLater(
        repo.applyCode(me, code),
        throwsA(
          isA<RewardsFailure>()
              .having((e) => e.message, 'message', contains('own code')),
        ),
      );

      final balances = <int>[];
      for (var n = 1; n <= 15; n++) {
        await repo.applyCode(friend(n), code.toLowerCase());
        // Joining alone pays nothing.
        expect(
          (await repo.watchWallet(me.uid).first).successfulInvites,
          n - 1,
        );
        repo.completeFirstOrder(friend(n).uid);
        // A second delivered order from the same friend does not count.
        repo.completeFirstOrder(friend(n).uid);
        balances.add((await repo.watchWallet(me.uid).first).balancePaise);
      }
      expect(balances, [
        2500, 2500, 5000, 5000, 5000, 7500, 7500, 7500, 7500, 10000, //
        10000, 10000, 10000, 10000, 12500,
      ]);
      final wallet = await repo.watchWallet(me.uid).first;
      expect(wallet.successfulInvites, 15);
      expect(wallet.earnedPaise, 12500);
      expect(await repo.watchHistory(me.uid).first, hasLength(5));
      expect(
        (await repo.watchReferrals(me.uid).first)
            .every((r) => r.status == ReferralStatus.ordered),
        isTrue,
      );
      // A code can be used once per person.
      await expectLater(
        repo.applyCode(friend(1), code),
        throwsA(isA<RewardsFailure>()),
      );
    });

    testWidgets('wallet money comes off the order at checkout', (tester) async {
      final rewards = FakeRewardsRepository();
      final code = await rewards.inviteCode(me);
      await rewards.applyCode(friend(1), code);
      rewards.completeFirstOrder(friend(1).uid); // ₹25 in my wallet

      await _pumpApp(
        tester,
        prefs: _signedIn,
        overrides: [rewardsRepositoryProvider.overrideWithValue(rewards)],
      );
      await tester.pumpAndSettle();
      await _addBananaAndOpenCart(tester);
      await tester.tap(find.byKey(const ValueKey('checkout-button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('name-field')), 'Navi');
      await tester.enterText(
        find.byKey(const ValueKey('line1-field')),
        '12, 4th Cross',
      );

      final walletSwitch = find.byKey(const ValueKey('use-wallet-switch'));
      await tester.scrollUntilVisible(
        walletSwitch,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('₹25 available'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('m2d wallet'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('- ₹25'), findsOneWidget);
      // 42 + 30 delivery = 72, less 25 from the wallet.
      expect(find.textContaining('₹47'), findsWidgets);

      await _placeCodOrder(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OrderResultScreen)),
      );
      final order = (await container
              .read(orderRepositoryProvider)
              .watchOrders(me.uid)
              .first)
          .single;
      expect(order.totalPaise, 7200);
      expect(order.walletAppliedPaise, 2500);
      expect(order.payablePaise, 4700);
      expect(Order.fromMap(order.id, order.toMap()).walletAppliedPaise, 2500);
      expect((await rewards.watchWallet(me.uid).first).balancePaise, 0);
      expect(
        (await rewards.watchHistory(me.uid).first).first.amountPaise,
        -2500,
      );
      expect(find.text('₹47'), findsOneWidget);
    });

    test('wallet never pays more than the order or the balance', () {
      expect(walletAmountFor(7200, 2500), 2500);
      expect(walletAmountFor(1800, 2500), 1800);
      expect(walletAmountFor(7200, 0), 0);
    });

    testWidgets('account page opens invite, wallet, help and legal pages', (
      tester,
    ) async {
      await _pumpApp(tester, prefs: _signedIn);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('invite-tile')));
      await tester.pumpAndSettle();
      expect(find.text('Earn up to ₹125'), findsOneWidget);
      expect(find.byKey(const ValueKey('invite-code')), findsOneWidget);
      expect(find.text('0 of 15 friends ordered'), findsOneWidget);
      // Own code is refused in the "code from a friend" box.
      final code = tester
          .widget<Text>(find.byKey(const ValueKey('invite-code')))
          .data!;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('friend-code-field')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.enterText(
        find.byKey(const ValueKey('friend-code-field')),
        code,
      );
      await tester.tap(find.byKey(const ValueKey('apply-code-button')));
      await tester.pumpAndSettle();
      expect(find.text("You can't use your own code."), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('wallet-tile')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('wallet-balance')), findsOneWidget);
      expect(find.text('Nothing here yet'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      for (final (key, expected) in [
        ('help-tile', 'How long does delivery take?'),
        ('terms-tile', 'Sample terms and conditions text.'),
        ('privacy-tile', 'Sample privacy policy text.'),
      ]) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey(key)),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(find.text(expected), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });
  });
}
