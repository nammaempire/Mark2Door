import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_providers.dart';
import '../domain/rewards.dart';

/// The signed-in shopper's wallet, live.
final walletProvider = StreamProvider<Wallet>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(Wallet.empty);
  return ref.watch(rewardsRepositoryProvider).watchWallet(user.uid);
});

/// Wallet balance for checkout; 0 while loading or if it cannot be read,
/// so an order can always be placed without it.
final walletBalanceProvider = Provider<int>(
  (ref) => ref.watch(walletProvider).valueOrNull?.balancePaise ?? 0,
);

final walletHistoryProvider = StreamProvider.autoDispose<List<WalletEntry>>(
  (ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return Stream.value(const []);
    return ref.watch(rewardsRepositoryProvider).watchHistory(user.uid);
  },
);

final referralsProvider = StreamProvider.autoDispose<List<Referral>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(rewardsRepositoryProvider).watchReferrals(user.uid);
});

/// The shopper's own invite code, created on first use.
final inviteCodeProvider = FutureProvider<String>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) throw const RewardsFailure('Log in to invite friends.');
  return ref.watch(rewardsRepositoryProvider).inviteCode(user);
});

/// Whether the shopper has already entered a friend's code.
final hasUsedCodeProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return true;
  return ref.watch(rewardsRepositoryProvider).hasUsedCode(user.uid);
});
