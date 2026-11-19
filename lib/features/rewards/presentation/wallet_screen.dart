import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../cart/presentation/bill_summary.dart';
import '../application/rewards_providers.dart';
import '../domain/rewards.dart';

/// m2d wallet: the balance and everything that went in or out.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider).valueOrNull ?? Wallet.empty;
    final history = ref.watch(walletHistoryProvider);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('m2d wallet')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                const Text(
                  'Balance',
                  style: TextStyle(fontSize: 13, color: Color(0xCCFFFFFF)),
                ),
                const SizedBox(height: 2),
                Text(
                  formatPaise(wallet.balancePaise),
                  key: const ValueKey('wallet-balance'),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Switch on "Use m2d wallet" at checkout to pay with it.',
                  style: TextStyle(fontSize: 13, color: Color(0xE6FFFFFF)),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SectionLabel('History'),
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: history,
              onRetry: () => ref.invalidate(walletHistoryProvider),
              data: (entries) => entries.isEmpty
                  ? const EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Nothing here yet',
                      message: 'Rewards from inviting friends will show up '
                          'here.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _EntryTile(entries[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile(this.entry);

  final WalletEntry entry;

  @override
  Widget build(BuildContext context) {
    final moneyIn = entry.amountPaise >= 0;
    final color = moneyIn ? AppColors.success : AppColors.textDark;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              moneyIn ? AppColors.successSoft : AppColors.primarySoft,
          child: Icon(
            switch (entry.type) {
              'referral_reward' => Icons.card_giftcard_rounded,
              'order_refund' => Icons.replay_rounded,
              _ => Icons.shopping_bag_outlined,
            },
            color: moneyIn ? AppColors.success : AppColors.primary,
          ),
        ),
        title: Text(
          entry.note.isEmpty ? 'Wallet update' : entry.note,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(formatOrderDate(entry.createdAt)),
        trailing: Text(
          '${moneyIn ? '+' : '-'} ${formatPaise(entry.amountPaise.abs())}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}
