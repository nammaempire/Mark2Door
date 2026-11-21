import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// A spot on the map.
typedef MapPin = ({double lat, double lng});

/// Why the phone's location could not be read, in words for the shopper.
class LocationFailure implements Exception {
  const LocationFailure(this.message);
  final String message;
}

/// Reads where the phone is, to pin a delivery address on the map.
abstract interface class LocationService {
  /// The phone's current position. Asks for permission the first time.
  /// Throws [LocationFailure] when it cannot be read.
  Future<MapPin> current();
}

/// Sample-data stand-in: a fixed spot in Koramangala, Bengaluru.
class FakeLocationService implements LocationService {
  /// Set to make [current] fail with this message.
  String? failure;

  @override
  Future<MapPin> current() async {
    if (failure != null) throw LocationFailure(failure!);
    return (lat: 12.9352, lng: 77.6245);
  }
}

class DeviceLocationService implements LocationService {
  @override
  Future<MapPin> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationFailure(
          'Turn on location (GPS) on your phone and try again.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const LocationFailure(
          'Allow location for mart2door to pin your address.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationFailure(
          'Location is blocked for mart2door. Allow it in your phone '
          'settings, then try again.',
        );
      }
      final at = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 20));
      return (lat: at.latitude, lng: at.longitude);
    } on LocationFailure {
      rethrow;
    } on TimeoutException {
      throw const LocationFailure(
        "Couldn't find your location. Try again outdoors or near a window.",
      );
    } on Exception {
      throw const LocationFailure("Couldn't read your location. Try again.");
    }
  }
}
