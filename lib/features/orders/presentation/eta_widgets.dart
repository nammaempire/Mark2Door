import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/order.dart';

/// Rebuilds [builder] with a fresh "now" every [interval] so countdowns
/// stay current without each screen managing its own timer.
class Ticker extends StatefulWidget {
  const Ticker({
    super.key,
    required this.builder,
    this.interval = const Duration(seconds: 20),
  });

  final Widget Function(BuildContext context, DateTime now) builder;
  final Duration interval;

  @override
  State<Ticker> createState() => _TickerState();
}

class _TickerState extends State<Ticker> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, DateTime.now());
}

({Color color, IconData icon}) _etaStyle(EtaKind kind) {
  switch (kind) {
    case EtaKind.onTime:
      return (color: AppColors.primary, icon: Icons.schedule_rounded);
    case EtaKind.late:
      return (color: AppColors.accentDark, icon: Icons.schedule_rounded);
    case EtaKind.onHold:
      return (color: AppColors.warning, icon: Icons.hourglass_top_rounded);
    case EtaKind.delivered:
      return (color: AppColors.success, icon: Icons.check_circle_rounded);
  }
}

/// One-line ETA for the order history list.
class EtaLine extends StatelessWidget {
  const EtaLine({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Ticker(
      builder: (context, now) {
        final eta = order.eta(now);
        if (eta == null) return const SizedBox.shrink();
        final style = _etaStyle(eta.kind);
        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: style.color.withAlpha(22),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(style.icon, size: 18, color: style.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  eta.headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: style.color,
                  ),
                ),
              ),
              if (eta.kind == EtaKind.onTime && order.etaAt != null)
                Text(
                  // "Estimated delivery by 8:40 PM" -> "by 8:40 PM"
                  eta.detail!.replaceFirst('Estimated delivery ', ''),
                  style: TextStyle(fontSize: 12, color: style.color),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Prominent ETA card for the top of the order detail page.
class EtaBanner extends StatelessWidget {
  const EtaBanner({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Ticker(
      builder: (context, now) {
        final eta = order.eta(now);
        if (eta == null) return const SizedBox.shrink();
        final style = _etaStyle(eta.kind);
        return Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: style.color.withAlpha(22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: style.color.withAlpha(60)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(style.icon, color: style.color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eta.headline,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: style.color,
                      ),
                    ),
                    if (eta.detail != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        eta.detail!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
