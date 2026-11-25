import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/storage/local_store.dart';
import '../data/service_area_repository.dart';

/// The pincode the shopper wants delivery to; null until they enter one.
/// Any valid pincode is accepted, so shoppers outside the delivery area
/// can still browse. Whether we deliver there is [deliveryAvailableProvider].
final pincodeProvider =
    NotifierProvider<PincodeController, String?>(PincodeController.new);

class PincodeController extends Notifier<String?> {
  @override
  String? build() =>
      ref.read(localStoreProvider).readString(LocalStore.pincodeKey);

  Future<void> set(String pincode) async {
    state = pincode;
    await ref
        .read(localStoreProvider)
        .writeString(LocalStore.pincodeKey, pincode);
  }
}

/// Whether the admin has the shopper's pincode switched on as a delivery
/// area. Re-checked whenever the pincode changes.
final deliveryAvailableProvider = FutureProvider<bool>((ref) async {
  final pincode = ref.watch(pincodeProvider);
  if (pincode == null) return true;
  final served =
      await ref.watch(serviceAreaRepositoryProvider).isServiceable(pincode);
  // The store sees which pincodes shoppers ask for and cannot get, so it
  // knows where to start delivering next.
  if (!served) ref.read(demandLogProvider).pincodeNotServed(pincode);
  return served;
});

/// True once we know the shopper's own pincode has no instant delivery.
/// These shoppers get two tabs: Instant (for an address in a pincode we
/// do serve) and Outstation (courier, all over India).
final outOfAreaProvider = Provider<bool>(
  (ref) => !(ref.watch(deliveryAvailableProvider).valueOrNull ?? true),
);

/// Whether the store delivers instantly to [pincode]. Checked live at
/// checkout, where the shopper can type a different pincode.
final pincodeServedProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, pincode) =>
      ref.watch(serviceAreaRepositoryProvider).isServiceable(pincode),
);

/// The two ways of shopping.
enum ShopMode { instant, outstation }

/// The tab an out-of-area shopper has open.
final shopTabProvider =
    NotifierProvider<ShopTabController, ShopMode>(ShopTabController.new);

class ShopTabController extends Notifier<ShopMode> {
  @override
  ShopMode build() => ShopMode.instant;

  void show(ShopMode mode) => state = mode;
}

/// How the shopper is shopping right now. Inside the delivery area it is
/// always instant; outside it follows the open tab.
final shopModeProvider = Provider<ShopMode>(
  (ref) => ref.watch(outOfAreaProvider)
      ? ref.watch(shopTabProvider)
      : ShopMode.instant,
);

/// Pincodes with instant delivery, for the "choose a pincode" list.
final serviceAreasProvider = FutureProvider<List<ServiceArea>>(
  (ref) => ref.watch(serviceAreaRepositoryProvider).fetchAreas(),
);

/// The serviced pincode an out-of-area shopper picked on the Instant tab,
/// to order for an address there; null until they pick one.
final instantPincodeProvider =
    NotifierProvider<InstantPincodeController, String?>(
  InstantPincodeController.new,
);

class InstantPincodeController extends Notifier<String?> {
  @override
  String? build() {
    // Starts again when the shopper changes their own pincode.
    ref.watch(pincodeProvider);
    return ref
        .read(localStoreProvider)
        .readString(LocalStore.instantPincodeKey);
  }

  Future<void> set(String? pincode) async {
    state = pincode;
    await ref
        .read(localStoreProvider)
        .writeString(LocalStore.instantPincodeKey, pincode);
  }
}

/// The pincode the current order will be delivered to: the shopper's own,
/// or the one picked on the Instant tab. Null while an out-of-area
/// shopper has not picked one.
final deliveryPincodeProvider = Provider<String?>((ref) {
  final own = ref.watch(pincodeProvider);
  if (!ref.watch(outOfAreaProvider)) return own;
  return ref.watch(shopModeProvider) == ShopMode.outstation
      ? own
      : ref.watch(instantPincodeProvider);
});

/// The store that serves the order being shopped for, when the business
/// has several stores: the one that delivers to the delivery pincode.
/// Null with one shop, on the Outstation tab, and until it is known. It
/// decides which store's stock the shopper sees.
final storeIdProvider = FutureProvider<String?>((ref) async {
  final pincode = ref.watch(deliveryPincodeProvider);
  if (pincode == null || ref.watch(shopModeProvider) == ShopMode.outstation) {
    return null;
  }
  try {
    return await ref
        .watch(serviceAreaRepositoryProvider)
        .storeIdFor(pincode);
  } catch (_) {
    return null; // no signal: the product's own stock is shown
  }
});

/// True when the order is for a pincode other than the shopper's own, so
/// the phone's GPS position says nothing about the delivery address.
final orderingForElsewhereProvider = Provider<bool>(
  (ref) =>
      ref.watch(outOfAreaProvider) &&
      ref.watch(shopModeProvider) == ShopMode.instant,
);

/// False only when there is nowhere to deliver yet: an out-of-area
/// shopper on the Instant tab who has not picked a serviced pincode.
/// While the area check is running, or if it fails, shopping stays open;
/// the checkout confirms the delivery area again before an order is placed.
final canOrderProvider = Provider<bool>(
  (ref) => ref.watch(deliveryPincodeProvider) != null,
);
