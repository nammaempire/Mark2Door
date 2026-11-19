import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/domain/app_user.dart';
import '../domain/rewards.dart';
import 'rewards_repository.dart';

/// Collections:
/// - `users/{uid}`: `phone`, `referralCode`, `referredBy`
/// - `referral_codes/{code}`: `uid`, so a code can be looked up
/// - `referrals/{inviteeUid}`: who invited this shopper, and its status
/// - `wallets/{uid}` and `wallets/{uid}/transactions/{id}`
///
/// The shopper's app only ever takes money out of a wallet (when paying for
/// an order). Rewards and refunds are paid in by the admin web, and the
/// security rules allow nothing else.
class FirestoreRewardsRepository implements RewardsRepository {
  FirestoreRewardsRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);
  DocumentReference<Map<String, dynamic>> _wallet(String uid) =>
      _db.collection('wallets').doc(uid);

  @override
  Future<String> inviteCode(AppUser user) async {
    final existing = (await _user(user.uid).get()).data()?['referralCode'];
    if (existing is String && existing.isNotEmpty) return existing;

    // A code is claimed by creating `referral_codes/{code}`; the rules
    // refuse to overwrite one, so a clash simply fails and we try another.
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = newInviteCode();
      try {
        await _db.collection('referral_codes').doc(code).set({'uid': user.uid});
      } on FirebaseException {
        continue;
      }
      await _user(user.uid).set(
        {
          'phone': user.phone,
          'referralCode': code,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        },
        SetOptions(merge: true),
      );
      return code;
    }
    throw const RewardsFailure("Couldn't create your invite code. Try again.");
  }

  @override
  Stream<Wallet> watchWallet(String uid) => _wallet(uid).snapshots().map(
        (doc) => doc.data() == null ? Wallet.empty : Wallet.fromMap(doc.data()!),
      );

  @override
  Stream<List<WalletEntry>> watchHistory(String uid) => _wallet(uid)
      .collection('transactions')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => WalletEntry.fromMap(d.data()))
            .toList(growable: false),
      );

  @override
  Stream<List<Referral>> watchReferrals(String uid) => _db
      .collection('referrals')
      .where('referrerUid', isEqualTo: uid)
      .snapshots()
      .map(
        (snap) => snap.docs.map((d) => Referral.fromMap(d.data())).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  @override
  Future<bool> hasUsedCode(String uid) async =>
      (await _db.collection('referrals').doc(uid).get()).exists;

  @override
  Future<void> applyCode(AppUser user, String code) async {
    final clean = normaliseCode(code);
    if (clean.isEmpty) {
      throw const RewardsFailure('Enter the code your friend shared.');
    }
    final owner =
        (await _db.collection('referral_codes').doc(clean).get()).data()?['uid'];
    if (owner is! String) {
      throw const RewardsFailure("That code doesn't match anyone.");
    }
    if (owner == user.uid) {
      throw const RewardsFailure("You can't use your own code.");
    }
    if (await hasUsedCode(user.uid)) {
      throw const RewardsFailure('You have already used an invite code.');
    }
    final orders = await _db
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (orders.docs.isNotEmpty) {
      throw const RewardsFailure(
        'Invite codes are for new customers, before their first order.',
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _db.batch()
      ..set(_db.collection('referrals').doc(user.uid), {
        'referrerUid': owner,
        'inviteeUid': user.uid,
        'inviteePhone': maskPhone(user.phone),
        'code': clean,
        'status': ReferralStatus.joined.name,
        'createdAt': now,
      })
      ..set(
        _user(user.uid),
        {'phone': user.phone, 'referredBy': owner},
        SetOptions(merge: true),
      );
    await batch.commit();
  }
}
