import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../store/application/store_providers.dart';
import '../application/pincode_controller.dart';
import '../data/service_area_repository.dart';

/// The Instant / Outstation switch, shown only to shoppers whose own
/// pincode has no instant delivery. Takes no space for everyone else.
class ShopTabs extends ConsumerWidget {
  const ShopTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(outOfAreaProvider)) return const SizedBox.shrink();
    final mode = ref.watch(shopTabProvider);

    Widget tab(ShopMode value, IconData icon, String label, String hint) {
      final selected = mode == value;
      final tint = value == ShopMode.outstation
          ? AppColors.outstation
          : AppColors.primary;
      return Expanded(
        child: InkWell(
          key: ValueKey('tab-${value.name}'),
          onTap: () => ref.read(shopTabProvider.notifier).show(value),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? tint : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: selected ? Colors.white : tint,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  hint,
                  style: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? const Color(0xD9FFFFFF)
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      key: const ValueKey('shop-tabs'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          tab(ShopMode.instant, Icons.bolt_rounded, 'Instant', 'In minutes'),
          const SizedBox(width: 4),
          tab(
            ShopMode.outstation,
            Icons.local_shipping_rounded,
            'Outstation',
            'All India delivery',
          ),
        ],
      ),
    );
  }
}

/// Instant tab for a shopper whose pincode we do not serve: says sorry,
/// and lets them pick a pincode we do serve to order for an address there.
class InstantUnavailablePanel extends ConsumerWidget {
  const InstantUnavailablePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pincode = ref.watch(pincodeProvider) ?? '';
    final areas = ref.watch(serviceAreasProvider);
    return SingleChildScrollView(
      key: const ValueKey('instant-unavailable'),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_off_rounded,
              size: 40,
              color: AppColors.accentDark,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Sorry, we do not deliver instantly to $pincode yet',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ordering for your home or family in an area we serve? Choose '
            'that pincode and we will deliver there in minutes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          areas.when(
            data: (list) => list.isEmpty
                ? const Text(
                    'Instant delivery areas will be listed here soon.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  )
                : _AreaPicker(areas: list),
            loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
            error: (_, __) => TextButton.icon(
              onPressed: () => ref.invalidate(serviceAreasProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Could not load the areas. Try again'),
            ),
          ),
          const SizedBox(height: 22),
          const Divider(),
          const SizedBox(height: 14),
          const Text(
            'Want it delivered where you are now?',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          TextButton.icon(
            key: const ValueKey('go-outstation-button'),
            onPressed: () => ref
                .read(shopTabProvider.notifier)
                .show(ShopMode.outstation),
            icon: const Icon(Icons.local_shipping_rounded),
            label: const Text('See Outstation products'),
          ),
        ],
      ),
    );
  }
}

class _AreaPicker extends ConsumerWidget {
  const _AreaPicker({required this.areas});

  final List<ServiceArea> areas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropdownButtonFormField<String>(
      key: const ValueKey('service-pincode-dropdown'),
      isExpanded: true,
      menuMaxHeight: 360,
      decoration: const InputDecoration(
        labelText: 'Pincodes we deliver to',
        prefixIcon: Icon(Icons.location_on_rounded),
      ),
      hint: const Text('Choose a pincode'),
      items: [
        for (final area in areas)
          DropdownMenuItem(
            key: ValueKey('service-pincode-${area.pincode}'),
            value: area.pincode,
            child: Text(area.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) =>
          ref.read(instantPincodeProvider.notifier).set(value),
    );
  }
}

/// One line at the top of the store telling an out-of-area shopper what
/// they are looking at: instant delivery to the pincode they picked, or
/// courier delivery to their own. Takes no space inside the delivery area.
class DeliveryModeBanner extends ConsumerWidget {
  const DeliveryModeBanner({super.key, this.margin = EdgeInsets.zero});

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(outOfAreaProvider)) return const SizedBox.shrink();
    final outstation = ref.watch(shopModeProvider) == ShopMode.outstation;
    final pincode = ref.watch(deliveryPincodeProvider) ?? '';
    final String title;
    final String detail;
    if (outstation) {
      final days = ref.watch(storeSettingsProvider).courierEta;
      title = 'Outstation delivery to $pincode';
      detail = 'Reaches you in $days. Pay online.';
    } else {
      final areas = ref.watch(serviceAreasProvider).valueOrNull ?? const [];
      final name = areas
          .where((a) => a.pincode == pincode)
          .map((a) => a.name)
          .firstOrNull;
      title = 'Instant delivery to $pincode';
      detail = name == null || name.isEmpty
          ? 'For an address in this pincode.'
          : '$name. For an address in this pincode.';
    }
    return Container(
      key: const ValueKey('delivery-mode-banner'),
      margin: margin,
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: outstation ? AppColors.outstationSoft : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            outstation ? Icons.local_shipping_rounded : Icons.bolt_rounded,
            color: outstation ? AppColors.outstation : AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (!outstation)
            TextButton(
              key: const ValueKey('change-instant-pincode'),
              onPressed: () =>
                  ref.read(instantPincodeProvider.notifier).set(null),
              child: const Text('Change'),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}
