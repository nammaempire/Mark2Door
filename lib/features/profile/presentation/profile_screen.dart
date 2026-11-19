import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/auth_header.dart';
import '../../checkout/application/address_book.dart';
import '../../rewards/application/rewards_providers.dart';
import '../../rewards/domain/rewards.dart';
import '../../service_area/application/pincode_controller.dart';
import '../../support/data/content_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Your cart will be kept on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      // The router redirect sends the user to login once the session ends.
      await ref.read(authRepositoryProvider).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final pincode = ref.watch(pincodeProvider);
    final address = ref.watch(savedAddressProvider);
    final walletBalance = ref.watch(walletBalanceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: const CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primarySoft,
                child: Icon(Icons.person_rounded, color: AppColors.primary),
              ),
              title: Text(
                address?.name.isNotEmpty ?? false
                    ? address!.name
                    : 'mart2door shopper',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(user?.phone ?? ''),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey('invite-tile'),
                  leading: const Icon(
                    Icons.card_giftcard_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Invite and earn',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Up to ${formatPaise(ReferralRules.maxRewardPaise)} for '
                    'inviting friends',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(Routes.invite),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  key: const ValueKey('wallet-tile'),
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('m2d wallet'),
                  subtitle: Text(formatPaise(walletBalance)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(Routes.wallet),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Delivery pincode'),
                  subtitle: Text(pincode ?? 'Not set'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(Routes.pincode),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text('Saved address'),
                  subtitle: Text(
                    address?.singleLine ?? 'Added when you place an order',
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('Your orders'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.go(Routes.orders),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey('help-tile'),
                  leading: const Icon(Icons.help_outline_rounded),
                  title: const Text('Help and support'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(Routes.help),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  key: const ValueKey('terms-tile'),
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms and conditions'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      context.push(Routes.legal(LegalPage.termsId)),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  key: const ValueKey('privacy-tile'),
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy policy'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      context.push(Routes.legal(LegalPage.privacyId)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              key: const ValueKey('logout-tile'),
              leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: const Text(
                'Log out',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => _confirmLogout(context, ref),
            ),
          ),
          if (!Env.useFirebase) ...[
            const SizedBox(height: 16),
            const HintBanner(
              'Sample-data mode: products, login and orders are stored on '
              'this device only. Connect Firebase to go live (see README).',
            ),
          ],
          const SizedBox(height: 24),
          const Center(
            child: Text(
              '${AppConfig.appName} · v1.0.0',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
