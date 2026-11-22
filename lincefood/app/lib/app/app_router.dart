import 'package:flutter/material.dart';

import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/email_verification_screen.dart';
import '../features/cart/presentation/cart_screen.dart';
import '../features/catalog/presentation/catalog_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/orders/presentation/orders_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/navigation/auth_gate_screen.dart';
import '../features/privacy/privacy_notice_screen.dart';

class AppRouter {
  static const onboarding = '/onboarding';
  static const auth = '/auth';
  static const emailVerification = '/email-verification';
  static const catalog = '/catalog';
  static const cart = '/cart';
  static const orders = '/orders';
  static const profile = '/profile';
  static const privacy = '/privacy';
  static const home = '/home';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final rawPage = switch (settings.name) {
      onboarding => const OnboardingScreen(),
      auth => const AuthScreen(),
      emailVerification => const EmailVerificationScreen(),
      privacy => const PrivacyNoticeScreen(),
      home => const AuthGateScreen(),
      catalog => const ProtectedRoute(child: CatalogScreen()),
      cart => const ProtectedRoute(child: CartScreen()),
      orders => const ProtectedRoute(child: OrdersScreen()),
      profile => const ProtectedRoute(child: ProfileScreen()),
      _ => const _NotFoundScreen(),
    };

    return MaterialPageRoute<void>(
      builder: (context) => rawPage,
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
