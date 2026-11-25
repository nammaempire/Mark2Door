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
    this.courierFeePaise = 6000,
    this.courierFreeAbovePaise = 99900,
    this.courierEta = '3 to 5 days',
    this.storeName = '',
    this.storeAddress = '',
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

  /// Outstation (courier) orders: one flat charge, free at or above an
  /// order value, and the delivery time shown to the shopper.
  final int courierFeePaise;
  final int courierFreeAbovePaise;
  final String courierEta;

  /// The store's name and address, printed on invoices. Empty until the
  /// store fills them in under Storefront in the admin web.
  final String storeName;
  final String storeAddress;

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
        courierFeePaise: (map['courierFeePaise'] as num?)?.toInt() ?? 6000,
        courierFreeAbovePaise:
            (map['courierFreeAbovePaise'] as num?)?.toInt() ?? 99900,
        courierEta: _text(map['courierEta'], '3 to 5 days'),
        storeName: (map['storeName'] as String? ?? '').trim(),
        storeAddress: (map['storeAddress'] as String? ?? '').trim(),
      );

  static String _text(Object? value, String fallback) {
    final text = (value as String? ?? '').trim();
    return text.isEmpty ? fallback : text;
  }

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
      other.supportEmail == supportEmail &&
      other.courierFeePaise == courierFeePaise &&
      other.courierFreeAbovePaise == courierFreeAbovePaise &&
      other.courierEta == courierEta &&
      other.storeName == storeName &&
      other.storeAddress == storeAddress;

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
        courierFeePaise,
        courierFreeAbovePaise,
        courierEta,
        storeName,
        storeAddress,
      );
}
