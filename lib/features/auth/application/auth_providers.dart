import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../domain/app_user.dart';

final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// Synchronous view of the signed-in user for widgets.
final currentUserProvider = Provider<AppUser?>((ref) {
  ref.watch(authStateProvider); // rebuild on sign-in / sign-out
  return ref.watch(authRepositoryProvider).currentUser;
});

/// Registers this phone for order notifications once a customer is signed
/// in. Watched by the home screen; failing to register never blocks the
/// app, because orders also update live on screen.
final pushRegistrationProvider = FutureProvider<void>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid ?? '';
  if (uid.isEmpty) return;
  try {
    await ref.watch(pushServiceProvider).register(uid);
  } on Exception catch (e) {
    debugPrint('PUSH: could not register customer $uid: $e');
  }
});
