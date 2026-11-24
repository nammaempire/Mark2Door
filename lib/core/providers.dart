import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/fake_auth_repository.dart';
import '../features/auth/data/firebase_auth_repository.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/catalog/data/fake_catalog_repository.dart';
import '../features/catalog/data/firestore_catalog_repository.dart';
import '../features/checkout/data/coupon_repository.dart';
import '../features/insights/demand_log.dart';
import '../features/checkout/data/payment_gateway.dart';
import '../features/orders/data/fake_order_repository.dart';
import '../features/orders/data/firestore_order_repository.dart';
import '../features/orders/data/order_repository.dart';
import '../features/profile/data/customer_profile_repository.dart';
import '../features/rewards/data/firestore_rewards_repository.dart';
import '../features/rewards/data/rewards_repository.dart';
import '../features/service_area/data/service_area_repository.dart';
import '../features/store/data/store_repository.dart';
import '../features/support/data/content_repository.dart';
import 'config/env.dart';
import 'location/location_service.dart';
import 'push/push_service.dart';
import 'storage/local_store.dart';

/// Composition root: the only place that knows which implementation backs
/// each interface. Features depend on the interfaces, so swapping sample
/// data for Firebase (or a fake in tests) never touches UI code.

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return Env.useFirebase
      ? FirebaseAuthRepository(FirebaseAuth.instance)
      : FakeAuthRepository(ref.watch(localStoreProvider));
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return Env.useFirebase
      ? FirestoreCatalogRepository(FirebaseFirestore.instance)
      : FakeCatalogRepository();
});

final serviceAreaRepositoryProvider = Provider<ServiceAreaRepository>((ref) {
  return Env.useFirebase
      ? FirestoreServiceAreaRepository(FirebaseFirestore.instance)
      : FakeServiceAreaRepository();
});

final rewardsRepositoryProvider = Provider<RewardsRepository>((ref) {
  return Env.useFirebase
      ? FirestoreRewardsRepository(FirebaseFirestore.instance)
      : FakeRewardsRepository();
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  if (Env.useFirebase) {
    return FirestoreOrderRepository(FirebaseFirestore.instance);
  }
  // Sample data: paying from the wallet updates the sample wallet too.
  final rewards = ref.watch(rewardsRepositoryProvider);
  final coupons = ref.watch(couponRepositoryProvider);
  return FakeOrderRepository(
    rewards: rewards is FakeRewardsRepository ? rewards : null,
    coupons: coupons is FakeCouponRepository ? coupons : null,
  );
});

final couponRepositoryProvider = Provider<CouponRepository>((ref) {
  return Env.useFirebase
      ? FirestoreCouponRepository(FirebaseFirestore.instance)
      : FakeCouponRepository();
});

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return Env.useFirebase
      ? FirestoreContentRepository(FirebaseFirestore.instance)
      : FakeContentRepository();
});

final customerProfileRepositoryProvider =
    Provider<CustomerProfileRepository>((ref) {
  return Env.useFirebase
      ? FirestoreCustomerProfileRepository(FirebaseFirestore.instance)
      : FakeCustomerProfileRepository();
});

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return Env.useFirebase
      ? FirestoreStoreRepository(FirebaseFirestore.instance)
      : FakeStoreRepository();
});

final paymentGatewayProvider = Provider<PaymentGateway>((ref) {
  // With the real backend, payments go through Razorpay and are confirmed
  // by the server. Sample data keeps the try-it-out sheet.
  return Env.useFirebase
      ? RazorpayPaymentGateway(FirebaseFunctions.instance)
      : SimulatedPaymentGateway(rootNavigatorKey);
});

final pushServiceProvider = Provider<PushService>((ref) {
  return Env.useFirebase
      ? FirebasePushService(
          FirebaseMessaging.instance,
          FirebaseFirestore.instance,
        )
      : FakePushService();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return Env.useFirebase ? DeviceLocationService() : FakeLocationService();
});

final demandRepositoryProvider = Provider<DemandRepository>((ref) {
  return Env.useFirebase
      ? FirestoreDemandRepository(FirebaseFirestore.instance)
      : FakeDemandRepository();
});

/// Tells the store what shoppers wanted and could not get.
final demandLogProvider = Provider<DemandLog>(
  (ref) => DemandLog(
    ref.watch(demandRepositoryProvider),
    ref.watch(localStoreProvider),
  ),
);
