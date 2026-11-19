import 'dart:async';

import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

enum PaymentOutcome { success, failed, pending }

@immutable
class PaymentResult {
  const PaymentResult(this.outcome, {this.paymentId, this.message});

  final PaymentOutcome outcome;
  final String? paymentId;
  final String? message;
}

@immutable
class PaymentRequest {
  const PaymentRequest({
    required this.orderId,
    required this.amountPaise,
    required this.phone,
    required this.description,
  });

  final String orderId;
  final int amountPaise;
  final String phone;
  final String description;
}

abstract interface class PaymentGateway {
  /// Never throws: every path resolves to a [PaymentResult].
  Future<PaymentResult> pay(PaymentRequest request);
}

/// Razorpay Standard Checkout.
///
/// PRODUCTION NOTE: before going live, create the Razorpay order and verify
/// the payment signature on a server (Cloud Function) and pass `order_id`
/// below. Client-only confirmation can be spoofed and must not mark an
/// order as paid in production.
class RazorpayPaymentGateway implements PaymentGateway {
  @override
  Future<PaymentResult> pay(PaymentRequest request) {
    final completer = Completer<PaymentResult>();
    final razorpay = Razorpay();

    void finish(PaymentResult result) {
      if (completer.isCompleted) return;
      razorpay.clear();
      completer.complete(result);
    }

    razorpay
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
        finish(PaymentResult(PaymentOutcome.success, paymentId: r.paymentId));
      })
      ..on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
        finish(PaymentResult(PaymentOutcome.failed, message: r.message));
      })
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
        // Wallet apps confirm asynchronously; the server webhook settles it.
        finish(const PaymentResult(PaymentOutcome.pending));
      });

    try {
      razorpay.open({
        'key': Env.razorpayKey,
        'amount': request.amountPaise,
        'currency': 'INR',
        'name': AppConfig.appName,
        'description': request.description,
        'prefill': {'contact': request.phone},
        'notes': {'appOrderId': request.orderId},
        'theme': {'color': '#800020'},
      });
    } catch (e) {
      finish(const PaymentResult(
        PaymentOutcome.failed,
        message: 'Could not open the payment screen.',
      ));
    }
    return completer.future;
  }
}

/// Stand-in used when no Razorpay key is configured: lets you pick the
/// outcome so the success, failure and pending journeys can all be tested.
class SimulatedPaymentGateway implements PaymentGateway {
  SimulatedPaymentGateway(this._navigatorKey);

  final GlobalKey<NavigatorState> _navigatorKey;

  @override
  Future<PaymentResult> pay(PaymentRequest request) async {
    final context = _navigatorKey.currentContext;
    if (context == null) {
      return const PaymentResult(PaymentOutcome.failed);
    }
    final outcome = await showModalBottomSheet<PaymentOutcome>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _SimulatedSheet(request: request),
    );
    switch (outcome) {
      case PaymentOutcome.success:
        return PaymentResult(
          PaymentOutcome.success,
          paymentId: 'pay_demo_${DateTime.now().millisecondsSinceEpoch}',
        );
      case PaymentOutcome.pending:
        return const PaymentResult(PaymentOutcome.pending);
      case PaymentOutcome.failed:
      case null:
        return const PaymentResult(
          PaymentOutcome.failed,
          message: 'Payment was cancelled.',
        );
    }
  }
}

class _SimulatedSheet extends StatelessWidget {
  const _SimulatedSheet({required this.request});

  final PaymentRequest request;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, IconData icon, Color color, PaymentOutcome o) {
      return ListTile(
        key: ValueKey('simulate-${o.name}'),
        leading: Icon(icon, color: color),
        title: Text(label),
        onTap: () => Navigator.of(context).pop(o),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Test payment · ${formatPaise(request.amountPaise)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'No Razorpay key is set, so choose how this payment '
                  'should end.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          option('Payment succeeds', Icons.check_circle_rounded,
              AppColors.success, PaymentOutcome.success),
          option('Payment fails', Icons.cancel_rounded, AppColors.danger,
              PaymentOutcome.failed),
          option('Payment stays pending', Icons.schedule_rounded,
              AppColors.warning, PaymentOutcome.pending),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
