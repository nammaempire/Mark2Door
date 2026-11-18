import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/storage/local_store.dart';

/// The pincode the shopper is ordering to; null until one is confirmed
/// as serviceable.
final pincodeProvider =
    NotifierProvider<PincodeController, String?>(PincodeController.new);

class PincodeController extends Notifier<String?> {
  @override
  String? build() =>
      ref.read(localStoreProvider).readString(LocalStore.pincodeKey);

  /// Returns true and stores [pincode] when we deliver there.
  Future<bool> trySet(String pincode) async {
    final ok =
        await ref.read(serviceAreaRepositoryProvider).isServiceable(pincode);
    if (ok) {
      state = pincode;
      await ref
          .read(localStoreProvider)
          .writeString(LocalStore.pincodeKey, pincode);
    }
    return ok;
  }
}
