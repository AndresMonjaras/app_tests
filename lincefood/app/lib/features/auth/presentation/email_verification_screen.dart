import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'email_verification_controller.dart';

class EmailVerificationScreen extends ConsumerWidget {
  const EmailVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(emailVerificationControllerProvider);
    final controller = ref.read(emailVerificationControllerProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final hasSession = state.email.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Verifica tu correo')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasSession) ...[
                const Text(
                  'Confirma tu correo para poder continuar con tus pedidos.',
                ),
                const SizedBox(height: 8),
                Text(
                  state.email,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: state.canResend
                      ? controller.resendVerificationEmail
                      : null,
                  child: Text(_resendButtonLabel(state)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: state.isVerifying
                      ? null
                      : controller.checkVerification,
                  child: state.isVerifying
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Ya verifiqué'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    final signedOut = await controller.signOut();
                    if (signedOut && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Cerrar sesión'),
                ),
              ] else
                const Text(
                  'No hay una sesión iniciada para verificar el correo.',
                ),
              const SizedBox(height: 16),
              if (state.message != null)
                Text(state.message!, style: TextStyle(color: colors.primary)),
              if (state.error != null)
                Text(state.error!, style: TextStyle(color: colors.error)),
            ],
          ),
        ),
      ),
    );
  }

  String _resendButtonLabel(EmailVerificationState state) {
    if (state.isSending) return 'Enviando...';
    if (state.secondsRemaining > 0) {
      return 'Reenviar correo (${state.secondsRemaining}s)';
    }
    return 'Reenviar correo';
  }
}
