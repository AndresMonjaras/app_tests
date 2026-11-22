import 'package:flutter/material.dart';

// Accesos con proveedores externos. Se muestran siempre; los que no están
// configurados quedan desactivados con una nota, para que el cliente sepa por qué.
class AuthSocialButtons extends StatelessWidget {
  const AuthSocialButtons({
    required this.busy,
    required this.googleEnabled,
    required this.githubEnabled,
    required this.onGoogle,
    required this.onGitHub,
    super.key,
  });

  final bool busy;
  final bool googleEnabled;
  final bool githubEnabled;
  final VoidCallback onGoogle;
  final VoidCallback onGitHub;

  @override
  Widget build(BuildContext context) {
    final allAvailable = googleEnabled && githubEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Expanded(child: Divider()),
            Flexible(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('o continúa con', textAlign: TextAlign.center),
              ),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          style: _socialButtonStyle,
          onPressed: busy || !googleEnabled ? null : onGoogle,
          child: const _ProviderLabel(
            icon: Icons.g_mobiledata,
            text: 'Continuar con Google',
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          style: _socialButtonStyle,
          onPressed: busy || !githubEnabled ? null : onGitHub,
          child: const _ProviderLabel(
            icon: Icons.code,
            text: 'Continuar con GitHub',
          ),
        ),
        if (!allAvailable)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Los métodos atenuados aún no están disponibles. Puedes entrar con tu correo.',
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

// El texto se ajusta en líneas si el usuario amplía la fuente, en lugar de desbordar.
class _ProviderLabel extends StatelessWidget {
  const _ProviderLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24),
        const SizedBox(width: 8),
        Flexible(child: Text(text, textAlign: TextAlign.center)),
      ],
    );
  }
}

const _socialButtonStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(0, 52)),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
  ),
);
