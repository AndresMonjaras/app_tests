import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/preferences/app_preferences_controller.dart';
import '../auth/presentation/auth_controller.dart';
import '../auth/presentation/auth_screen.dart';
import '../auth/presentation/email_verification_screen.dart';
import '../onboarding/presentation/onboarding_screen.dart';
import '../profile/data/firebase_profile_repository.dart';
import '../../core/notifications/notification_providers.dart';
import 'app_navigation_shell.dart';

class AuthGateScreen extends ConsumerWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authUserProvider, (previous, next) {
      final previousUid = previous?.asData?.value?.uid;
      final currentUid = next.asData?.value?.uid;
      if (previousUid != null && previousUid != currentUid) {
        unawaited(
          ref
              .read(firebaseNotificationServiceProvider)
              .clearDeviceSubscriptions(),
        );
      }
    });
    final preferences = ref.watch(appPreferencesProvider);
    return preferences.when(
      loading: () => const _LoadingScreen(),
      error: (_, _) => const AuthScreen(),
      data: (value) {
        if (!value.onboardingComplete) return const OnboardingScreen();
        final auth = ref.watch(authUserProvider);
        return auth.when(
          loading: () => const _LoadingScreen(),
          error: (_, _) => const AuthScreen(),
          data: (user) {
            if (user == null) return const AuthScreen();
            if (!user.emailVerified) return const EmailVerificationScreen();
            ref.watch(profileSyncProvider);
            return const AppNavigationShell();
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class ProtectedRoute extends ConsumerWidget {
  const ProtectedRoute({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authUserProvider);
    return auth.when(
      loading: () => const _LoadingScreen(),
      error: (_, _) => const AuthScreen(),
      data: (user) {
        if (user == null) return const AuthScreen();
        if (!user.emailVerified) return const EmailVerificationScreen();
        return child;
      },
    );
  }
}
