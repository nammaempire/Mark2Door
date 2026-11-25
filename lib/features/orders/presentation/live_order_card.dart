import 'package:flutter/material.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/order.dart';
import 'eta_widgets.dart';

/// Where an order is on its way to the shopper, as four steps.
enum OrderStage {
  placed('Placed'),
  assigned('Partner'),
  onTheWay('On the way'),
  delivered('Delivered');

  const OrderStage(this.label);
  final String label;

  /// The step's name for [order]: courier orders are packed and shipped
  /// where instant orders get a delivery partner.
  String labelFor(Order order) {
    if (!order.isCourier) return label;
    return switch (this) {
      OrderStage.assigned => 'Packed',
      OrderStage.onTheWay => 'Shipped',
      _ => label,
    };
  }

  static OrderStage of(Order order) {
    switch (order.status) {
      case OrderStatus.delivered:
        return OrderStage.delivered;
      case OrderStatus.pickedUp:
        return OrderStage.onTheWay;
      case OrderStatus.accepted:
        return OrderStage.assigned;
      case OrderStatus.placed:
      case OrderStatus.cancelled:
        return order.riderName == null
            ? OrderStage.placed
            : OrderStage.assigned;
    }
  }
}

/// What the live card says for an order right now.
@immutable
class OrderStageView {
  const OrderStageView(this.icon, this.headline, this.detail);

  final IconData icon;
  final String headline;
  final String detail;

  static OrderStageView of(Order order) {
    final rider = order.riderName ?? 'Your delivery partner';
    if (order.awaitingPayment) {
      return const OrderStageView(
        Icons.hourglass_top_rounded,
        'Waiting for payment',
        'Your order is confirmed as soon as the payment goes through.',
      );
    }
    if (order.isCourier) {
      final days = order.courierEta ?? 'a few days';
      final tracking = order.trackingNumber;
      switch (OrderStage.of(order)) {
        case OrderStage.placed:
          return OrderStageView(
            Icons.inventory_2_rounded,
            'Order placed',
            'The store is packing your order. It reaches you in $days.',
          );
        case OrderStage.assigned:
          return const OrderStageView(
            Icons.inventory_rounded,
            'Packed',
            'Your parcel is packed and ready to be shipped.',
          );
        case OrderStage.onTheWay:
          return OrderStageView(
            Icons.local_shipping_rounded,
            'Shipped',
            tracking == null || tracking.isEmpty
                ? 'Your parcel is on its way.'
                : '${order.courierName ?? 'Delivery'} tracking number '
                    '$tracking.',
          );
        case OrderStage.delivered:
          return const OrderStageView(
            Icons.check_circle_rounded,
            'Delivered',
            'Your order has reached you. Enjoy!',
          );
      }
    }
    switch (OrderStage.of(order)) {
      case OrderStage.placed:
        return const OrderStageView(
          Icons.storefront_rounded,
          'Order placed',
          'The store is getting your order ready.',
        );
      case OrderStage.assigned:
        return OrderStageView(
          Icons.shopping_bag_rounded,
          order.status == OrderStatus.accepted
              ? 'Order accepted'
              : 'Delivery partner assigned',
          '$rider is collecting your order from the store.',
        );
      case OrderStage.onTheWay:
        return OrderStageView(
          Icons.delivery_dining_rounded,
          'Out for delivery',
          '$rider is on the way to you.',
        );
      case OrderStage.delivered:
        return const OrderStageView(
          Icons.check_circle_rounded,
          'Delivered',
          'Your order has reached you. Enjoy!',
        );
    }
  }
}

/// Animated card that shows an order's live status: a pulsing icon, what
/// is happening now, the arrival time and a four-step progress bar whose
/// current step keeps moving.
///
/// Used on the home page (while an order is on its way), on the "order
/// placed" page and at the top of the order details.
class LiveOrderCard extends StatefulWidget {
  const LiveOrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.showOrderId = true,
    this.showEta = true,
    this.footer,
  });

  final Order order;
  final VoidCallback? onTap;
  final bool showOrderId;

  /// Off where the page already shows the arrival time next to the card.
  final bool showEta;

  /// Small line under the progress bar, e.g. "and 1 more order".
  final String? footer;

  @override
  State<LiveOrderCard> createState() => _LiveOrderCardState();
}

class _LiveOrderCardState extends State<LiveOrderCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!MediaQuery.disableAnimationsOf(context) && !Env.runningTests) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final stage = OrderStage.of(order);
    final view = OrderStageView.of(order);
    final done = stage == OrderStage.delivered;
    final color = done ? AppColors.success : AppColors.primary;

    return TweenAnimationBuilder<double>(
      // Slides up and fades in when the card first appears.
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 16),
          child: child,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(color.withAlpha(34), AppColors.surface),
              Color.alphaBlend(color.withAlpha(10), AppColors.surface),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(70)),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PulsingIcon(
                        animation: _loop,
                        icon: view.icon,
                        color: color,
                        still: done,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: AnimatedSwitcher(
                          // The words cross-fade when the status changes.
                          duration: const Duration(milliseconds: 350),
                          layoutBuilder: (current, previous) => Stack(
                            alignment: Alignment.topLeft,
                            children: [
                              ...previous,
                              if (current != null) current
                            ],
                          ),
                          child: Column(
                            key: ValueKey(view.headline),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                view.headline,
                                key: const ValueKey('live-order-headline'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                view.detail,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (widget.onTap != null)
                        const Padding(
                          padding: EdgeInsets.only(left: 4, top: 2),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _StageBar(
                    animation: _loop,
                    order: order,
                    stage: stage,
                    color: color,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (widget.showOrderId) ...[
                        Text(
                          'Order ${order.displayId}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: !widget.showEta || done || order.awaitingPayment
                            ? const SizedBox.shrink()
                            : Ticker(
                                builder: (context, now) {
                                  final eta = order.eta(now);
                                  if (eta == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: 15,
                                        color: color,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          eta.headline,
                                          key: const ValueKey('live-order-eta'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                  if (widget.footer != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.footer!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The status icon, with a ring that grows and fades out behind it.
class _PulsingIcon extends StatelessWidget {
  const _PulsingIcon({
    required this.animation,
    required this.icon,
    required this.color,
    required this.still,
  });

  final Animation<double> animation;
  final IconData icon;
  final Color color;
  final bool still;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = still ? 0.0 : animation.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (!still)
                Container(
                  width: 36 + 16 * t,
                  height: 36 + 16 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withAlpha((70 * (1 - t)).round()),
                  ),
                ),
              // A gentle bob, so the icon itself feels alive.
              Transform.translate(
                offset: Offset(0, still ? 0 : -2 * (0.5 - (t - 0.5).abs())),
                child: child,
              ),
            ],
          );
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: color.withAlpha(90)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, a) =>
                ScaleTransition(scale: a, child: child),
            child: Icon(icon, key: ValueKey(icon), color: color, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Four segments: finished ones are filled, the current one has a light
/// band sweeping across it, the rest are empty.
class _StageBar extends StatelessWidget {
  const _StageBar({
    required this.animation,
    required this.order,
    required this.stage,
    required this.color,
  });

  final Animation<double> animation;
  final Order order;
  final OrderStage stage;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final done = stage == OrderStage.delivered;
    return Column(
      children: [
        Row(
          children: [
            for (final s in OrderStage.values) ...[
              if (s.index > 0) const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 6,
                    child: s.index < stage.index || done
                        ? ColoredBox(color: color)
                        : s.index > stage.index
                            ? ColoredBox(color: color.withAlpha(40))
                            : AnimatedBuilder(
                                animation: animation,
                                builder: (context, _) => CustomPaint(
                                  painter: _SweepPainter(
                                    animation.value,
                                    color,
                                  ),
                                ),
                              ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final s in OrderStage.values)
              Expanded(
                child: Text(
                  s.labelFor(order),
                  textAlign: s.index == 0
                      ? TextAlign.start
                      : s.index == OrderStage.values.length - 1
                          ? TextAlign.end
                          : TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: s.index <= stage.index
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: s.index <= stage.index ? color : AppColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SweepPainter extends CustomPainter {
  _SweepPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = color.withAlpha(90));
    // A solid band that travels from left to right and starts again.
    final band = size.width * 0.45;
    final left = -band + (size.width + band) * t;
    canvas.drawRect(
      Rect.fromLTWH(left, 0, band, size.height).intersect(rect),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.t != t || old.color != color;
}
