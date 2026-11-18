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
import '../../service_area/application/pincode_controller.dart';
import '../application/checkout_controller.dart';
import '../domain/address.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _line1;
  late final TextEditingController _landmark;
  PaymentMethod _method = PaymentMethod.online;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(savedAddressProvider);
    final userPhone = ref.read(currentUserProvider)?.phone ?? '';
    _name = TextEditingController(text: saved?.name ?? '');
    _phone = TextEditingController(
      text: saved?.phone ?? userPhone.replaceFirst(AppConfig.countryCode, ''),
    );
    _line1 = TextEditingController(text: saved?.line1 ?? '');
    _landmark = TextEditingController(text: saved?.landmark ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _line1.dispose();
    _landmark.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final address = Address(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      line1: _line1.text.trim(),
      landmark: _landmark.text.trim(),
      pincode: ref.read(pincodeProvider) ?? '',
    );
    final result = await ref
        .read(checkoutControllerProvider.notifier)
        .placeOrder(address: address, method: _method);
    if (!mounted || result == null) return;
    context.go(Routes.orderResult(result.orderId, result.outcome));
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final pincode = ref.watch(pincodeProvider) ?? '';
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
                    _field(
                      key: 'name-field',
                      controller: _name,
                      label: 'Full name',
                      validator: Validators.required('your name'),
                      capitalization: TextCapitalization.words,
                      autofill: AutofillHints.name,
                    ),
                    _field(
                      key: 'address-phone-field',
                      controller: _phone,
                      label: 'Mobile number',
                      validator: Validators.phone,
                      keyboard: TextInputType.phone,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                    ),
                    _field(
                      key: 'line1-field',
                      controller: _line1,
                      label: 'House / flat, street, area',
                      validator: Validators.required('your address'),
                      capitalization: TextCapitalization.sentences,
                      autofill: AutofillHints.streetAddressLine1,
                    ),
                    _field(
                      key: 'landmark-field',
                      controller: _landmark,
                      label: 'Landmark (optional)',
                      capitalization: TextCapitalization.sentences,
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.location_on_outlined,
                            color: AppColors.primary),
                        title: Text('Pincode $pincode'),
                        subtitle: const Text('We deliver to this area'),
                        trailing: TextButton(
                          onPressed: () => context.push(Routes.pincode),
                          child: const Text('Change'),
                        ),
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
                    const SectionLabel('Bill details'),
                    BillSummary(
                      subtotalPaise: cart.subtotalPaise,
                      deliveryFeePaise: cart.deliveryFeePaise,
                      totalPaise: cart.totalPaise,
                      savingsPaise: cart.savingsPaise,
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
                  _method == PaymentMethod.cod
                      ? 'Place order  ·  ${formatPaise(cart.totalPaise)}'
                      : 'Pay ${formatPaise(cart.totalPaise)}',
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

  Widget _field({
    required String key,
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    TextCapitalization capitalization = TextCapitalization.none,
    String? autofill,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: ValueKey(key),
        controller: controller,
        validator: validator,
        keyboardType: keyboard,
        inputFormatters: formatters,
        textCapitalization: capitalization,
        textInputAction: TextInputAction.next,
        autofillHints: autofill == null ? null : [autofill],
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
