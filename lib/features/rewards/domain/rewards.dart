import 'package:flutter/foundation.dart';

/// Invite-and-earn terms. A reward is paid each time the number of friends
/// whose first order was delivered reaches the next milestone: after 1
/// friend, then 2 more, 3 more, 4 more and 5 more (15 friends in all).
///
/// The admin web pays the rewards and uses the same numbers; change them in
/// both places together.
abstract final class ReferralRules {
  static const List<int> milestones = [1, 3, 6, 10, 15];
  static const int rewardPaise = 2500;

  static int get maxInvites => milestones.last;
  static int get maxRewardPaise => rewardPaise * milestones.length;

  /// How many milestones [successfulInvites] has reached.
  static int milestonesReached(int successfulInvites) =>
      milestones.where((m) => successfulInvites >= m).length;

  /// Friends still needed for the next reward; 0 once every reward is won.
  static int invitesToNextReward(int successfulInvites) {
    for (final m in milestones) {
      if (successfulInvites < m) return m - successfulInvites;
    }
    return 0;
  }
}

/// A shopper's m2d wallet (`wallets/{uid}`).
@immutable
class Wallet {
  const Wallet({
    this.balancePaise = 0,
    this.successfulInvites = 0,
    this.rewardedMilestones = 0,
  });

  static const empty = Wallet();

  final int balancePaise;

  /// Invited friends whose first order has been delivered.
  final int successfulInvites;

  /// Rewards already paid, so none is ever paid twice.
  final int rewardedMilestones;

  int get earnedPaise => rewardedMilestones * ReferralRules.rewardPaise;

  factory Wallet.fromMap(Map<String, dynamic> map) => Wallet(
        balancePaise: (map['balancePaise'] as num?)?.toInt() ?? 0,
        successfulInvites: (map['successfulInvites'] as num?)?.toInt() ?? 0,
        rewardedMilestones: (map['rewardedMilestones'] as num?)?.toInt() ?? 0,
      );
}

/// One line of wallet history (`wallets/{uid}/transactions/{id}`).
@immutable
class WalletEntry {
  const WalletEntry({
    required this.amountPaise,
    required this.type,
    required this.note,
    required this.createdAt,
  });

  /// Positive for money in, negative for money spent.
  final int amountPaise;

  /// `referral_reward`, `order_payment` or `order_refund`.
  final String type;
  final String note;
  final DateTime createdAt;

  factory WalletEntry.fromMap(Map<String, dynamic> map) => WalletEntry(
        amountPaise: (map['amountPaise'] as num?)?.toInt() ?? 0,
        type: map['type'] as String? ?? '',
        note: map['note'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['createdAt'] as num?)?.toInt() ?? 0,
        ),
      );
}

enum ReferralStatus {
  /// Signed up with the code; has not had an order delivered yet.
  joined,

  /// First order delivered: counts towards the inviter's rewards.
  ordered,

  /// Had already ordered before using the code, so does not count.
  ineligible,
}

/// A friend who joined with the shopper's code (`referrals/{inviteeUid}`).
@immutable
class Referral {
  const Referral({
    required this.friend,
    required this.status,
    required this.createdAt,
  });

  /// Friend's number with the middle hidden, e.g. "98••••3210".
  final String friend;
  final ReferralStatus status;
  final DateTime createdAt;

  factory Referral.fromMap(Map<String, dynamic> map) => Referral(
        friend: map['inviteePhone'] as String? ?? 'A friend',
        status: ReferralStatus.values.firstWhere(
          (s) => s.name == map['status'],
          orElse: () => ReferralStatus.joined,
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['createdAt'] as num?)?.toInt() ?? 0,
        ),
      );
}

/// Error with a message that is safe to show to the shopper.
class RewardsFailure implements Exception {
  const RewardsFailure(this.message);

  final String message;

  @override
  String toString() => 'RewardsFailure($message)';
}

/// "+919876543210" or "9876543210" -> "98••••3210".
String maskPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 10) return 'A friend';
  final local = digits.substring(digits.length - 10);
  return '${local.substring(0, 2)}••••${local.substring(6)}';
}
