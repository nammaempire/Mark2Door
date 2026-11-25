import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/shimmer.dart';
import '../../cart/presentation/bill_summary.dart';
import '../application/order_providers.dart';
import '../domain/order.dart';
import 'eta_widgets.dart';
import '../../store/application/store_providers.dart';
import '../application/invoice.dart';
import 'live_order_card.dart';
import '../../reviews/review_widgets.dart';
import 'pay_now.dart';
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
        PayNowBanner(order: order),
        if (order.isRefunded || order.refundInProgress)
          _RefundBanner(order: order),
        if (order.status == OrderStatus.cancelled &&
            order.cancelledBy == 'customer')
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'You cancelled this order.',
              key: ValueKey('cancelled-by-you'),
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        if (order.status != OrderStatus.cancelled) ...[
          const SectionLabel('Order status'),
          LiveOrderCard(
            key: const ValueKey('order-status-card'),
            order: order,
            showOrderId: false,
            showEta: false,
          ),
        ],
        if (order.status == OrderStatus.delivered && order.riderName != null)
          _RateDelivery(order: order),
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
                  subtitle: order.status == OrderStatus.delivered
                      // Bought and received: the item can be reviewed.
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item.unit}  ×  ${item.quantity}'),
                            ReviewItemButton(order: order, item: item),
                          ],
                        )
                      : Text('${item.unit}  ×  ${item.quantity}'),
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
          courier: order.isCourier,
          handlingFeePaise: order.handlingFeePaise,
          rainFeePaise: order.rainFeePaise,
          walletAppliedPaise: order.walletAppliedPaise,
          couponCode: order.couponCode,
          couponDiscountPaise: order.couponDiscountPaise,
          totalPaise: order.totalPaise,
          totalLabel: 'Total',
          savingsVerb: 'You saved',
        ),
        const SectionLabel('Delivery and payment'),
        Card(
          child: Column(
            children: [
              if (order.isCourier) ...[
                ListTile(
                  key: const ValueKey('courier-tile'),
                  leading: const Icon(Icons.local_shipping_rounded,
                      color: AppColors.primary),
                  title: Text(
                    order.courierName ?? 'Outstation delivery',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    (order.trackingNumber?.isNotEmpty ?? false)
                        ? 'Tracking number ${order.trackingNumber}'
                        : 'Reaches you in ${order.courierEta ?? 'a few days'}. '
                            'The tracking number appears here once shipped.',
                  ),
                  trailing: (order.trackingNumber?.isNotEmpty ?? false)
                      ? IconButton(
                          key: const ValueKey('copy-tracking-button'),
                          tooltip: 'Copy tracking number',
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: order.trackingNumber!),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tracking number copied'),
                              ),
                            );
                          },
                        )
                      : null,
                ),
                const Divider(indent: 16, endIndent: 16),
              ],
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
        _InvoiceButton(order: order),
        if (order.canCancel) _CancelOrder(order: order),
      ],
    );
  }
}

/// "Cancel order", offered until the delivery partner has picked the order
/// up. Asks first, and says where any money already paid will go.
/// "Download invoice": builds the bill as a PDF on the phone and hands it
/// to the phone's share sheet, where it can be saved or sent. Offered once
/// the order is real: not cancelled, and not still waiting for payment.
class _InvoiceButton extends ConsumerStatefulWidget {
  const _InvoiceButton({required this.order});

  final Order order;

  @override
  ConsumerState<_InvoiceButton> createState() => _InvoiceButtonState();
}

class _InvoiceButtonState extends ConsumerState<_InvoiceButton> {
  bool _busy = false;

  Future<void> _download() async {
    if (_busy) return;
    setState(() => _busy = true);
    final order = widget.order;
    try {
      final bytes = await buildInvoicePdf(
        order,
        ref.read(storeSettingsProvider),
      );
      await ref.read(invoiceSharerProvider)(bytes, invoiceFileName(order));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Could not make the invoice. Try again.'),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    if (order.status == OrderStatus.cancelled || order.awaitingPayment) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: OutlinedButton.icon(
        key: const ValueKey('download-invoice-button'),
        onPressed: _busy ? null : _download,
        icon: const Icon(Icons.receipt_long_rounded),
        label: Text(_busy ? 'Preparing invoice' : 'Download invoice'),
      ),
    );
  }
}

class _CancelOrder extends ConsumerStatefulWidget {
  const _CancelOrder({required this.order});

  final Order order;

  @override
  ConsumerState<_CancelOrder> createState() => _CancelOrderState();
}

class _CancelOrderState extends ConsumerState<_CancelOrder> {
  bool _busy = false;

  /// What happens to money already paid, if any.
  List<String> get _refundLines {
    final o = widget.order;
    final paidOnline = o.paymentMethod == PaymentMethod.online &&
        o.paymentStatus == PaymentStatus.paid &&
        o.payablePaise > 0;
    return [
      if (o.walletAppliedPaise > 0)
        '${formatPaise(o.walletAppliedPaise)} will be returned to your '
            'm2d wallet.',
      if (paidOnline)
        '${formatPaise(o.payablePaise)} paid online will be refunded to the '
            'account you paid from.',
    ];
  }

  Future<void> _cancel() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          [
            'Order ${widget.order.displayId} will not be delivered.',
            ..._refundLines,
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep order'),
          ),
          TextButton(
            key: const ValueKey('confirm-cancel-button'),
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(orderRepositoryProvider).cancel(widget.order.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Order cancelled.')));
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Could not cancel. The order may already be on its way.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          OutlinedButton.icon(
            key: const ValueKey('cancel-order-button'),
            onPressed: _busy ? null : _cancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            icon: const Icon(Icons.cancel_outlined),
            label: Text(_busy ? 'Cancelling' : 'Cancel order'),
          ),
          const SizedBox(height: 8),
          const Text(
            'You can cancel until your order leaves the store.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
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

/// Lets the shopper rate the delivery partner once the order is delivered.
/// Stars are picked first and sent with Submit, because a rating cannot be
/// changed afterwards.
class _RateDelivery extends ConsumerStatefulWidget {
  const _RateDelivery({required this.order});

  final Order order;

  @override
  ConsumerState<_RateDelivery> createState() => _RateDeliveryState();
}

class _RateDeliveryState extends ConsumerState<_RateDelivery> {
  static const _words = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  int _picked = 0;
  bool _saving = false;

  Future<void> _submit() async {
    if (_saving || _picked == 0) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(orderRepositoryProvider)
          .rateDelivery(widget.order.id, _picked);
      messenger.showSnackBar(
        const SnackBar(content: Text('Thanks for rating your delivery')),
      );
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't save your rating. Try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = widget.order.riderRating;
    final stars = saved ?? _picked;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      saved == null
                          ? 'Rate your delivery'
                          : 'You rated this delivery',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  // What the picked stars mean, e.g. "Very good".
                  Text(
                    _words[stars],
                    key: const ValueKey('rating-word'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                saved == null
                    ? 'How was ${widget.order.riderName}?'
                    : 'Delivered by ${widget.order.riderName}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      key: ValueKey('rate-star-$i'),
                      tooltip: '$i star${i == 1 ? '' : 's'}',
                      visualDensity: VisualDensity.compact,
                      // Locked once the rating has been sent.
                      onPressed: saved != null || _saving
                          ? null
                          : () => setState(() => _picked = i),
                      icon: Icon(
                        i <= stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 34,
                        color: i <= stars
                            ? const Color(0xFFE8A200)
                            : AppColors.textMuted,
                      ),
                    ),
                ],
              ),
              if (saved == null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('submit-rating-button'),
                    onPressed: _picked == 0 || _saving ? null : _submit,
                    child: Text(_saving ? 'Sending…' : 'Submit rating'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
