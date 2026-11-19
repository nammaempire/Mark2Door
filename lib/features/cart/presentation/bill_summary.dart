import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

/// Price breakdown card shared by cart, checkout and order detail.
class BillSummary extends StatelessWidget {
  const BillSummary({
    super.key,
    required this.subtotalPaise,
    required this.deliveryFeePaise,
    required this.totalPaise,
    this.savingsPaise = 0,
    this.totalLabel = 'To pay',
  });

  final int subtotalPaise;
  final int deliveryFeePaise;
  final int totalPaise;
  final int savingsPaise;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row('Item total', formatPaise(subtotalPaise)),
            const SizedBox(height: 10),
            _row(
              'Delivery fee',
              deliveryFeePaise == 0 ? 'FREE' : formatPaise(deliveryFeePaise),
              valueColor: deliveryFeePaise == 0 ? AppColors.success : null,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            _row(totalLabel, formatPaise(totalPaise), bold: true),
            if (savingsPaise > 0) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'You save ${formatPaise(savingsPaise)} on this order',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value,
      {bool bold = false, Color? valueColor}) {
    final style = TextStyle(
      fontSize: bold ? 16 : 14,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: AppColors.textDark,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
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
