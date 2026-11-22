import 'package:flutter/material.dart';

/// Aviso de privacidad del proyecto académico.
/// No es un aviso institucional: la universidad debe validarlo antes de
/// usar la app con personas reales.
class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  static const _sections = [
    (
      title: 'Qué datos usamos',
      body:
          'Tu nombre, correo, foto de perfil opcional y los pedidos que '
          'realizas. Los usamos para darte acceso, preparar tu comida y '
          'avisarte cuando esté lista.',
    ),
    (
      title: 'Pagos',
      body:
          'Los pagos se procesan con Stripe en modo de prueba. Lincefood no '
          'guarda números de tarjeta: solo el estado del pago de cada pedido.',
    ),
    (
      title: 'Notificaciones',
      body:
          'Los avisos de la cafetería son opcionales y puedes desactivarlos '
          'en Perfil > Notificaciones. Guardamos el identificador del '
          'dispositivo solo para enviarte esos avisos.',
    ),
    (
      title: 'Biometría',
      body:
          'La protección del QR con huella o rostro la resuelve tu teléfono. '
          'La app no recibe ni guarda datos biométricos.',
    ),
    (
      title: 'Dónde se guardan',
      body:
          'En Firebase (Authentication, Realtime Database y Storage). Solo tú '
          'y el personal autorizado de la cafetería pueden ver tus pedidos.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Aviso de privacidad')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            color: colors.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Borrador académico. Antes de usar esta versión con personas '
                'reales, la universidad debe confirmar al responsable, el '
                'contacto, los plazos de conservación y los canales para '
                'ejercer tus derechos.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSecondaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final section in _sections) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(section.body, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
