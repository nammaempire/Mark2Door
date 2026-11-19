import 'package:flutter/foundation.dart';

@immutable
class Address {
  const Address({
    required this.name,
    required this.phone,
    required this.line1,
    required this.landmark,
    required this.pincode,
  });

  final String name;
  final String phone;
  final String line1;
  final String landmark;
  final String pincode;

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
      };

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
      );
}
