import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authFormControllerProvider);
    final controller = ref.read(authFormControllerProvider.notifier);
    final isRegistering = state.mode == AuthFormMode.register;
    final isRecovering = state.mode == AuthFormMode.recover;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                Icon(
                  Icons.local_cafe_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  isRecovering
                      ? 'Recupera tu cuenta'
                      : isRegistering
                      ? 'Crea tu cuenta Lincefood'
                      : 'Inicia sesión',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (isRegistering) ...[
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (isRegistering &&
                                (value?.trim().isEmpty ?? true)) {
                              return 'Escribe tu nombre.';
                            }
                            if ((value?.trim().length ?? 0) > 80) {
                              return 'El nombre no puede superar 80 caracteres.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty || !email.contains('@')) {
                            return 'Escribe un correo válido.';
                          }
                          return null;
                        },
                      ),
                      if (!isRecovering) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          autofillHints: isRegistering
                              ? const [AutofillHints.newPassword]
                              : const [AutofillHints.password],
                          decoration: const InputDecoration(
                            labelText: 'Contraseña',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final password = value ?? '';
                            if (password.isEmpty) {
                              return 'Escribe tu contraseña.';
                            }
                            if (isRegistering && password.length < 8) {
                              return 'Usa al menos 8 caracteres.';
                            }
                            return null;
                          },
                        ),
                      ],
                      if (isRegistering) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmationController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirmar contraseña',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return 'Las contraseñas no coinciden.';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 18),
                      if (state.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            state.error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (state.notice != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            state.notice!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: state.isBusy
                              ? null
                              : () {
                                  if (!_formKey.currentState!.validate()) {
                                    return;
                                  }
                                  controller.submit(
                                    name: _nameController.text,
                                    email: _emailController.text,
                                    password: _passwordController.text,
                                  );
                                },
                          child: state.isBusy
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  isRecovering
                                      ? 'Enviar instrucciones'
                                      : isRegistering
                                      ? 'Crear cuenta'
                                      : 'Entrar',
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isRegistering && !isRecovering) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () =>
                          controller.selectMode(AuthFormMode.recover),
                      child: const Text('Olvidé mi contraseña'),
                    ),
                  ),
                  const Divider(height: 24),
                  OutlinedButton.icon(
                    onPressed: state.isBusy
                        ? null
                        : controller.signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata, size: 26),
                    label: const Text('Continuar con Google'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: state.isBusy
                        ? null
                        : controller.signInWithFacebook,
                    icon: const Icon(Icons.facebook),
                    label: const Text('Continuar con Facebook'),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed: state.isBusy
                      ? null
                      : () => controller.selectMode(
                          isRegistering
                              ? AuthFormMode.signIn
                              : AuthFormMode.register,
                        ),
                  child: Text(
                    isRegistering
                        ? 'Ya tengo cuenta · Iniciar sesión'
                        : 'Crear cuenta nueva',
                  ),
                ),
                if (isRecovering)
                  TextButton(
                    onPressed: () => controller.selectMode(AuthFormMode.signIn),
                    child: const Text('Volver a iniciar sesión'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/privacy'),
                  child: const Text('Aviso de privacidad'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
