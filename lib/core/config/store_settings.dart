import 'package:flutter/foundation.dart';

import 'env.dart';

/// Delivery charges and promise, managed from the admin web
/// (Firestore document `settings/store`). Falls back to [defaults] until
/// the admin has saved anything.
@immutable
class StoreSettings {
  const StoreSettings({
    required this.deliveryFeePaise,
    required this.freeDeliveryThresholdPaise,
    required this.deliveryEtaMinutes,
    this.handlingFeeEnabled = false,
    this.handlingFeePaise = 0,
    this.rainFeeEnabled = false,
    this.rainFeePaise = 0,
    this.supportEmail = '',
  });

  static const defaults = StoreSettings(
    deliveryFeePaise: AppConfig.deliveryFeePaise,
    freeDeliveryThresholdPaise: AppConfig.freeDeliveryThresholdPaise,
    deliveryEtaMinutes: AppConfig.deliveryEtaMinutes,
  );

  final int deliveryFeePaise;

  /// Orders at or above this subtotal are delivered free.
  final int freeDeliveryThresholdPaise;
  final int deliveryEtaMinutes;

  /// Extra charges the admin can switch on and off. A charge is added to
  /// the order, and shown to the shopper, only while it is enabled.
  final bool handlingFeeEnabled;
  final int handlingFeePaise;
  final bool rainFeeEnabled;
  final int rainFeePaise;

  /// Where "Email us" on the help page writes to; empty hides the button.
  final String supportEmail;

  factory StoreSettings.fromMap(Map<String, dynamic> map) => StoreSettings(
        deliveryFeePaise: (map['deliveryFeePaise'] as num?)?.toInt() ??
            defaults.deliveryFeePaise,
        freeDeliveryThresholdPaise:
            (map['freeDeliveryThresholdPaise'] as num?)?.toInt() ??
                defaults.freeDeliveryThresholdPaise,
        deliveryEtaMinutes: (map['deliveryEtaMinutes'] as num?)?.toInt() ??
            defaults.deliveryEtaMinutes,
        handlingFeeEnabled: map['handlingFeeEnabled'] as bool? ?? false,
        handlingFeePaise: (map['handlingFeePaise'] as num?)?.toInt() ?? 0,
        rainFeeEnabled: map['rainFeeEnabled'] as bool? ?? false,
        rainFeePaise: (map['rainFeePaise'] as num?)?.toInt() ?? 0,
        supportEmail: (map['supportEmail'] as String? ?? '').trim(),
      );

  @override
  bool operator ==(Object other) =>
      other is StoreSettings &&
      other.deliveryFeePaise == deliveryFeePaise &&
      other.freeDeliveryThresholdPaise == freeDeliveryThresholdPaise &&
      other.deliveryEtaMinutes == deliveryEtaMinutes &&
      other.handlingFeeEnabled == handlingFeeEnabled &&
      other.handlingFeePaise == handlingFeePaise &&
      other.rainFeeEnabled == rainFeeEnabled &&
      other.rainFeePaise == rainFeePaise &&
      other.supportEmail == supportEmail;

  @override
  int get hashCode => Object.hash(
        deliveryFeePaise,
        freeDeliveryThresholdPaise,
        deliveryEtaMinutes,
        handlingFeeEnabled,
        handlingFeePaise,
        rainFeeEnabled,
        rainFeePaise,
        supportEmail,
      );
}
