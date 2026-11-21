import 'package:flutter/foundation.dart';

@immutable
class Address {
  const Address({
    required this.name,
    required this.phone,
    required this.line1,
    required this.landmark,
    required this.pincode,
    this.lat,
    this.lng,
  });

  final String name;
  final String phone;
  final String line1;
  final String landmark;
  final String pincode;

  /// The exact spot the shopper pinned for this address with "Use my
  /// current location"; null when they did not. The delivery partner's
  /// map goes to this pin instead of guessing from the typed address.
  final double? lat;
  final double? lng;

  bool get hasPin => lat != null && lng != null;

  String get singleLine => [
        line1,
        if (landmark.isNotEmpty) landmark,
        pincode,
      ].join(', ');

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'line1': line1,
        'landmark': landmark,
        'pincode': pincode,
        if (hasPin) 'lat': lat,
        if (hasPin) 'lng': lng,
      };

  /// Two addresses are the same when their text matches; the pin is not
  /// compared, so pinning an address does not save it a second time.
  @override
  bool operator ==(Object other) =>
      other is Address &&
      other.name == name &&
      other.phone == phone &&
      other.line1 == line1 &&
      other.landmark == landmark &&
      other.pincode == pincode;

  @override
  int get hashCode => Object.hash(name, phone, line1, landmark, pincode);

  factory Address.fromMap(Map<String, dynamic> map) => Address(
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        line1: map['line1'] as String? ?? '',
        landmark: map['landmark'] as String? ?? '',
        pincode: map['pincode'] as String? ?? '',
        lat: (map['lat'] as num?)?.toDouble(),
        lng: (map['lng'] as num?)?.toDouble(),
      );
}
