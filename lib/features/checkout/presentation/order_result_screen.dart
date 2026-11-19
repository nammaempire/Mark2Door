import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../orders/application/order_providers.dart';
import '../data/payment_gateway.dart';

/// One screen, three states: success, payment failed, payment pending.
class OrderResultScreen extends ConsumerWidget {
  const OrderResultScreen({
    super.key,
    required this.orderId,
    required this.outcome,
  });

  final String orderId;
  final PaymentOutcome outcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId)).valueOrNull;
    final view = _ResultView.of(outcome);

    return PopScope(
      // Back must never return to the checkout that was just completed.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.home);
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: view.color.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(view.icon, size: 64, color: view.color),
                ),
                const SizedBox(height: 24),
                Text(
                  view.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  view.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
                if (order != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _row('Order', order.displayId),
                        const SizedBox(height: 8),
                        _row('Amount', formatPaise(order.totalPaise)),
                        const SizedBox(height: 8),
                        _row('Payment', order.paymentMethod.label),
                        if (outcome == PaymentOutcome.success &&
                            order.etaAt != null) ...[
                          const SizedBox(height: 8),
                          _row('Arriving by', formatTime(order.etaAt!)),
                        ],
                      ],
                    ),
                  ),
                ],
                const Spacer(flex: 2),
                if (outcome == PaymentOutcome.failed)
                  FilledButton(
                    key: const ValueKey('retry-button'),
                    // The cart was kept, so this rebuilds home > cart.
                    onPressed: () => context.go(Routes.cart),
                    child: const Text('Try again'),
                  )
                else
                  FilledButton(
                    key: const ValueKey('track-button'),
                    onPressed: () => context.go(Routes.order(orderId)),
                    child: const Text('View order'),
                  ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go(Routes.home),
                  child: const Text('Continue shopping'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultView {
  const _ResultView(this.icon, this.color, this.title, this.message);

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  static _ResultView of(PaymentOutcome outcome) {
    switch (outcome) {
      case PaymentOutcome.success:
        return const _ResultView(
          Icons.check_circle_rounded,
          AppColors.success,
          'Order placed',
          "We've received your order and will deliver it soon.",
        );
      case PaymentOutcome.failed:
        return const _ResultView(
          Icons.cancel_rounded,
          AppColors.danger,
          'Payment failed',
          'No order was confirmed. If money was deducted, it will be '
              'refunded automatically. Your cart is saved.',
        );
      case PaymentOutcome.pending:
        return const _ResultView(
          Icons.schedule_rounded,
          AppColors.warning,
          'Payment pending',
          "We're waiting for your bank to confirm the payment. Your order "
              'will be confirmed as soon as it comes through.',
        );
    }
  }
}
