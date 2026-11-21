import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/catalog/presentation/home_screen.dart';
import '../../features/catalog/presentation/home_shell.dart';
import '../../features/catalog/presentation/product_detail_screen.dart';
import '../../features/catalog/presentation/product_list_screen.dart';
import '../../features/checkout/data/payment_gateway.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/checkout/presentation/order_result_screen.dart';
import '../../features/checkout/presentation/result_animation.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/rewards/presentation/invite_screen.dart';
import '../../features/rewards/presentation/wallet_screen.dart';
import '../../features/service_area/application/pincode_controller.dart';
import '../../features/service_area/presentation/pincode_screen.dart';
import '../../features/support/presentation/help_screen.dart';
import '../../features/support/presentation/legal_screen.dart';
import '../providers.dart';

/// Route locations in one place so screens never hand-build path strings.
abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const otp = '/otp';
  static const pincode = '/pincode';
  static const home = '/home';
  static const orders = '/orders';
  static const profile = '/profile';
  static const cart = '/home/cart';
  static const checkout = '/home/checkout';

  static String product(String id) => '/home/product/$id';
  static String category(String id) => '/home/category/$id';
  static String order(String id) => '/orders/$id';
  static String refund(String id) => '/orders/$id/refund';
  static const invite = '/profile/invite';
  static const wallet = '/profile/wallet';
  static const help = '/profile/help';
  static String legal(String pageId) => '/profile/legal/$pageId';

  /// The same legal pages, readable before logging in.
  static String publicLegal(String pageId) => '/legal/$pageId';
  static String orderResult(String id, PaymentOutcome outcome) =>
      '/home/order-result/$id?outcome=${outcome.name}';
}

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run `redirect` whenever the session or the delivery pincode changes.
  final refresh = _RouterRefresh();
  ref
    ..listen(authStateProvider, (_, __) => refresh.notify())
    ..listen(pincodeProvider, (_, __) => refresh.notify())
    ..onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.matchedLocation;
      if (location == Routes.splash) return null;

      // Terms and the privacy policy can be read without an account.
      if (location.startsWith('/legal/')) return null;

      final loggedIn = ref.read(authRepositoryProvider).currentUser != null;
      final onAuthPage = location == Routes.login || location == Routes.otp;
      if (!loggedIn) return onAuthPage ? null : Routes.login;

      final hasPincode = ref.read(pincodeProvider) != null;
      if (onAuthPage) return hasPincode ? Routes.home : Routes.pincode;
      if (!hasPincode && location != Routes.pincode) return Routes.pincode;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.otp,
        redirect: (context, state) =>
            state.extra is OtpArgs ? null : Routes.login,
        builder: (context, state) => OtpScreen(args: state.extra! as OtpArgs),
      ),
      GoRoute(
        path: Routes.pincode,
        builder: (context, state) => const PincodeScreen(),
      ),
      GoRoute(
        path: '/legal/:page',
        builder: (context, state) => LegalScreen(
          pageId: state.pathParameters['page']!,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'product/:id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => ProductDetailScreen(
                      productId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: 'category/:id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => ProductListScreen(
                      categoryId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: 'cart',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const CartScreen(),
                  ),
                  GoRoute(
                    path: 'checkout',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const CheckoutScreen(),
                  ),
                  GoRoute(
                    path: 'order-result/:id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => OrderResultScreen(
                      orderId: state.pathParameters['id']!,
                      // PaymentOutcome and ResultKind share these names.
                      outcome: ResultKind.values.firstWhere(
                        (o) =>
                            o != ResultKind.refunded &&
                            o.name == state.uri.queryParameters['outcome'],
                        orElse: () => ResultKind.pending,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.orders,
                builder: (context, state) => const OrdersScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => OrderDetailScreen(
                      orderId: state.pathParameters['id']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'refund',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => OrderResultScreen(
                          orderId: state.pathParameters['id']!,
                          outcome: ResultKind.refunded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'invite',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const InviteScreen(),
                  ),
                  GoRoute(
                    path: 'wallet',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const WalletScreen(),
                  ),
                  GoRoute(
                    path: 'help',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const HelpScreen(),
                  ),
                  GoRoute(
                    path: 'legal/:page',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => LegalScreen(
                      pageId: state.pathParameters['page']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
