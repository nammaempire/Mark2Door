import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../application/order_providers.dart';
import '../domain/order.dart';
import 'eta_widgets.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your orders')),
      body: AsyncValueView(
        value: orders,
        onRetry: () => ref.invalidate(ordersProvider),
        data: (items) => items.isEmpty
            ? EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No orders yet',
                message: 'Your orders will show up here.',
                actionLabel: 'Start shopping',
                onAction: () => context.go(Routes.home),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _OrderCard(order: items[i]),
              ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final names = order.items.map((i) => i.name).join(', ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.order(order.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Order ${order.displayId}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const Spacer(),
                  OrderStatusChip(order: order),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                formatOrderDate(order.createdAt),
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
              Text(
                names,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.textDark),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '${order.itemCount} '
                    '${order.itemCount == 1 ? 'item' : 'items'}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const Spacer(),
                  Text(
                    formatPaise(order.totalPaise),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              EtaLine(order: order),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (order) {
      Order(isRefunded: true) => ('Refunded', const Color(0xFF2F6FD6)),
      Order(status: OrderStatus.cancelled) => ('Cancelled', AppColors.danger),
      Order(status: OrderStatus.delivered) => ('Delivered', AppColors.success),
      Order(awaitingPayment: true) => ('Payment pending', AppColors.warning),
      _ => (order.status.label, AppColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
