import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/preferences/app_preferences_controller.dart';
import '../auth/presentation/auth_controller.dart';
import '../auth/presentation/auth_screen.dart';
import '../auth/presentation/email_verification_screen.dart';
import '../onboarding/presentation/onboarding_screen.dart';
import 'app_navigation_shell.dart';

class AuthGateScreen extends ConsumerWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authUserProvider);
    return auth.when(
      loading: () => const _LoadingScreen(),
      error: (_, _) => _ProblemScreen(
        message: 'No pudimos consultar tu sesión.',
        onRetry: () => ref.invalidate(authUserProvider),
      ),
      data: (user) {
        if (user == null) return const AuthScreen();
        if (!user.emailVerified) return const EmailVerificationScreen();
        final preferences = ref.watch(appPreferencesProvider);
        return preferences.when(
          loading: () => const _LoadingScreen(),
          error: (_, _) => _ProblemScreen(
            message: 'No pudimos cargar tus preferencias.',
            onRetry: () => ref.invalidate(appPreferencesProvider),
          ),
          data: (value) {
            if (!value.onboardingComplete) {
              return OnboardingScreen(
                themeMode: value.themeMode,
                onThemeChanged: (mode) => _saveTheme(context, ref, mode),
                onCompleted: () => _finishOnboarding(context, ref),
              );
            }
            return const AppNavigationShell();
          },
        );
      },
    );
  }

  Future<void> _saveTheme(
    BuildContext context,
    WidgetRef ref,
    ThemeMode mode,
  ) async {
    try {
      await ref.read(appPreferencesProvider.notifier).setThemeMode(mode);
    } catch (_) {
      if (context.mounted) {
        _showPreferenceError(context);
      }
    }
  }

  Future<void> _finishOnboarding(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(appPreferencesProvider.notifier).finishOnboarding();
    } catch (_) {
      if (context.mounted) {
        _showPreferenceError(context);
      }
    }
  }

  void _showPreferenceError(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('No se pudieron guardar tus preferencias.'),
        ),
      );
  }
}

class ProtectedRoute extends ConsumerWidget {
  const ProtectedRoute({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider);
    return preferences.when(
      loading: () => const _LoadingScreen(),
      error: (_, _) => _ProblemScreen(
        message: 'No pudimos cargar tus preferencias.',
        onRetry: () => ref.invalidate(appPreferencesProvider),
      ),
      data: (value) {
        if (!value.onboardingComplete) return const AuthGateScreen();

        final auth = ref.watch(authUserProvider);
        return auth.when(
          loading: () => const _LoadingScreen(),
          error: (_, _) => _ProblemScreen(
            message: 'No pudimos consultar tu sesión.',
            onRetry: () => ref.invalidate(authUserProvider),
          ),
          data: (user) {
            if (user == null || !user.emailVerified) {
              return const AuthGateScreen();
            }
            return child;
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _ProblemScreen extends StatelessWidget {
  const _ProblemScreen({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      ),
    );
  }
}
