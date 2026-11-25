import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../checkout/application/pay_again.dart';
import '../../checkout/data/payment_gateway.dart';
import '../domain/order.dart';

/// "Pay ₹X online": takes the shopper back into the payment journey for
/// an order that is still waiting for its online payment.
class PayNowButton extends ConsumerWidget {
  const PayNowButton({super.key, required this.order});

  final Order order;

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(payAgainProvider.notifier).pay(order);
    if (result == null || !context.mounted) return;
    switch (result.outcome) {
      case PaymentOutcome.success:
        context.go(Routes.orderResult(order.id, PaymentOutcome.success));
      case PaymentOutcome.pending:
        _say(
          context,
          'Your bank has not confirmed the payment yet. We will update the '
          'order as soon as it does.',
        );
      case PaymentOutcome.failed:
        _say(
          context,
          result.message ?? 'Payment did not go through. Try again.',
        );
    }
  }

  void _say(BuildContext context, String text) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(payAgainProvider).isLoading;
    return FilledButton.icon(
      key: const ValueKey('pay-now-button'),
      onPressed: busy ? null : () => _pay(context, ref),
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.lock_rounded, size: 18),
      label: Text(
        busy
            ? 'Opening payment'
            : 'Pay ${formatPaise(order.payablePaise)} online',
      ),
    );
  }
}

/// Shown on an order that is waiting for its online payment: says the
/// order is not confirmed yet and offers to pay now. Takes no space on
/// every other order.
class PayNowBanner extends StatelessWidget {
  const PayNowBanner({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    if (!order.canPayNow) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('pay-now-banner'),
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD3A3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: AppColors.accentDark),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Payment not completed',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'This order is confirmed only after you pay online. If money '
            'has already left your account, wait a minute: the order '
            'updates by itself.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          PayNowButton(order: order),
        ],
      ),
    );
  }
}
