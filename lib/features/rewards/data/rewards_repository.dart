import 'dart:async';
import 'dart:math';

import '../../auth/domain/app_user.dart';
import '../domain/rewards.dart';

abstract interface class RewardsRepository {
  /// The shopper's own invite code, created the first time it is needed.
  Future<String> inviteCode(AppUser user);

  /// Emits the wallet now and on every change; an empty wallet until the
  /// shopper has one.
  Stream<Wallet> watchWallet(String uid);

  /// Newest first.
  Stream<List<WalletEntry>> watchHistory(String uid);

  /// Friends who joined with the shopper's code, newest first.
  Stream<List<Referral>> watchReferrals(String uid);

  /// Whether the shopper has already used somebody's code.
  Future<bool> hasUsedCode(String uid);

  /// Links [user] to the friend who owns [code]. Throws [RewardsFailure]
  /// when the code is unknown, their own, already used, or the shopper has
  /// ordered before.
  Future<void> applyCode(AppUser user, String code);
}

/// Letters and digits that are hard to confuse when read aloud or typed.
const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

String newInviteCode([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(
    6,
    (_) => _codeAlphabet[r.nextInt(_codeAlphabet.length)],
  ).join();
}

String normaliseCode(String input) =>
    input.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

/// In-memory rewards for sample data and tests.
class FakeRewardsRepository implements RewardsRepository {
  final _codes = <String, String>{}; // code -> uid
  final _wallets = <String, Wallet>{};
  final _history = <String, List<WalletEntry>>{};
  final _referrals = <String, ({String referrer, Referral referral})>{};
  final _changes = StreamController<void>.broadcast();

  /// Set by the sample-data order repository so "has ordered before" works.
  bool Function(String uid) hasOrders = (_) => false;

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    yield* _changes.stream.map((_) => read());
  }

  @override
  Future<String> inviteCode(AppUser user) async {
    for (final e in _codes.entries) {
      if (e.value == user.uid) return e.key;
    }
    final code = newInviteCode(Random(user.uid.hashCode));
    _codes[code] = user.uid;
    return code;
  }

  @override
  Stream<Wallet> watchWallet(String uid) =>
      _watch(() => _wallets[uid] ?? Wallet.empty);

  @override
  Stream<List<WalletEntry>> watchHistory(String uid) =>
      _watch(() => List.unmodifiable(_history[uid] ?? const []));

  @override
  Stream<List<Referral>> watchReferrals(String uid) => _watch(
        () => [
          for (final r in _referrals.values)
            if (r.referrer == uid) r.referral,
        ],
      );

  @override
  Future<bool> hasUsedCode(String uid) async => _referrals.containsKey(uid);

  @override
  Future<void> applyCode(AppUser user, String code) async {
    final owner = _codes[normaliseCode(code)];
    if (owner == null) {
      throw const RewardsFailure("That code doesn't match anyone.");
    }
    if (owner == user.uid) {
      throw const RewardsFailure("You can't use your own code.");
    }
    if (_referrals.containsKey(user.uid)) {
      throw const RewardsFailure('You have already used an invite code.');
    }
    if (hasOrders(user.uid)) {
      throw const RewardsFailure(
        'Invite codes are for new customers, before their first order.',
      );
    }
    _referrals[user.uid] = (
      referrer: owner,
      referral: Referral(
        friend: maskPhone(user.phone),
        status: ReferralStatus.joined,
        createdAt: DateTime.now(),
      ),
    );
    _changes.add(null);
  }

  /// Takes [amountPaise] out of the wallet for an order. Used by the
  /// sample-data order repository; Firestore does this in one batch.
  void spend(String uid, int amountPaise, String note) {
    final wallet = _wallets[uid] ?? Wallet.empty;
    _wallets[uid] = Wallet(
      balancePaise: wallet.balancePaise - amountPaise,
      successfulInvites: wallet.successfulInvites,
      rewardedMilestones: wallet.rewardedMilestones,
    );
    (_history[uid] ??= []).insert(
      0,
      WalletEntry(
        amountPaise: -amountPaise,
        type: 'order_payment',
        note: note,
        createdAt: DateTime.now(),
      ),
    );
    _changes.add(null);
  }

  /// Plays the admin's part for tests: records that [inviteeUid]'s first
  /// order was delivered and pays any reward the inviter has now earned.
  void completeFirstOrder(String inviteeUid) {
    final entry = _referrals[inviteeUid];
    if (entry == null || entry.referral.status != ReferralStatus.joined) return;
    _referrals[inviteeUid] = (
      referrer: entry.referrer,
      referral: Referral(
        friend: entry.referral.friend,
        status: ReferralStatus.ordered,
        createdAt: entry.referral.createdAt,
      ),
    );
    final wallet = _wallets[entry.referrer] ?? Wallet.empty;
    final invites = wallet.successfulInvites + 1;
    final reached = ReferralRules.milestonesReached(invites);
    final due = reached - wallet.rewardedMilestones;
    _wallets[entry.referrer] = Wallet(
      balancePaise: wallet.balancePaise + due * ReferralRules.rewardPaise,
      successfulInvites: invites,
      rewardedMilestones: reached,
    );
    for (var i = 0; i < due; i++) {
      (_history[entry.referrer] ??= []).insert(
        0,
        WalletEntry(
          amountPaise: ReferralRules.rewardPaise,
          type: 'referral_reward',
          note: 'Invite reward: $invites friends ordered',
          createdAt: DateTime.now(),
        ),
      );
    }
    _changes.add(null);
  }
}
