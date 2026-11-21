import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/otp_confirm_dialog.dart';
import '../../cart/application/cart_controller.dart';
import '../../checkout/application/address_book.dart';
import '../../service_area/application/pincode_controller.dart';
import '../application/customer_name.dart';

/// Deletes the shopper's account after they confirm and re-enter an OTP.
///
/// Removes the login, the profile (name), the m2d wallet and everything
/// saved on this phone. Past orders stay with the store as sales records,
/// no longer tied to a login. The router returns to the login page once
/// the session ends.
Future<void> deleteCustomerAccount(BuildContext context) async {
  // The account page is gone by the time this finishes, so everything is
  // read from the app-wide container, not from the page.
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  final auth = container.read(authRepositoryProvider);
  final user = auth.currentUser;
  if (user == null) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete your account?'),
      content: const Text(
        'This cannot be undone.\n\n'
        '• Your login, name and saved addresses are removed.\n'
        '• Any m2d wallet balance and invite progress are lost.\n'
        '• You will no longer see your past orders. The store keeps its '
        'order records.\n\n'
        'Orders already on the way will still be delivered.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep account'),
        ),
        TextButton(
          key: const ValueKey('confirm-delete-account'),
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (!(confirmed ?? false) || !context.mounted) return;

  if (!auth.signedInRecently) {
    final verified =
        await confirmWithOtp(context, auth: auth, phone: user.phone);
    if (!verified) return;
  }

  try {
    // Stop order notifications to this phone; never blocks the deletion.
    try {
      await container
          .read(pushServiceProvider)
          .unregister(user.uid)
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
    await container
        .read(customerProfileRepositoryProvider)
        .deleteData(user)
        .timeout(const Duration(seconds: 20));
    await auth.deleteAccount();
  } on AuthFailure catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return;
  } on Exception {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Could not delete your account. Check your internet connection '
          'and try again.',
        ),
      ),
    );
    return;
  }

  // Forget everything this phone remembered about the shopper.
  final store = container.read(localStoreProvider);
  for (final key in const [
    LocalStore.customerNameKey,
    LocalStore.cartKey,
    LocalStore.addressKey,
    LocalStore.addressBookKey,
    LocalStore.pincodeKey,
  ]) {
    await store.writeString(key, null);
  }
  container
    ..invalidate(customerNameProvider)
    ..invalidate(cartProvider)
    ..invalidate(addressBookProvider)
    ..invalidate(pincodeProvider);
  messenger.showSnackBar(
    const SnackBar(content: Text('Your account has been deleted.')),
  );
}
