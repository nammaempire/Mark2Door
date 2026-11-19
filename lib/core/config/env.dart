import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Compile-time configuration, supplied with `--dart-define`.
///
/// flutter run --dart-define=RAZORPAY_KEY=rzp_test_xxx
abstract final class Env {
  /// The app uses Firebase unless it is started with
  /// `--dart-define=USE_FIREBASE=false`, which switches to in-memory sample
  /// data. Automated tests always run on sample data.
  static final bool useFirebase = _firebaseFlag && !_runningTests;

  static const bool _firebaseFlag =
      bool.fromEnvironment('USE_FIREBASE', defaultValue: true);

  static bool get _runningTests =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  /// Empty => simulated payment sheet instead of the Razorpay checkout.
  static const String razorpayKey = String.fromEnvironment('RAZORPAY_KEY');

  static bool get useRazorpay => razorpayKey.isNotEmpty;
}

/// Business rules that the admin panel will eventually own.
abstract final class AppConfig {
  static const String appName = 'mart2door';
  static const String countryCode = '+91';
  static const int deliveryFeePaise = 3000;
  static const int freeDeliveryThresholdPaise = 49900;
  static const int maxQtyPerItem = 10;

  /// Delivery promise used to estimate arrival when an order is placed.
  /// The delivery app can overwrite an order's `etaAt` with a live estimate.
  static const int deliveryEtaMinutes = 30;

  /// OTP accepted by the sample-data auth repository.
  static const String demoOtp = '123456';
}
