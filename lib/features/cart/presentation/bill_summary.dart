import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

/// "Order summary" card shared by cart, checkout and order detail.
///
/// Handling fee and rain charge are admin-controlled extras: each row is
/// shown only when its amount is above zero.
class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({
    super.key,
    required this.subtotalPaise,
    required this.deliveryFeePaise,
    required this.totalPaise,
    this.mrpTotalPaise = 0,
    this.handlingFeePaise = 0,
    this.rainFeePaise = 0,
    this.walletAppliedPaise = 0,
    this.totalLabel = 'To pay',
    this.savingsVerb = 'You save',
  });

  /// What the items cost at selling price.
  final int subtotalPaise;

  /// What the items would cost at MRP; shown struck through when higher.
  final int mrpTotalPaise;
  final int deliveryFeePaise;
  final int handlingFeePaise;
  final int rainFeePaise;

  /// Paid from the m2d wallet; shown as a deduction when above zero.
  final int walletAppliedPaise;

  /// Order value before the wallet is taken off.
  final int totalPaise;
  final String totalLabel;

  /// "You save" before ordering, "You saved" on a placed order.
  final String savingsVerb;

  @override
  Widget build(BuildContext context) {
    final savingsPaise = mrpTotalPaise - subtotalPaise;
    return Card(
      key: const ValueKey('order-summary'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row(
              'Item total',
              formatPaise(subtotalPaise),
              struck: savingsPaise > 0 ? formatPaise(mrpTotalPaise) : null,
            ),
            const SizedBox(height: 10),
            _row(
              'Delivery fee',
              deliveryFeePaise == 0 ? 'FREE' : formatPaise(deliveryFeePaise),
              valueColor: deliveryFeePaise == 0 ? AppColors.success : null,
            ),
            if (handlingFeePaise > 0) ...[
              const SizedBox(height: 10),
              _row('Handling fee', formatPaise(handlingFeePaise)),
            ],
            if (rainFeePaise > 0) ...[
              const SizedBox(height: 10),
              _row('Rain charge', formatPaise(rainFeePaise)),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            if (walletAppliedPaise > 0) ...[
              _row('Order total', formatPaise(totalPaise)),
              const SizedBox(height: 10),
              _row(
                'm2d wallet',
                '- ${formatPaise(walletAppliedPaise)}',
                valueColor: AppColors.success,
              ),
              const SizedBox(height: 10),
            ],
            _row(
              totalLabel,
              formatPaise(totalPaise - walletAppliedPaise),
              bold: true,
            ),
            if (savingsPaise > 0) ...[
              const SizedBox(height: 12),
              Container(
                key: const ValueKey('savings-banner'),
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.savings_outlined,
                      size: 18,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$savingsVerb ${formatPaise(savingsPaise)} on this '
                        'order',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
    String? struck,
  }) {
    final style = TextStyle(
      fontSize: bold ? 16 : 14,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: AppColors.textDark,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        if (struck != null) ...[
          Text(
            struck,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(value, style: style.copyWith(color: valueColor)),
      ],
    );
  }
}

/// Section heading used on cart / checkout / order pages.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}

/// Pinned bottom action bar with a single primary button.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: child,
        ),
      ),
    );
  }
}
