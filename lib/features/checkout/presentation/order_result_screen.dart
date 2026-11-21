import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../orders/application/order_providers.dart';
import '../../orders/presentation/live_order_card.dart';
import 'result_animation.dart';

/// One screen, four states: order placed, payment failed, payment pending
/// and refunded. Each has its own animation, message and next step.
class OrderResultScreen extends ConsumerWidget {
  const OrderResultScreen({
    super.key,
    required this.orderId,
    required this.outcome,
  });

  final String orderId;
  final ResultKind outcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId)).valueOrNull;
    final view = _ResultView.of(outcome);

    return PopScope(
      // Back must never return to the checkout that was just completed.
      // The refund page is opened from an order, so back returns to it.
      canPop: outcome == ResultKind.refunded,
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
                ResultAnimation(
                  key: ValueKey('result-${outcome.name}'),
                  kind: outcome,
                ),
                const SizedBox(height: 12),
                if (outcome == ResultKind.success && order != null)
                  // The live card says "Order placed" and keeps showing
                  // where the order is while this page stays open.
                  LiveOrderCard(
                    key: const ValueKey('result-status-card'),
                    order: order,
                    showOrderId: false,
                  )
                else ...[
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
                ],
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
                        _row(
                          outcome == ResultKind.refunded
                              ? 'Refund amount'
                              : 'Amount',
                          // A refund returns the whole order value; otherwise
                          // show what was left to pay after the wallet.
                          formatPaise(
                            outcome == ResultKind.refunded
                                ? order.totalPaise
                                : order.payablePaise,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _row('Payment', order.paymentMethod.label),
                        if (outcome == ResultKind.success &&
                            order.etaAt != null) ...[
                          const SizedBox(height: 8),
                          _row('Arriving by', formatTime(order.etaAt!)),
                        ],
                      ],
                    ),
                  ),
                ],
                const Spacer(flex: 2),
                if (outcome == ResultKind.failed)
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
  const _ResultView(this.title, this.message);

  final String title;
  final String message;

  static _ResultView of(ResultKind outcome) {
    switch (outcome) {
      case ResultKind.success:
        return const _ResultView(
          'Order placed',
          "We've received your order and will deliver it soon.",
        );
      case ResultKind.failed:
        return const _ResultView(
          'Payment failed',
          'No order was confirmed. If money was deducted, it will be '
              'refunded automatically. Your cart is saved.',
        );
      case ResultKind.pending:
        return const _ResultView(
          'Payment pending',
          "We're waiting for your bank to confirm the payment. Your order "
              'will be confirmed as soon as it comes through.',
        );
      case ResultKind.refunded:
        return const _ResultView(
          'Refund sent',
          'Your money for this order has been returned to the account you '
              'paid from. Banks can take a few days to show it.',
        );
    }
  }
}
