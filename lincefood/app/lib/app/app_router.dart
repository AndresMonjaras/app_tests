import 'package:flutter/material.dart';

import '../features/admin/presentation/admin_catalog_screen.dart';

import '../features/cart/presentation/cart_screen.dart';
import '../features/catalog/presentation/catalog_screen.dart';
import '../features/location/presentation/cafeteria_location_screen.dart';
import '../features/navigation/auth_gate_screen.dart';
import '../features/notifications/presentation/notification_preferences_screen.dart';
import '../features/notifications/presentation/notifications_inbox_screen.dart';
import '../features/orders/presentation/orders_screen.dart';
import '../features/pickup_qr/presentation/pickup_qr_screen.dart';
import '../features/orders/presentation/staff_orders_screen.dart';
import '../features/plans/presentation/plans_screen.dart';
import '../features/privacy/privacy_notice_screen.dart';
import '../features/profile/presentation/profile_screen.dart';

class AppRouter {
  static const onboarding = '/onboarding';
  static const auth = '/auth';
  static const emailVerification = '/email-verification';
  static const home = '/home';
  static const catalog = '/catalog';
  static const admin = '/admin';
  static const cart = '/cart';
  static const orders = '/orders';
  static const staffOrders = '/orders/staff';
  static const map = '/map';
  static const cafeteriaLocation = '/cafeteria/location';
  static const profile = '/profile';
  static const notificationPreferences = '/notification-preferences';
  static const notifications = '/notifications';
  static const pickupQr = '/pickup-qr';
  static const plans = '/plans';
  static const privacy = '/privacy';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final arguments = settings.arguments;
    final orderId = arguments is Map && arguments['orderId'] is String
        ? arguments['orderId'] as String
        : null;
    final page = switch (settings.name) {
      onboarding || auth || emailVerification || home => const AuthGateScreen(),
      admin => const ProtectedRoute(child: AdminCatalogScreen()),
      catalog => const ProtectedRoute(child: CatalogScreen()),
      cart => const ProtectedRoute(child: CartScreen()),
      orders => ProtectedRoute(child: OrdersScreen(orderId: orderId)),
      staffOrders => const ProtectedRoute(child: StaffOrdersScreen()),
      map || cafeteriaLocation => const ProtectedRoute(
        child: CafeteriaLocationScreen(),
      ),
      profile => const ProtectedRoute(child: ProfileScreen()),
      notificationPreferences => const ProtectedRoute(
        child: NotificationPreferencesScreen(),
      ),
      notifications => const ProtectedRoute(child: NotificationsInboxScreen()),
      pickupQr => ProtectedRoute(
        child: orderId == null
            ? const OrdersScreen()
            : PickupQrScreen(orderId: orderId),
      ),
      plans => const ProtectedRoute(child: PlansScreen()),
      // Público: debe poder leerse antes de crear la cuenta.
      privacy => const PrivacyNoticeScreen(),
      _ => const _NotFoundScreen(),
    };

    return MaterialPageRoute<void>(
      builder: (context) => page,
      settings: settings,
    );
  }
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('No encontramos esta sección.')),
    );
  }
}
