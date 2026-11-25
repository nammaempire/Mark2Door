import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../store/application/store_providers.dart';
import '../application/address_book.dart';
import '../application/checkout_controller.dart';
import '../application/coupon_offers.dart';
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

  /// The pincode box shown under a saved address, so the pincode can be
  /// changed on this page without opening the address list.
  final _savedPin = TextEditingController();
  Address? _savedPinFor;
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
      pincode: ref.read(deliveryPincodeProvider) ?? '',
      name: ref.read(customerNameProvider),
    );
  }

  @override
  void dispose() {
    _fields.dispose();
    _savedPin.dispose();
    _couponController.dispose();
    super.dispose();
  }

  /// "Apply" on a coupon in the list: the code goes into the box and is
  /// applied, exactly as if the shopper had typed it.
  void _useCoupon(String code) {
    _couponController.text = code;
    _applyCoupon();
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

  /// True when a saved address is shown with a pincode box under it.
  bool get _editsSavedPin =>
      !ref.read(cartProvider).courier && !ref.read(outOfAreaProvider);

  /// "Delivery pincode": checked as soon as six digits are typed.
  Widget _pincodeBox(
    TextEditingController controller,
    AsyncValue<bool>? served,
    bool notServed,
    String typed,
  ) {
    return TextFormField(
      key: const ValueKey('checkout-pincode-field'),
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      validator: Validators.pincode,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: 'Delivery pincode',
        prefixIcon: const Icon(Icons.location_on_outlined),
        suffixIcon: served == null
            ? null
            : served.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : Icon(
                    notServed
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_rounded,
                    color: notServed
                        ? AppColors.danger
                        : AppColors.success,
                  ),
        helperText: served?.valueOrNull == true
            ? 'We deliver to $typed'
            : null,
      ),
    );
  }

  Future<void> _placeOrder() async {
    FocusScope.of(context).unfocus();
    // A saved address is used as it is; otherwise the form is the address.
    var address = ref.read(checkoutAddressProvider);
    if (address == null) {
      if (!_formKey.currentState!.validate()) return;
      // Instant orders go to the pincode typed on this page; outstation
      // orders to the shopper's own pincode.
      address = _fields.toAddress(
        pincodeOverride: ref.read(cartProvider).courier
            ? ref.read(deliveryPincodeProvider) ?? ''
            : null,
      );
    } else if (_editsSavedPin) {
      // The pincode typed under the saved address replaces that
      // address's pincode. Its map pin belonged to the old place.
      final pin = _savedPin.text.trim();
      if (pin.length == 6 && pin != address.pincode) {
        final book = ref.read(addressBookProvider);
        final index = book.addresses.indexOf(address);
        address = Address(
          name: address.name,
          phone: address.phone,
          line1: address.line1,
          landmark: address.landmark,
          pincode: pin,
        );
        if (index >= 0) {
          ref.read(addressBookProvider.notifier).replace(index, address);
        }
      }
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
    final pincode = ref.watch(deliveryPincodeProvider) ?? '';
    final saved = ref.watch(checkoutAddressProvider);
    final outOfArea = ref.watch(outOfAreaProvider);
    final settings = ref.watch(storeSettingsProvider);
    // Courier orders are paid online only.
    if (cart.courier && _method == PaymentMethod.cod) {
      _method = PaymentMethod.online;
    }
    // Instant delivery only reaches served pincodes. The pincode is the
    // saved address's, or the one typed in the box on this page; while it
    // is not served, paying is switched off.
    if (saved != _savedPinFor) {
      final first = _savedPinFor == null;
      _savedPinFor = saved;
      if (first) {
        _savedPin.text = saved?.pincode ?? '';
      } else {
        // Another address was picked: show its pincode after this build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _savedPin.text = saved?.pincode ?? '');
        });
      }
    }
    final pinBox = saved == null ? _fields.pincode : _savedPin;
    final typed = pinBox.text.trim();
    final checkPincode = cart.courier
        ? null
        : saved != null && !_editsSavedPin
            ? saved.pincode
            : typed;
    final served = checkPincode != null && checkPincode.length == 6
        ? ref.watch(pincodeServedProvider(checkPincode))
        : null;
    final notServed = served?.valueOrNull == false;
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
                    if (saved != null) ...[
                      _SavedAddressCard(address: saved),
                      if (_editsSavedPin) ...[
                        const SizedBox(height: 10),
                        _pincodeBox(_savedPin, served, notServed, typed),
                      ],
                    ] else ...[
                      AddressFormFields(fields: _fields),
                      if (!cart.courier)
                        // The pincode can be changed right here; it is
                        // checked as soon as six digits are typed.
                        _pincodeBox(_fields.pincode, served, notServed, typed)
                      else
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.location_on_outlined,
                              color: AppColors.primary),
                          title: Text('Pincode $pincode'),
                          subtitle: Text(
                            cart.courier
                                ? 'Outstation delivery in ${settings.courierEta}'
                                : outOfArea
                                    ? 'Instant delivery to an address in '
                                        'this pincode'
                                    : 'Your delivery pincode',
                          ),
                          trailing: outOfArea
                              ? null
                              : TextButton(
                                  onPressed: () =>
                                      context.push(Routes.pincode),
                                  child: const Text('Change'),
                                ),
                        ),
                      ),
                    ],
                    if (notServed)
                      Container(
                        key: const ValueKey('pincode-not-served'),
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDECEC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF3B8B8)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_off_rounded,
                              color: AppColors.danger,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Sorry, we do not deliver to $checkPincode '
                                'yet. Enter a pincode we deliver to.',
                                style: const TextStyle(
                                  height: 1.35,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SectionLabel('Payment method'),
                    Card(
                      child: Column(
                        children: [
                          _methodTile(
                            PaymentMethod.online,
                            Icons.account_balance_wallet_outlined,
                            'UPI, cards, netbanking',
                          ),
                          if (!cart.courier) ...[
                            const Divider(indent: 16, endIndent: 16),
                            _methodTile(
                              PaymentMethod.cod,
                              Icons.payments_outlined,
                              'Pay when your order arrives',
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (cart.courier) ...[
                      const SizedBox(height: 12),
                      HintBanner(
                        key: const ValueKey('courier-hint'),
                        'Delivered in ${settings.courierEta}. '
                        'Outstation orders are paid online.',
                      ),
                    ],
                    if (_method == PaymentMethod.online &&
                        !Env.useFirebase) ...[
                      const SizedBox(height: 12),
                      const HintBanner(
                        'Sample-data mode: online payment opens a test sheet '
                        'where you pick the result.',
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
                    if (_coupon == null)
                      _CouponList(
                        onApply: _applyingCoupon ? null : _useCoupon,
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
                      courier: cart.courier,
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
                // No paying while the pincode is not one we deliver to.
                onPressed: placing ||
                        notServed ||
                        (saved != null && _editsSavedPin && typed.length != 6)
                    ? null
                    : _placeOrder,
                child: LoadingLabel(
                  notServed
                      ? 'We do not deliver to this pincode'
                      : _method == PaymentMethod.cod || payable == 0
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
/// "View coupons": opens the store's coupons as cards. Those that can be
/// used on this cart come first with an Apply button; the rest are greyed
/// out at the bottom with the reason.
class _CouponList extends ConsumerStatefulWidget {
  const _CouponList({required this.onApply});

  /// Null while a coupon is being checked.
  final ValueChanged<String>? onApply;

  @override
  ConsumerState<_CouponList> createState() => _CouponListState();
}

class _CouponListState extends ConsumerState<_CouponList> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final offers = ref.watch(couponOffersProvider);
    final list = offers.valueOrNull ?? const <CouponOffer>[];
    // Nothing to show when the store has no coupons.
    if (offers.hasValue && list.isEmpty) return const SizedBox.shrink();
    final usable = list.where((o) => o.usable).length;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              key: const ValueKey('coupon-list-toggle'),
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_offer_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        !offers.hasValue
                            ? 'View coupons'
                            : usable == 0
                                ? 'View coupons'
                                : usable == 1
                                    ? '1 coupon you can use'
                                    : '$usable coupons you can use',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_open) ...[
              const Divider(height: 1),
              offers.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, __) => Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextButton.icon(
                    onPressed: () => ref.invalidate(couponOffersProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Could not load coupons. Try again'),
                  ),
                ),
                data: (items) => Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Column(
                    key: const ValueKey('coupon-list'),
                    children: [
                      for (final offer in items)
                        _CouponOfferCard(
                          offer: offer,
                          onApply: widget.onApply,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CouponOfferCard extends StatelessWidget {
  const _CouponOfferCard({required this.offer, required this.onApply});

  final CouponOffer offer;
  final ValueChanged<String>? onApply;

  @override
  Widget build(BuildContext context) {
    final coupon = offer.coupon;
    final usable = offer.usable;
    final tint = usable ? AppColors.primary : AppColors.textMuted;
    return Opacity(
      // Coupons that cannot be used are greyed out.
      opacity: usable ? 1 : 0.55,
      child: Container(
        key: ValueKey('coupon-card-${coupon.code}'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: usable ? AppColors.primarySoft : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: usable ? const Color(0xFFE9B9C4) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: tint),
                        ),
                        child: Text(
                          coupon.code,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: tint,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          coupon.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    usable
                        ? 'You save ${formatPaise(offer.savingPaise)} on '
                            'this order'
                        : offer.problem!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: usable ? FontWeight.w600 : FontWeight.w400,
                      color: usable ? AppColors.success : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (usable)
              TextButton(
                key: ValueKey('coupon-apply-${coupon.code}'),
                onPressed:
                    onApply == null ? null : () => onApply!(coupon.code),
                child: const Text(
                  'APPLY',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
