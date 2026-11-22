import 'package:flutter/material.dart';

import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/email_verification_screen.dart';
import '../features/cart/presentation/cart_screen.dart';
import '../features/catalog/presentation/catalog_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/orders/presentation/orders_screen.dart';
import '../features/profile/presentation/profile_screen.dart';

class AppRouter {
  static const onboarding = '/onboarding';
  static const auth = '/auth';
  static const emailVerification = '/email-verification';
  static const catalog = '/catalog';
  static const cart = '/cart';
  static const orders = '/orders';
  static const profile = '/profile';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final page = switch (settings.name) {
      onboarding => const OnboardingScreen(),
      auth => const AuthScreen(),
      emailVerification => const EmailVerificationScreen(),
      catalog => const CatalogScreen(),
      cart => const CartScreen(),
      orders => const OrdersScreen(),
      profile => const ProfileScreen(),
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
