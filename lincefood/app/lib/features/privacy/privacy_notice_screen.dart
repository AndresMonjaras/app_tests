import 'package:flutter/material.dart';

class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aviso de privacidad')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Text(
            'Borrador académico',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            'Lincefood tratará los datos de cuenta y pedidos para habilitar '
            'el acceso y la recogida de alimentos. Firebase proporciona '
            'autenticación y sincronización; los avisos son opcionales. La '
            'aplicación no almacena datos de tarjeta ni datos biométricos.',
          ),
          SizedBox(height: 12),
          Text(
            'Antes de usar esta versión con personas reales, la universidad '
            'debe confirmar al responsable, contacto, ubicación, plazos de '
            'conservación y canales para ejercer derechos. Este texto todavía '
            'no es un aviso institucional aprobado.',
          ),
        ],
      ),
    );
  }
}
