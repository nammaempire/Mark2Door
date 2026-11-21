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
import '../../profile/application/customer_name.dart';
import '../../service_area/application/pincode_controller.dart';
import '../application/address_book.dart';
import '../application/checkout_controller.dart';
import '../../../core/providers.dart';
import '../domain/address.dart';
import '../domain/coupon.dart';
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

  /// Off until the shopper ticks "Use m2d wallet".
  bool _useWallet = false;

  final _couponController = TextEditingController();
  Coupon? _coupon;
  String? _couponError;
  bool _applyingCoupon = false;

  @override
  void initState() {
    super.initState();
    _fields = AddressFields.from(
      null,
      phone: ref.read(currentUserProvider)?.phone ?? '',
      pincode: ref.read(pincodeProvider) ?? '',
      name: ref.read(customerNameProvider),
    );
  }

  @override
  void dispose() {
    _fields.dispose();
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon() async {
    FocusScope.of(context).unfocus();
    final code = Coupon.normalise(_couponController.text);
    if (code.isEmpty) {
      setState(() => _couponError = 'Enter a coupon code.');
      return;
    }
    setState(() {
      _applyingCoupon = true;
      _couponError = null;
    });
    String? error;
    Coupon? coupon;
    try {
      final repo = ref.read(couponRepositoryProvider);
      coupon = await repo.find(code);
      final uid = ref.read(currentUserProvider)?.uid ?? '';
      if (coupon == null) {
        error = 'This coupon code is not valid.';
      } else {
        error = coupon.problemFor(
          ref.read(cartProvider).subtotalPaise,
          DateTime.now(),
        );
        if (error == null &&
            coupon.oncePerCustomer &&
            await repo.alreadyUsed(code, uid)) {
          error = 'You have already used this coupon.';
        }
      }
    } catch (_) {
      error = 'Could not check this coupon. Try again.';
    }
    if (!mounted) return;
    setState(() {
      _applyingCoupon = false;
      _couponError = error;
      _coupon = error == null ? coupon : null;
    });
  }

  void _removeCoupon() => setState(() {
        _coupon = null;
        _couponError = null;
        _couponController.clear();
      });

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
        .placeOrder(
          address: address,
          method: _method,
          useWallet: _useWallet,
          coupon: _coupon,
        );
    if (!mounted || result == null) return;
    context.go(Routes.orderResult(result.orderId, result.outcome));
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final pincode = ref.watch(pincodeProvider) ?? '';
    final saved = ref.watch(addressBookProvider).selected;
    final walletBalance = ref.watch(walletBalanceProvider);
    // An applied coupon stops counting if the cart drops below its minimum.
    final couponProblem =
        _coupon?.problemFor(cart.subtotalPaise, DateTime.now());
    final discount = _coupon == null || couponProblem != null
        ? 0
        : _coupon!.discountFor(cart.subtotalPaise);
    final total = cart.totalPaise - discount;
    final walletApplied =
        _useWallet ? walletAmountFor(total, walletBalance) : 0;
    final payable = total - walletApplied;
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
                    const SectionLabel('Apply coupon'),
                    _CouponCard(
                      controller: _couponController,
                      applied: _coupon,
                      discountPaise: discount,
                      error: _couponError ?? couponProblem,
                      busy: _applyingCoupon,
                      onApply: _applyCoupon,
                      onRemove: _removeCoupon,
                    ),
                    if (walletBalance > 0) ...[
                      const SectionLabel('m2d wallet'),
                      Card(
                        child: CheckboxListTile(
                          key: const ValueKey('use-wallet-checkbox'),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'Use m2d wallet',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            _useWallet
                                ? '${formatPaise(walletApplied)} will be used '
                                    'from ${formatPaise(walletBalance)}'
                                : '${formatPaise(walletBalance)} available',
                          ),
                          secondary: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: AppColors.primary,
                          ),
                          value: _useWallet,
                          onChanged: (v) =>
                              setState(() => _useWallet = v ?? false),
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
                      couponCode: _coupon?.code,
                      couponDiscountPaise: discount,
                      totalPaise: total,
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

/// "Apply coupon": a code field with an Apply button, which turns into a
/// green confirmation once a coupon is in use.
class _CouponCard extends StatelessWidget {
  const _CouponCard({
    required this.controller,
    required this.applied,
    required this.discountPaise,
    required this.error,
    required this.busy,
    required this.onApply,
    required this.onRemove,
  });

  final TextEditingController controller;
  final Coupon? applied;
  final int discountPaise;
  final String? error;
  final bool busy;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final coupon = applied;
    if (coupon != null) {
      final counting = discountPaise > 0;
      return Card(
        key: const ValueKey('coupon-applied'),
        child: ListTile(
          leading: Icon(
            counting ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color: counting ? AppColors.success : AppColors.warning,
          ),
          title: Text(
            counting
                ? '${coupon.code} applied'
                : '${coupon.code} is not being used',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            counting
                ? 'You save ${formatPaise(discountPaise)} (${coupon.label})'
                : error ?? '',
          ),
          trailing: TextButton(
            key: const ValueKey('remove-coupon-button'),
            onPressed: onRemove,
            child: const Text('Remove'),
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('coupon-field'),
                controller: controller,
                enabled: !busy,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onApply(),
                decoration: InputDecoration(
                  hintText: 'Enter coupon code',
                  prefixIcon: const Icon(Icons.local_offer_outlined),
                  errorText: error,
                  errorMaxLines: 2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton(
                key: const ValueKey('apply-coupon-button'),
                onPressed: busy ? null : onApply,
                child: Text(busy ? 'Checking' : 'Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
