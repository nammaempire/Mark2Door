import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launchers.dart';
import '../../../core/widgets/shimmer.dart';
import '../../auth/application/auth_providers.dart';
import '../../cart/presentation/bill_summary.dart';
import '../application/rewards_providers.dart';
import '../domain/rewards.dart';

/// Invite and earn: the shopper's code to share, progress towards each
/// reward, the friends who joined, and where to enter a friend's code.
class InviteScreen extends ConsumerWidget {
  const InviteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider).valueOrNull ?? Wallet.empty;
    final code = ref.watch(inviteCodeProvider);
    final referrals = ref.watch(referralsProvider);
    final usedCode = ref.watch(hasUsedCodeProvider).valueOrNull ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Invite and earn')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Hero(code: code),
          const SectionLabel('Your rewards'),
          _Progress(wallet: wallet),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              key: const ValueKey('open-wallet-tile'),
              leading: const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'm2d wallet',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('${formatPaise(wallet.balancePaise)} to spend'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(Routes.wallet),
            ),
          ),
          const SectionLabel('Friends you invited'),
          referrals.when(
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Shimmer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox.line(width: 160, height: 14),
                      SizedBox(height: 12),
                      SkeletonBox.line(width: 200),
                    ],
                  ),
                ),
              ),
            ),
            error: (_, __) => const _Note(
              "Couldn't load your invites. Check your connection.",
            ),
            data: (friends) => friends.isEmpty
                ? const _Note(
                    'Nobody has joined with your code yet. Share it to get '
                    'started.',
                  )
                : Card(
                    child: Column(
                      children: [
                        for (final (i, f) in friends.indexed) ...[
                          if (i > 0) const Divider(indent: 16, endIndent: 16),
                          _FriendTile(friend: f),
                        ],
                      ],
                    ),
                  ),
          ),
          if (!usedCode) ...[
            const SectionLabel('Have a code from a friend?'),
            const _EnterCode(),
          ],
          const SectionLabel('How it works'),
          const _Note(
            '1. Share your code with friends who are new to mart2door.\n'
            '2. They enter it here before placing their first order.\n'
            '3. When their first order is delivered, it counts for you.\n'
            '4. Rewards are added to your m2d wallet and can be used on any '
            'order.',
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.code});

  final AsyncValue<String> code;

  String _message(String code) =>
      'Shop groceries on ${AppConfig.appName} and get them delivered to '
      'your door. Use my invite code $code before your first order.';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final value = code.valueOrNull;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.primaryLight, palette.primaryDark],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: palette.elevation,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earn up to ${formatPaise(ReferralRules.maxRewardPaise)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Invite friends. Get ${formatPaise(ReferralRules.rewardPaise)} '
            'in your m2d wallet at each step, as their first orders are '
            'delivered.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xE6FFFFFF),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
            decoration: BoxDecoration(
              color: const Color(0x26FFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x66FFFFFF)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your invite code',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xCCFFFFFF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (value != null)
                        Text(
                          value,
                          key: const ValueKey('invite-code'),
                          style: const TextStyle(
                            fontSize: 24,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        )
                      else if (code.hasError)
                        const Text(
                          'Not available right now',
                          style: TextStyle(color: Colors.white),
                        )
                      else
                        const Shimmer(
                          child: SkeletonBox(width: 130, height: 28),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('copy-code-button'),
                  tooltip: 'Copy code',
                  color: Colors.white,
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: value == null
                      ? null
                      : () => Launchers.copy(
                            context,
                            value,
                            confirmation: 'Invite code copied',
                          ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const ValueKey('share-code-button'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: palette.primaryDark,
            ),
            onPressed: value == null
                ? null
                : () => Launchers.shareOnWhatsApp(context, _message(value)),
            icon: const Icon(Icons.share_rounded),
            label: const Text('Share on WhatsApp'),
          ),
        ],
      ),
    );
  }
}

/// The five reward steps, ticked as they are reached.
class _Progress extends StatelessWidget {
  const _Progress({required this.wallet});

  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    final invites = wallet.successfulInvites;
    final toNext = ReferralRules.invitesToNextReward(invites);
    return Card(
      key: const ValueKey('reward-progress'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$invites of ${ReferralRules.maxInvites} friends ordered',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Text(
                  '${formatPaise(wallet.earnedPaise)} earned',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (invites / ReferralRules.maxInvites).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppColors.primarySoft,
              ),
            ),
            const SizedBox(height: 14),
            for (final (i, at) in ReferralRules.milestones.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Icon(
                      invites >= at
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 22,
                      color:
                          invites >= at ? AppColors.success : AppColors.border,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        i == 0
                            ? '1 friend orders'
                            : '$at friends have ordered',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              invites >= at ? FontWeight.w700 : FontWeight.w500,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Text(
                      '+ ${formatPaise(ReferralRules.rewardPaise)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: invites >= at
                            ? AppColors.success
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              toNext == 0
                  ? 'You have earned every reward. Thank you for spreading '
                      'the word.'
                  : '$toNext more ${toNext == 1 ? 'friend' : 'friends'} to '
                      'your next ${formatPaise(ReferralRules.rewardPaise)}.',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend});

  final Referral friend;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (friend.status) {
      ReferralStatus.ordered => ('Counted', AppColors.success),
      ReferralStatus.joined => ('Waiting for first order', AppColors.warning),
      ReferralStatus.ineligible => ('Not a new customer', AppColors.textMuted),
    };
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: AppColors.primarySoft,
        child: Icon(Icons.person_rounded, color: AppColors.primary),
      ),
      title: Text(
        friend.friend,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('Joined ${formatOrderDate(friend.createdAt)}'),
      trailing: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _EnterCode extends ConsumerStatefulWidget {
  const _EnterCode();

  @override
  ConsumerState<_EnterCode> createState() => _EnterCodeState();
}

class _EnterCodeState extends ConsumerState<_EnterCode> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final user = ref.read(currentUserProvider);
    if (_saving || user == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(rewardsRepositoryProvider)
          .applyCode(user, _controller.text);
      ref.invalidate(hasUsedCodeProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Invite code added. Happy shopping!')),
      );
    } on RewardsFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't add that code. Try again.");
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter it before your first order so your friend gets the '
              'credit.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('friend-code-field'),
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              onSubmitted: (_) => _apply(),
              decoration: InputDecoration(
                hintText: 'ABC123',
                counterText: '',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const ValueKey('apply-code-button'),
              onPressed: _saving ? null : _apply,
              child: Text(_saving ? 'Adding…' : 'Add code'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
