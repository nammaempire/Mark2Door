import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../application/pincode_controller.dart';

/// "Sorry, we don't deliver here yet" notice with a way to change the
/// pincode. Takes no space while delivery is available.
class NotServiceableBanner extends ConsumerWidget {
  const NotServiceableBanner({super.key, this.margin = EdgeInsets.zero});

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(canOrderProvider)) return const SizedBox.shrink();
    final pincode = ref.watch(pincodeProvider) ?? '';
    return Container(
      key: const ValueKey('not-serviceable-banner'),
      margin: margin,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD3A3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.location_off_rounded,
              color: AppColors.accentDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Sorry, we don't deliver to $pincode yet",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'You can look around, but ordering is not available in '
                  'this area.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey('change-pincode-button'),
            onPressed: () => context.push(Routes.pincode),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}
