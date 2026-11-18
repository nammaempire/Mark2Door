import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_providers.dart';
import '../domain/order.dart';

final ordersProvider = StreamProvider.autoDispose<List<Order>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(orderRepositoryProvider).watchOrders(user.uid);
});

final orderProvider = StreamProvider.autoDispose.family<Order?, String>(
  (ref, id) => ref.watch(orderRepositoryProvider).watchOrder(id),
);
