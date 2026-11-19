import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/auth_header.dart';
import '../../cart/application/cart_controller.dart';
import '../../cart/presentation/bill_summary.dart';
import '../../orders/domain/order.dart';
import '../../rewards/application/rewards_providers.dart';
import '../../service_area/application/pincode_controller.dart';
import '../application/address_book.dart';
import '../application/checkout_controller.dart';
import '../domain/address.dart';
import 'address_sheets.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();

  /// Used only for a shopper's first order, before any address is saved.
  late final AddressFields _fields;
  PaymentMethod _method = PaymentMethod.online;

  /// On by default whenever there is wallet money to use.
  bool _useWallet = true;

  @override
  void initState() {
    super.initState();
    _fields = AddressFields.from(
      null,
      phone: ref.read(currentUserProvider)?.phone ?? '',
      pincode: ref.read(pincodeProvider) ?? '',
    );
  }

  @override
  void dispose() {
    _fields.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    FocusScope.of(context).unfocus();
    // A saved address is used as it is; otherwise the form is the address.
    var address = ref.read(addressBookProvider).selected;
    if (address == null) {
      if (!_formKey.currentState!.validate()) return;
      address = _fields.toAddress(
        pincodeOverride: ref.read(pincodeProvider) ?? '',
      );
    }
    final result = await ref
        .read(checkoutControllerProvider.notifier)
        .placeOrder(address: address, method: _method, useWallet: _useWallet);
    if (!mounted || result == null) return;
    context.go(Routes.orderResult(result.orderId, result.outcome));
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final pincode = ref.watch(pincodeProvider) ?? '';
    final saved = ref.watch(addressBookProvider).selected;
    final walletBalance = ref.watch(walletBalanceProvider);
    final walletApplied = _useWallet
        ? walletAmountFor(cart.totalPaise, walletBalance)
        : 0;
    final payable = cart.totalPaise - walletApplied;
    final placing = ref.watch(checkoutControllerProvider).isLoading;

    ref.listen(checkoutControllerProvider, (_, next) {
      final error = next.error;
      if (error is CheckoutFailure) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
      }
    });

    if (cart.isEmpty && !placing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: EmptyState(
          icon: Icons.shopping_bag_outlined,
          title: 'Your cart is empty',
          actionLabel: 'Start shopping',
          onAction: () => context.go(Routes.home),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: AbsorbPointer(
        absorbing: placing,
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    const SectionLabel('Delivery address'),
                    if (saved != null)
                      _SavedAddressCard(address: saved)
                    else ...[
                      AddressFormFields(fields: _fields),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.location_on_outlined,
                              color: AppColors.primary),
                          title: Text('Pincode $pincode'),
                          subtitle: const Text('Your delivery pincode'),
                          trailing: TextButton(
                            onPressed: () => context.push(Routes.pincode),
                            child: const Text('Change'),
                          ),
                        ),
                      ),
                    ],
                    const SectionLabel('Payment method'),
                    Card(
                      child: Column(
                        children: [
                          _methodTile(
                            PaymentMethod.online,
                            Icons.account_balance_wallet_outlined,
                            'UPI, cards, netbanking',
                          ),
                          const Divider(indent: 16, endIndent: 16),
                          _methodTile(
                            PaymentMethod.cod,
                            Icons.payments_outlined,
                            'Pay when your order arrives',
                          ),
                        ],
                      ),
                    ),
                    if (_method == PaymentMethod.online && !Env.useRazorpay) ...[
                      const SizedBox(height: 12),
                      const HintBanner(
                        'No Razorpay key is set, so online payment opens a '
                        'test sheet where you pick the result.',
                      ),
                    ],
                    if (walletBalance > 0) ...[
                      const SizedBox(height: 12),
                      Card(
                        child: SwitchListTile(
                          key: const ValueKey('use-wallet-switch'),
                          secondary: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: AppColors.primary,
                          ),
                          title: const Text(
                            'Use m2d wallet',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${formatPaise(walletBalance)} available',
                          ),
                          value: _useWallet,
                          onChanged: (v) => setState(() => _useWallet = v),
                        ),
                      ),
                    ],
                    const SectionLabel('Order summary'),
                    OrderSummaryCard(
                      subtotalPaise: cart.subtotalPaise,
                      mrpTotalPaise: cart.mrpTotalPaise,
                      deliveryFeePaise: cart.deliveryFeePaise,
                      handlingFeePaise: cart.handlingFeePaise,
                      rainFeePaise: cart.rainFeePaise,
                      walletAppliedPaise: walletApplied,
                      totalPaise: cart.totalPaise,
                    ),
                  ],
                ),
              ),
            ),
            BottomActionBar(
              child: FilledButton(
                key: const ValueKey('place-order-button'),
                onPressed: placing ? null : _placeOrder,
                child: LoadingLabel(
                  _method == PaymentMethod.cod || payable == 0
                      ? 'Place order  ·  ${formatPaise(payable)}'
                      : 'Pay ${formatPaise(payable)}',
                  loading: placing,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodTile(PaymentMethod method, IconData icon, String subtitle) {
    final selected = _method == method;
    return ListTile(
      key: ValueKey('method-${method.name}'),
      onTap: () => setState(() => _method = method),
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        method.label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_off_rounded,
        color: selected ? AppColors.primary : AppColors.textMuted,
      ),
    );
  }
}

/// The saved address the order will go to, with a way to pick another or
/// add a new one. Shoppers who have ordered before never retype it.
class _SavedAddressCard extends StatelessWidget {
  const _SavedAddressCard({required this.address});

  final Address address;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('saved-address-card'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.home_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address.singleLine,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '+91 ${address.phone}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              key: const ValueKey('change-address-button'),
              onPressed: () => showAddressPicker(context),
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }
}
