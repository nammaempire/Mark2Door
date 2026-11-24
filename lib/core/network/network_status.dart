import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';

/// Whether the phone can reach the internet right now.
enum NetworkState {
  /// Just started: not known yet.
  checking,
  online,
  offline,
}

/// Finds out whether the internet can be reached.
abstract interface class NetworkProbe {
  Future<bool> reachable();
}

/// Tries to open a connection to the store's backend. Being connected to
/// Wi-Fi or mobile data is not enough; this checks that data actually
/// gets through.
class DeviceNetworkProbe implements NetworkProbe {
  const DeviceNetworkProbe();

  @override
  Future<bool> reachable() async {
    try {
      final socket = await Socket.connect(
        'firestore.googleapis.com',
        443,
        timeout: const Duration(seconds: 4),
      );
      socket.destroy();
      return true;
    } on Exception {
      return false;
    }
  }
}

final networkProbeProvider = Provider<NetworkProbe?>(
  // Sample data lives in the app and needs no internet, so nothing is
  // checked there (and in tests).
  (ref) => Env.useFirebase ? const DeviceNetworkProbe() : null,
);

final networkStateProvider =
    NotifierProvider<NetworkStatus, NetworkState>(NetworkStatus.new);

/// Keeps checking the connection: often while offline, so the app comes
/// back by itself the moment the network returns, and now and then while
/// online.
class NetworkStatus extends Notifier<NetworkState> {
  static const _whileOffline = Duration(seconds: 3);
  static const _whileOnline = Duration(seconds: 10);

  Timer? _timer;
  bool _checking = false;

  @override
  NetworkState build() {
    final probe = ref.watch(networkProbeProvider);
    ref.onDispose(() => _timer?.cancel());
    if (probe == null) return NetworkState.online;
    Future.microtask(check);
    return NetworkState.checking;
  }

  /// Checks now. Also called by "Try again" on the no-internet page.
  Future<void> check() async {
    final probe = ref.read(networkProbeProvider);
    if (probe == null || _checking) return;
    _checking = true;
    try {
      var ok = await probe.reachable();
      // One missed try on a weak signal is not "offline": look twice.
      if (!ok && state == NetworkState.online) {
        await Future<void>.delayed(const Duration(seconds: 1));
        ok = await probe.reachable();
      }
      state = ok ? NetworkState.online : NetworkState.offline;
    } finally {
      _checking = false;
      _timer?.cancel();
      _timer = Timer(
        state == NetworkState.online ? _whileOnline : _whileOffline,
        check,
      );
    }
  }
}
