import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/store_settings.dart';
import '../../../core/providers.dart';
import '../../catalog/domain/promo.dart';

final _storeSettingsStreamProvider = StreamProvider<StoreSettings>(
  (ref) => ref.watch(storeRepositoryProvider).watchSettings(),
);

/// Current delivery settings, synchronously. Uses the built-in defaults
/// while loading or if the settings cannot be read, so pricing always works.
final storeSettingsProvider = Provider<StoreSettings>((ref) {
  return ref.watch(_storeSettingsStreamProvider).valueOrNull ??
      StoreSettings.defaults;
});

final promosProvider = FutureProvider<List<Promo>>(
  (ref) => ref.watch(storeRepositoryProvider).fetchBanners(),
);
