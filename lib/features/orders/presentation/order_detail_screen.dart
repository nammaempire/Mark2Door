import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
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
        const SectionLabel('Bill details'),
        BillSummary(
          subtotalPaise: order.subtotalPaise,
          deliveryFeePaise: order.deliveryFeePaise,
          totalPaise: order.totalPaise,
          totalLabel: 'Total',
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
