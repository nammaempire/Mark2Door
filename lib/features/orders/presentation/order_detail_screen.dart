import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/shimmer.dart';
import '../../cart/presentation/bill_summary.dart';
import '../application/order_providers.dart';
import '../domain/order.dart';
import 'eta_widgets.dart';
import 'orders_screen.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      body: AsyncValueView(
        value: order,
        loading: const CardListSkeleton(count: 3),
        onRetry: () => ref.invalidate(orderProvider(orderId)),
        data: (o) => o == null
            ? const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Order not found',
              )
            : _Body(order: o),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final paymentText = switch ((order.paymentMethod, order.paymentStatus)) {
      (PaymentMethod.cod, _) => 'Cash on delivery',
      (_, PaymentStatus.paid) => 'Paid online',
      (_, PaymentStatus.pending) => 'Online payment pending',
      (_, PaymentStatus.failed) => 'Online payment failed',
      (_, PaymentStatus.refunded) => 'Refunded',
    };


    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order ${order.displayId}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatOrderDate(order.createdAt),
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            OrderStatusChip(order: order),
          ],
        ),
        EtaBanner(order: order),
        if (order.isRefunded || order.refundInProgress)
          _RefundBanner(order: order),
        if (order.status != OrderStatus.cancelled) ...[
          const SectionLabel('Order status'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _Timeline(current: order.status),
            ),
          ),
        ],
        const SectionLabel('Items'),
        Card(
          child: Column(
            children: [
              for (final (i, item) in order.items.indexed) ...[
                if (i > 0) const Divider(indent: 16, endIndent: 16),
                ListTile(
                  title: Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${item.unit}  ×  ${item.quantity}'),
                  trailing: Text(
                    formatPaise(item.lineTotalPaise),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SectionLabel('Order summary'),
        OrderSummaryCard(
          subtotalPaise: order.subtotalPaise,
          mrpTotalPaise: order.mrpTotalPaise,
          deliveryFeePaise: order.deliveryFeePaise,
          handlingFeePaise: order.handlingFeePaise,
          rainFeePaise: order.rainFeePaise,
          walletAppliedPaise: order.walletAppliedPaise,
          totalPaise: order.totalPaise,
          totalLabel: 'Total',
          savingsVerb: 'You saved',
        ),
        const SectionLabel('Delivery and payment'),
        Card(
          child: Column(
            children: [
              if (order.riderName != null) ...[
                ListTile(
                  leading: const Icon(Icons.delivery_dining_rounded,
                      color: AppColors.primary),
                  title: Text(
                    order.riderName!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [
                      'Your delivery partner',
                      if (order.riderPhone?.isNotEmpty ?? false)
                        '+91 ${order.riderPhone}',
                    ].join(' · '),
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),
              ],
              ListTile(
                leading: const Icon(Icons.location_on_outlined,
                    color: AppColors.primary),
                title: Text(
                  order.address.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${order.address.singleLine}\n${order.address.phone}',
                ),
                isThreeLine: true,
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.payments_outlined,
                    color: AppColors.primary),
                title: Text(
                  paymentText,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle:
                    order.paymentId == null ? null : Text(order.paymentId!),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tells the shopper where the money for a cancelled, paid order is.
class _RefundBanner extends StatelessWidget {
  const _RefundBanner({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final done = order.isRefunded;
    const color = Color(0xFF2F6FD6);
    return Container(
      key: const ValueKey('refund-banner'),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(60)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: done ? () => context.push(Routes.refund(order.id)) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    done
                        ? Icons.currency_rupee_rounded
                        : Icons.hourglass_top_rounded,
                    color: color,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        done
                            ? 'Refund of ${formatPaise(order.totalPaise)} sent'
                            : 'Refund in progress',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        done
                            ? 'Tap to see the refund details.'
                            : '${formatPaise(order.totalPaise)} will be '
                                'returned to the account you paid from.',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                if (done) const Icon(Icons.chevron_right_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Vertical progress through the delivery lifecycle. The delivery app and
/// admin web advance `status`; this screen updates live from the stream.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.current});

  final OrderStatus current;

  static const _steps = [
    OrderStatus.placed,
    OrderStatus.accepted,
    OrderStatus.pickedUp,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _steps.indexOf(current);
    return Column(
      children: [
        for (final (i, step) in _steps.indexed)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(
                    i <= currentIndex
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 22,
                    color: i <= currentIndex
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                  if (i < _steps.length - 1)
                    Container(
                      width: 2,
                      height: 22,
                      color: i < currentIndex
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  step.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        i == currentIndex ? FontWeight.w800 : FontWeight.w500,
                    color: i <= currentIndex
                        ? AppColors.textDark
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
