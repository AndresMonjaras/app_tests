import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/firebase_bootstrap_provider.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';

class FirebaseBootstrapScreen extends ConsumerWidget {
  const FirebaseBootstrapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseStatus = ref.watch(firebaseBootstrapProvider);

    return firebaseStatus.when(
      data: (status) => switch (status) {
        FirebaseBootstrapStatus.ready => const OnboardingScreen(),
        FirebaseBootstrapStatus.missing => const FirebaseConfigurationScreen(),
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Cargando configuración',
          ),
        ),
      ),
      error: (error, stackTrace) => const FirebaseConfigurationScreen(),
    );
  }
}

class FirebaseConfigurationScreen extends StatelessWidget {
  const FirebaseConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Firebase no está configurado',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Configura Firebase para Android antes de habilitar el inicio '
                'de sesión y el catálogo. Completa la configuración local '
                'sin guardar claves en el repositorio.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
