import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/env.dart';
import 'core/network/offline_gate.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class Mart2DoorApp extends ConsumerWidget {
  const Mart2DoorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
      // Covers every page while the phone has no internet.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        // Follows the phone's font size setting, within limits the
        // screens are built for: very large sizes would push text out of
        // cards and buttons.
        minScaleFactor: 0.9,
        maxScaleFactor: 1.2,
        child: OfflineGate(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
