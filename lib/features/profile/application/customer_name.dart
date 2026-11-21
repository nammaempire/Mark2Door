import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/storage/local_store.dart';

/// The name the shopper gave on the delivery pincode page; empty until
/// they enter one. Shown on the account page and used to fill in new
/// delivery addresses.
final customerNameProvider =
    NotifierProvider<CustomerNameController, String>(CustomerNameController.new);

class CustomerNameController extends Notifier<String> {
  @override
  String build() =>
      ref.read(localStoreProvider).readString(LocalStore.customerNameKey) ?? '';

  /// Saves the name on this phone and, without waiting, with the shopper's
  /// account. The account copy is best effort (it can sit queued while the
  /// phone is offline); the name is already usable either way.
  Future<void> set(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == state) return;
    state = trimmed;
    await ref
        .read(localStoreProvider)
        .writeString(LocalStore.customerNameKey, trimmed);
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    unawaited(
      ref
          .read(customerProfileRepositoryProvider)
          .saveName(user, trimmed)
          .catchError((Object _) {}),
    );
  }

  /// The name saved with the account, for a shopper signing in on a new
  /// phone. Null when there is none or it cannot be read.
  Future<String?> fetchSaved() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return null;
    try {
      return await ref
          .read(customerProfileRepositoryProvider)
          .fetchName(user.uid)
          .timeout(const Duration(seconds: 5));
    } on Exception {
      return null;
    }
  }
}
