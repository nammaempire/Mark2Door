import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/storage/local_store.dart';

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
  return ref.watch(serviceAreaRepositoryProvider).isServiceable(pincode);
});

/// False only once we know we do not deliver to the shopper's pincode.
/// While the check is running, or if it fails, shopping stays open; the
/// checkout confirms the delivery area again before an order is placed.
final canOrderProvider = Provider<bool>(
  (ref) => ref.watch(deliveryAvailableProvider).valueOrNull ?? true,
);
