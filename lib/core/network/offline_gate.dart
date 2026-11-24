import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../widgets/shimmer.dart';
import 'network_status.dart';

/// Covers the app while the phone has no internet, so the shopper never
/// sees stale or half-loaded content: a shimmer placeholder first, then
/// after [messageAfter] a "please connect" page. The moment the network
/// is back the cover lifts and the app carries on where it was.
class OfflineGate extends ConsumerStatefulWidget {
  const OfflineGate({super.key, required this.child});

  final Widget child;

  /// How long the shimmer shows before the message replaces it.
  static const messageAfter = Duration(seconds: 3);

  @override
  ConsumerState<OfflineGate> createState() => _OfflineGateState();
}

class _OfflineGateState extends ConsumerState<OfflineGate> {
  Timer? _timer;
  bool _showMessage = false;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    // Start the countdown for whatever the state is when the app opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onState(null, ref.read(networkStateProvider));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onState(NetworkState? before, NetworkState now) {
    if (now == NetworkState.online) {
      _timer?.cancel();
      _timer = null;
      if (_showMessage) setState(() => _showMessage = false);
      return;
    }
    // Not connected (or not known yet): start the countdown once.
    _timer ??= Timer(OfflineGate.messageAfter, () {
      if (mounted) setState(() => _showMessage = true);
    });
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    await ref.read(networkStateProvider.notifier).check();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(networkStateProvider, _onState);
    final state = ref.watch(networkStateProvider);
    final covered = state != NetworkState.online;
    return Stack(
      children: [
        // Kept in place underneath, so nothing the shopper was doing is
        // lost while the connection is away.
        widget.child,
        if (covered)
          Positioned.fill(
            child: Material(
              key: const ValueKey('offline-cover'),
              color: AppColors.background,
              child: SafeArea(
                child: _showMessage
                    ? _NoInternet(retrying: _retrying, onRetry: _retry)
                    : const _Loading(),
              ),
            ),
          ),
      ],
    );
  }
}

/// The shimmer shown for the first few seconds without a connection.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      key: ValueKey('offline-shimmer'),
      child: SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SkeletonBox(height: 52, radius: 16),
            ),
            SizedBox(height: 16),
            BannerSkeleton(),
            SizedBox(height: 20),
            SizedBox(height: 112, child: CategoryStripSkeleton()),
            SizedBox(height: 20),
            ProductRailSkeleton(),
            SizedBox(height: 20),
            ProductRailSkeleton(),
          ],
        ),
      ),
    );
  }
}

class _NoInternet extends StatelessWidget {
  const _NoInternet({required this.retrying, required this.onRetry});

  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('offline-message'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No internet connection',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please connect to Wi-Fi or mobile data. The app will '
              'continue by itself as soon as you are back online.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const ValueKey('offline-retry-button'),
              onPressed: retrying ? null : onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(retrying ? 'Checking' : 'Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
