import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/food_background.dart';
import 'auth_controller.dart';
import 'widgets/auth_brand_header.dart';
import 'widgets/auth_social_buttons.dart';

/// Indica si la contraseña se muestra en texto plano en el formulario.
class AuthPasswordVisibilityController extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final authPasswordVisibleProvider =
    NotifierProvider.autoDispose<AuthPasswordVisibilityController, bool>(
      AuthPasswordVisibilityController.new,
    );

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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(authFormControllerProvider.notifier)
        .submit(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authFormControllerProvider);
    final showPassword = ref.watch(authPasswordVisibleProvider);
    final providers = ref.watch(authProviderAvailabilityProvider);
    final controller = ref.read(authFormControllerProvider.notifier);
    final mode = state.mode;
    final isRegistering = mode == AuthFormMode.register;
    final isRecovering = mode == AuthFormMode.recover;
    final isSigningIn = mode == AuthFormMode.signIn;

    return Scaffold(
      body: FoodBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthBrandHeader(),
                    const SizedBox(height: 24),
                    Text(
                      _titleFor(mode),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _subtitleFor(mode),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            if (isRegistering) ...[
                              TextFormField(
                                enabled: !state.isBusy,
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                decoration: const InputDecoration(
                                  labelText: 'Nombre',
                                ),
                                validator: (value) {
                                  final name = value?.trim() ?? '';
                                  if (name.isEmpty) return 'Escribe tu nombre.';
                                  if (name.length > 80) {
                                    return 'El nombre no puede superar 80 caracteres.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              enabled: !state.isBusy,
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Correo electrónico',
                              ),
                              validator: _validateEmail,
                              onFieldSubmitted: isRecovering
                                  ? (_) => _submit()
                                  : null,
                            ),
                            if (!isRecovering) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                enabled: !state.isBusy,
                                controller: _passwordController,
                                obscureText: !showPassword,
                                autofillHints: isRegistering
                                    ? const [AutofillHints.newPassword]
                                    : const [AutofillHints.password],
                                textInputAction: isRegistering
                                    ? TextInputAction.next
                                    : TextInputAction.done,
                                onFieldSubmitted: isSigningIn
                                    ? (_) => _submit()
                                    : null,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  suffixIcon: IconButton(
                                    tooltip: showPassword
                                        ? 'Ocultar contraseña'
                                        : 'Mostrar contraseña',
                                    onPressed: state.isBusy
                                        ? null
                                        : () => ref
                                              .read(
                                                authPasswordVisibleProvider
                                                    .notifier,
                                              )
                                              .toggle(),
                                    icon: Icon(
                                      showPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) => isRegistering
                                    ? _validatePassword(value)
                                    : (value == null || value.isEmpty
                                          ? 'Escribe tu contraseña.'
                                          : null),
                              ),
                            ],
                            if (isRegistering) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                enabled: !state.isBusy,
                                controller: _confirmationController,
                                obscureText: !showPassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: const InputDecoration(
                                  labelText: 'Confirmar contraseña',
                                ),
                                validator: (value) {
                                  if (value != _passwordController.text) {
                                    return 'Las contraseñas no coinciden.';
                                  }
                                  return null;
                                },
                              ),
                            ],
                            if (isSigningIn)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: state.isBusy
                                      ? null
                                      : () => controller.selectMode(
                                          AuthFormMode.recover,
                                        ),
                                  child: const Text('Olvidé mi contraseña'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (state.error != null || state.notice != null)
                      _FeedbackBanner(
                        message: state.error ?? state.notice!,
                        isError: state.error != null,
                      ),
                    FilledButton(
                      onPressed: state.isBusy ? null : _submit,
                      child: state.isBusy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                semanticsLabel: 'Procesando',
                              ),
                            )
                          : Text(_actionLabelFor(mode)),
                    ),
                    if (!isRecovering) ...[
                      const SizedBox(height: 24),
                      AuthSocialButtons(
                        busy: state.isBusy,
                        googleEnabled: providers.google,
                        githubEnabled: providers.github,
                        onGoogle: controller.signInWithGoogle,
                        onGitHub: controller.signInWithGitHub,
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: state.isBusy
                          ? null
                          : () => controller.selectMode(_switchTargetFor(mode)),
                      child: Text(_switchLabelFor(mode)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _titleFor(AuthFormMode mode) => switch (mode) {
    AuthFormMode.signIn => 'Inicia sesión',
    AuthFormMode.register => 'Crea tu cuenta Lincefood',
    AuthFormMode.recover => 'Recupera tu cuenta',
  };

  String _subtitleFor(AuthFormMode mode) => switch (mode) {
    AuthFormMode.signIn => 'Entra para pedir y seguir tu pedido.',
    AuthFormMode.register =>
      'Crea tu cuenta para pedir y recoger tu pedido en la cafetería.',
    AuthFormMode.recover => 'Escribe tu correo y te enviaremos instrucciones para crear una contraseña nueva.',
  };

  String _actionLabelFor(AuthFormMode mode) => switch (mode) {
    AuthFormMode.signIn => 'Entrar',
    AuthFormMode.register => 'Crear cuenta',
    AuthFormMode.recover => 'Enviar instrucciones',
  };

  String _switchLabelFor(AuthFormMode mode) => switch (mode) {
    AuthFormMode.signIn => 'Crear cuenta nueva',
    AuthFormMode.register => 'Ya tengo cuenta · Iniciar sesión',
    AuthFormMode.recover => 'Volver a iniciar sesión',
  };

  AuthFormMode _switchTargetFor(AuthFormMode mode) => switch (mode) {
    AuthFormMode.signIn => AuthFormMode.register,
    AuthFormMode.register => AuthFormMode.signIn,
    AuthFormMode.recover => AuthFormMode.signIn,
  };

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    final isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    return isValid ? null : 'Escribe un correo válido.';
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres.';
    }
    return null;
  }
}

// Mensaje de estado del formulario. Se anuncia a lectores de pantalla al aparecer.
class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isError ? scheme.error : scheme.primary;

    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: TextStyle(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}
