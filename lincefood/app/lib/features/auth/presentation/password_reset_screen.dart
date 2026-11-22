import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'password_reset_controller.dart';

class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  ConsumerState<PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  final _correoController = TextEditingController();

  @override
  void dispose() {
    _correoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(passwordResetControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Escribe el correo con el que te registraste. '
                'Te enviaremos un enlace para restablecer tu contraseña.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _correoController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: estado.puedeEnviar
                    ? () => ref
                          .read(passwordResetControllerProvider.notifier)
                          .enviar(_correoController.text)
                    : null,
                child: Text(_etiquetaBoton(estado)),
              ),
              if (estado.mensaje != null) ...[
                const SizedBox(height: 16),
                Text(estado.mensaje!),
              ],
              if (estado.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  estado.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _etiquetaBoton(PasswordResetState estado) {
    if (estado.enviando) return 'Enviando...';
    if (estado.segundosRestantes > 0) {
      return 'Espera ${estado.segundosRestantes} s';
    }
    return 'Enviar enlace';
  }
}
