import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
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
  /// True when a successful payment is checked and recorded by the
  /// server, so the app must not mark the order paid itself.
  bool get confirmsOnServer;

  /// Never throws: every path resolves to a [PaymentResult].
  Future<PaymentResult> pay(PaymentRequest request);
}

/// Online payment through Razorpay, with the server in charge of the
/// money. The app never holds the secret key and cannot mark an order paid:
///
/// 1. The server (`createPaymentOrder`) opens a Razorpay order for the
///    amount due on the saved order, and sends back the public key id.
/// 2. Razorpay's own screen takes the payment: UPI, cards, net banking,
///    wallets.
/// 3. The server (`verifyPayment`) checks Razorpay's signature and marks
///    the order paid. If that call does not get through, the payment shows
///    as pending and Razorpay's webhook settles it.
class RazorpayPaymentGateway implements PaymentGateway {
  RazorpayPaymentGateway(this._functions);

  final FirebaseFunctions _functions;

  @override
  bool get confirmsOnServer => true;

  @override
  Future<PaymentResult> pay(PaymentRequest request) async {
    final String keyId;
    final String razorpayOrderId;
    final int amountPaise;
    try {
      final opened = await _functions
          .httpsCallable('createPaymentOrder')
          .call<Map<Object?, Object?>>({'orderId': request.orderId}).timeout(
              const Duration(seconds: 30));
      keyId = opened.data['keyId']! as String;
      razorpayOrderId = opened.data['razorpayOrderId']! as String;
      amountPaise = (opened.data['amountPaise']! as num).toInt();
    } on FirebaseFunctionsException catch (e) {
      return PaymentResult(
        PaymentOutcome.failed,
        message: e.message ?? 'Could not start the payment.',
      );
    } catch (_) {
      return const PaymentResult(
        PaymentOutcome.failed,
        message: 'Could not start the payment. Check your internet and try '
            'again.',
      );
    }

    final completer = Completer<PaymentResult>();
    final razorpay = Razorpay();

    void finish(PaymentResult result) {
      if (completer.isCompleted) return;
      razorpay.clear();
      completer.complete(result);
    }

    Future<void> confirm(PaymentSuccessResponse paid) async {
      try {
        await _functions
            .httpsCallable('verifyPayment')
            .call<Map<Object?, Object?>>({
          'orderId': request.orderId,
          'razorpayPaymentId': paid.paymentId,
          'razorpaySignature': paid.signature,
        }).timeout(const Duration(seconds: 30));
        finish(
            PaymentResult(PaymentOutcome.success, paymentId: paid.paymentId));
      } on FirebaseFunctionsException catch (e) {
        // The server looked and refused: this payment is not genuine.
        finish(
          e.code == 'permission-denied'
              ? PaymentResult(PaymentOutcome.failed, message: e.message)
              : const PaymentResult(PaymentOutcome.pending),
        );
      } catch (_) {
        // The money was taken but the server could not be reached. The
        // webhook confirms it; until then the order shows as pending.
        finish(const PaymentResult(PaymentOutcome.pending));
      }
    }

    razorpay
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, confirm)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
        finish(
          PaymentResult(
            PaymentOutcome.failed,
            message: r.code == Razorpay.PAYMENT_CANCELLED
                ? 'Payment cancelled.'
                : r.message,
          ),
        );
      })
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
        // Wallet apps confirm later; the server webhook settles it.
        finish(const PaymentResult(PaymentOutcome.pending));
      });

    try {
      razorpay.open({
        'key': keyId,
        'order_id': razorpayOrderId,
        'amount': amountPaise,
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

/// Stand-in used with sample data (no Firebase): lets you pick the outcome
/// so the success, failure and pending journeys can all be tried.
class SimulatedPaymentGateway implements PaymentGateway {
  SimulatedPaymentGateway(this._navigatorKey);

  final GlobalKey<NavigatorState> _navigatorKey;

  @override
  bool get confirmsOnServer => false;

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
