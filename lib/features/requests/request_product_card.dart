import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../auth/application/auth_providers.dart';
import '../profile/application/customer_name.dart';
import '../service_area/application/pincode_controller.dart';
import 'product_requests.dart';

/// "Can't find what you want?": shown under a category's products and
/// under search results. Opens a short form (product and quantity) that
/// goes to the store with the shopper's name, number and pincode.
class RequestProductCard extends StatelessWidget {
  const RequestProductCard({super.key, this.suggestedName = ''});

  /// What the shopper was searching for, to start the form with.
  final String suggestedName;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('request-product-card'),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.search_off_rounded, color: AppColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Can't find what you want?",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Tell us the product and how many you need. We will call you '
            'to say how long it will take to get it. You pay only when '
            'it is ready for you.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('request-product-button'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => _RequestSheet(suggestedName: suggestedName),
              ),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Request a product'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestSheet extends ConsumerStatefulWidget {
  const _RequestSheet({required this.suggestedName});

  final String suggestedName;

  @override
  ConsumerState<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends ConsumerState<_RequestSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.suggestedName);
  final _quantity = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(productRequestRepositoryProvider).send(
            ProductRequest(
              uid: user.uid,
              product: _name.text.trim(),
              quantity: _quantity.text.trim(),
              customerName: ref.read(customerNameProvider),
              phone: user.phone,
              pincode: ref.read(deliveryPincodeProvider) ?? '',
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Request sent. We will call you on ${user.phone}.',
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not send the request. Try again.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request a product',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'We will call you with how long it will take. No payment now.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('request-name'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              maxLength: 80,
              validator: (v) => (v ?? '').trim().length < 2
                  ? 'Enter the product name'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Product name',
                hintText: 'Brand, type and size',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('request-quantity'),
              controller: _quantity,
              textInputAction: TextInputAction.done,
              maxLength: 20,
              onFieldSubmitted: (_) => _send(),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter how many you need' : null,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                hintText: 'For example 2, or 5 kg',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('request-submit'),
                onPressed: _sending ? null : _send,
                child: Text(_sending ? 'Sending…' : 'Send request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
