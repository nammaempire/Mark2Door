import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mart2door/core/config/env.dart';
import 'package:mart2door/core/config/store_settings.dart';
import 'package:mart2door/core/storage/local_store.dart';
import 'package:mart2door/core/utils/formatters.dart';
import 'package:mart2door/features/cart/application/cart_controller.dart';
import 'package:mart2door/features/cart/domain/cart.dart';
import 'package:mart2door/features/catalog/domain/product.dart';
import 'package:mart2door/features/checkout/domain/address.dart';
import 'package:mart2door/features/orders/domain/order.dart';
import 'package:mart2door/features/store/application/store_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _milk = Product(
  id: 'milk',
  name: 'Milk',
  categoryId: 'dairy',
  unit: '500 ml',
  pricePaise: 2700,
  mrpPaise: 3000,
);
const _atta = Product(
  id: 'atta',
  name: 'Atta',
  categoryId: 'staples',
  unit: '5 kg',
  pricePaise: 23900,
  mrpPaise: 28500,
);
const _soldOut = Product(
  id: 'butter',
  name: 'Butter',
  categoryId: 'dairy',
  unit: '100 g',
  pricePaise: 5800,
  mrpPaise: 6000,
  inStock: false,
);

Future<ProviderContainer> _container([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('formatPaise', () {
    test('formats whole and fractional rupees with Indian grouping', () {
      expect(formatPaise(0), '₹0');
      expect(formatPaise(4200), '₹42');
      expect(formatPaise(4250), '₹42.50');
      expect(formatPaise(123456700), '₹12,34,567');
    });
  });

  group('Validators', () {
    test('phone accepts 10 digits starting 6-9 only', () {
      expect(Validators.phone('9876543210'), isNull);
      expect(Validators.phone('1234567890'), isNotNull);
      expect(Validators.phone('98765'), isNotNull);
      expect(Validators.phone(''), isNotNull);
    });

    test('pincode needs 6 digits not starting with 0', () {
      expect(Validators.pincode('560034'), isNull);
      expect(Validators.pincode('056003'), isNotNull);
      expect(Validators.pincode('5600'), isNotNull);
    });
  });

  group('CartController', () {
    test('add / remove updates quantities and totals', () async {
      final c = await _container();
      final cart = c.read(cartProvider.notifier);

      cart
        ..add(_milk)
        ..add(_milk)
        ..add(_atta);
      expect(c.read(cartProvider).totalQuantity, 3);
      expect(c.read(cartProvider).subtotalPaise, 2 * 2700 + 23900);
      expect(c.read(cartProvider).savingsPaise, 2 * 300 + 4600);

      cart
        ..remove(_milk)
        ..remove(_milk);
      expect(c.read(cartProvider).quantityOf('milk'), 0);
      expect(c.read(cartProvider).lines.single.product, _atta);
    });

    test('delivery fee applies below the free-delivery threshold', () async {
      final c = await _container();
      final cart = c.read(cartProvider.notifier)..add(_milk);

      expect(c.read(cartProvider).deliveryFeePaise, AppConfig.deliveryFeePaise);
      expect(c.read(cartProvider).totalPaise, 2700 + AppConfig.deliveryFeePaise);
      expect(
        c.read(cartProvider).toFreeDeliveryPaise,
        AppConfig.freeDeliveryThresholdPaise - 2700,
      );

      cart.setQuantity(_atta, 3); // 71,700 paise > threshold
      expect(c.read(cartProvider).deliveryFeePaise, 0);
      expect(c.read(cartProvider).toFreeDeliveryPaise, 0);
    });

    test('quantity is capped and out-of-stock items are rejected', () async {
      final c = await _container();
      c.read(cartProvider.notifier)
        ..setQuantity(_milk, 99)
        ..add(_soldOut);

      expect(c.read(cartProvider).quantityOf('milk'), AppConfig.maxQtyPerItem);
      expect(c.read(cartProvider).quantityOf('butter'), 0);
    });

    test('empty cart has no delivery fee', () {
      expect(const Cart().deliveryFeePaise, 0);
      expect(const Cart().totalPaise, 0);
    });

    test('totals follow the delivery settings set by the admin', () async {
      const fees = StoreSettings(
        deliveryFeePaise: 2000,
        freeDeliveryThresholdPaise: 5000,
        deliveryEtaMinutes: 45,
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          storeSettingsProvider.overrideWithValue(fees),
        ],
      );
      addTearDown(c.dispose);
      final cart = c.read(cartProvider.notifier)..add(_milk);

      expect(c.read(cartProvider).deliveryFeePaise, 2000);
      expect(c.read(cartProvider).toFreeDeliveryPaise, 5000 - 2700);

      cart.add(_milk); // 5,400 paise: over the admin's threshold
      expect(c.read(cartProvider).deliveryFeePaise, 0);

      cart.clear(); // settings survive clearing the cart
      cart.add(_milk);
      expect(c.read(cartProvider).deliveryFeePaise, 2000);
    });

    test('settings fall back to defaults for missing fields', () {
      final s = StoreSettings.fromMap(const {'deliveryFeePaise': 1500});
      expect(s.deliveryFeePaise, 1500);
      expect(
        s.freeDeliveryThresholdPaise,
        StoreSettings.defaults.freeDeliveryThresholdPaise,
      );
      expect(s.deliveryEtaMinutes, StoreSettings.defaults.deliveryEtaMinutes);
    });

    test('cart is restored from device storage', () async {
      final first = await _container();
      first.read(cartProvider.notifier)
        ..add(_milk)
        ..add(_milk);
      final saved = first.read(localStoreProvider).readString(LocalStore.cartKey)!;

      final second = await _container({LocalStore.cartKey: saved});
      expect(second.read(cartProvider).quantityOf('milk'), 2);
      expect(second.read(cartProvider).subtotalPaise, 5400);
    });
  });

  group('Order.eta', () {
    final placedAt = DateTime(2026, 11, 19, 20, 10);
    Order order({
      OrderStatus status = OrderStatus.placed,
      PaymentMethod method = PaymentMethod.cod,
      PaymentStatus payment = PaymentStatus.pending,
      bool withEta = true,
    }) =>
        Order(
          id: 'o1',
          userId: 'u1',
          items: const [],
          subtotalPaise: 0,
          deliveryFeePaise: 0,
          totalPaise: 0,
          address: const Address(
            name: '',
            phone: '',
            line1: '',
            landmark: '',
            pincode: '',
          ),
          paymentMethod: method,
          paymentStatus: payment,
          status: status,
          createdAt: placedAt,
          etaAt: withEta ? placedAt.add(const Duration(minutes: 30)) : null,
        );

    test('counts down and rounds partial minutes up', () {
      final eta = order().eta(placedAt.add(const Duration(minutes: 5, seconds: 20)))!;
      expect(eta.kind, EtaKind.onTime);
      expect(eta.headline, 'Arriving in 25 min');
      expect(eta.detail, 'Estimated delivery by 8:40 PM');
    });

    test('turns into a late message once the estimate has passed', () {
      final eta = order().eta(placedAt.add(const Duration(minutes: 31)))!;
      expect(eta.kind, EtaKind.late);
      expect(eta.headline, 'Arriving soon');
    });

    test('delivered, cancelled and unpaid orders do not show a countdown', () {
      expect(order(status: OrderStatus.delivered).eta(placedAt)!.kind,
          EtaKind.delivered);
      expect(order(status: OrderStatus.cancelled).eta(placedAt), isNull);
      expect(
        order(method: PaymentMethod.online).eta(placedAt)!.kind,
        EtaKind.onHold,
      );
      expect(order(withEta: false).eta(placedAt), isNull);
    });

    test('etaAt survives a round trip through the stored map', () {
      final restored = Order.fromMap('o1', order().toMap());
      expect(restored.etaAt, placedAt.add(const Duration(minutes: 30)));
      expect(Order.fromMap('o2', order(withEta: false).toMap()).etaAt, isNull);
    });

    test('rider assigned by the admin is read from the stored order', () {
      final map = order().toMap()
        ..['riderName'] = 'Suresh Kumar'
        ..['riderPhone'] = '9900011111';
      final restored = Order.fromMap('o1', map);
      expect(restored.riderName, 'Suresh Kumar');
      expect(restored.riderPhone, '9900011111');
      expect(Order.fromMap('o2', order().toMap()).riderName, isNull);
    });
  });
}
