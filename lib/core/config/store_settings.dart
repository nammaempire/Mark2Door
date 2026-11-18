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

  factory StoreSettings.fromMap(Map<String, dynamic> map) => StoreSettings(
        deliveryFeePaise: (map['deliveryFeePaise'] as num?)?.toInt() ??
            defaults.deliveryFeePaise,
        freeDeliveryThresholdPaise:
            (map['freeDeliveryThresholdPaise'] as num?)?.toInt() ??
                defaults.freeDeliveryThresholdPaise,
        deliveryEtaMinutes: (map['deliveryEtaMinutes'] as num?)?.toInt() ??
            defaults.deliveryEtaMinutes,
      );

  @override
  bool operator ==(Object other) =>
      other is StoreSettings &&
      other.deliveryFeePaise == deliveryFeePaise &&
      other.freeDeliveryThresholdPaise == freeDeliveryThresholdPaise &&
      other.deliveryEtaMinutes == deliveryEtaMinutes;

  @override
  int get hashCode => Object.hash(
        deliveryFeePaise,
        freeDeliveryThresholdPaise,
        deliveryEtaMinutes,
      );
}
