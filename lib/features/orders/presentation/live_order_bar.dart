import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../application/order_providers.dart';
import '../domain/order.dart';
import 'eta_widgets.dart';
import 'live_order_card.dart';

/// The shopper's order that is on its way, as a bar that slides up from
/// the bottom of the home page and sits just above the "View cart" bar.
/// It shows what is happening now, when the order arrives and how far
/// along it is; a tap opens the order. It slides away by itself once the
/// order is delivered or cancelled.
class LiveOrderBar extends ConsumerWidget {
  const LiveOrderBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider).valueOrNull ?? const <Order>[];
    final active = orders.where((o) => o.isActive).toList(growable: false);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // Rises from below the screen edge, and leaves the same way.
      transitionBuilder: (child, animation) => ClipRect(
        child: SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .animate(animation),
            child: child,
          ),
        ),
      ),
      child: active.isEmpty
          ? const SizedBox(width: double.infinity)
          : _Bar(
              // One bar per order, so a new order slides in afresh.
              key: ValueKey('bar-${active.first.id}'),
              order: active.first,
              more: active.length - 1,
            ),
    );
  }
}

class _Bar extends StatefulWidget {
  const _Bar({super.key, required this.order, required this.more});

  final Order order;
  final int more;

  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tests wait for animations to end, and this one never does.
    if (!MediaQuery.disableAnimationsOf(context) && !Env.runningTests) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final stage = OrderStage.of(order);
    final view = OrderStageView.of(order);
    final waiting = order.awaitingPayment;
    final color = waiting ? AppColors.accentDark : AppColors.success;
    final radius = BorderRadius.circular(18);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: radius,
          border: Border.all(color: color.withAlpha(90)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const ValueKey('home-live-order'),
            borderRadius: radius,
            onTap: () => context.push(Routes.order(order.id)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // The icon breathes while the order is on its way.
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, child) => Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withAlpha(
                              28 + (30 * _pulse.value).round(),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Transform.scale(
                            scale: 1 + 0.12 * _pulse.value,
                            child: child,
                          ),
                        ),
                        child: Icon(view.icon, color: color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              view.headline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Ticker(
                              builder: (context, now) => Text(
                                _detail(order, now),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          waiting ? 'Pay now' : 'Track',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  // Four steps: filled up to where the order is now.
                  Row(
                    children: [
                      for (final s in OrderStage.values) ...[
                        if (s.index > 0) const SizedBox(width: 5),
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: !waiting && s.index <= stage.index
                                  ? color
                                  : color.withAlpha(40),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The line under the headline: when it arrives, and the order number.
  String _detail(Order order, DateTime now) {
    final eta = order.eta(now);
    final parts = [
      if (eta != null && !order.awaitingPayment) eta.headline,
      'Order ${order.displayId}',
      if (widget.more > 0) '+${widget.more} more',
    ];
    return parts.join('  ·  ');
  }
}
