import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Order-update notifications for this phone.
abstract interface class PushService {
  /// Asks permission to notify and records this phone as the one to alert
  /// for the customer [uid].
  Future<void> register(String uid);

  /// Stops alerts to this phone for [uid], when the customer logs out.
  Future<void> unregister(String uid);
}

class FakePushService implements PushService {
  @override
  Future<void> register(String uid) async {}

  @override
  Future<void> unregister(String uid) async {}
}

/// Saves the phone's Firebase Cloud Messaging token under
/// `customer_tokens/{uid}`. A server function reads it to tell the
/// customer when their order is placed, assigned, delivered and so on.
class FirebasePushService implements PushService {
  FirebasePushService(this._messaging, this._db);

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;
  StreamSubscription<String>? _refresh;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('customer_tokens').doc(uid);

  Future<void> _save(String uid, String token) => _doc(uid).set({
        'token': token,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

  @override
  Future<void> register(String uid) async {
    if (uid.isEmpty) return;
    // Android 13 and later ask the customer; earlier versions allow it.
    await _messaging.requestPermission();
    final token = await _messaging.getToken();
    if (token != null) await _save(uid, token);
    // Google replaces tokens now and then; keep the saved one current.
    await _refresh?.cancel();
    _refresh = _messaging.onTokenRefresh.listen((t) => _save(uid, t));
  }

  @override
  Future<void> unregister(String uid) async {
    await _refresh?.cancel();
    _refresh = null;
    if (uid.isEmpty) return;
    await _doc(uid).delete();
  }
}
