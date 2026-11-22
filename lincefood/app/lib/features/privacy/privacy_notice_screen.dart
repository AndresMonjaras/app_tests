import 'package:flutter/material.dart';

class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aviso de privacidad')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: const [
          _DraftNoticeBanner(),
          SizedBox(height: 20),
          _NoticeSection(
            title: 'Quién es responsable',
            content:
                'Institución indicada por el equipo del proyecto: Tecnológico '
                'Nacional de México, Instituto Tecnológico de Celaya. '
                'Domicilio: Antonio García '
                'Cubas Pte. #600, esquina con Av. Tecnológico, Celaya, '
                'Guanajuato, México. Canal de contacto: '
                'direccion@itcelaya.edu.mx.',
          ),
          _NoticeSection(
            title: 'Datos que utiliza la aplicación',
            content:
                'Datos de cuenta: nombre, correo, identificador de usuario, '
                'proveedor de inicio de sesión y estado de verificación. '
                'Datos de servicio: productos, cantidades, importe, estado y '
                'fechas del pedido. Si activas avisos, se usan preferencias y '
                'un token técnico del dispositivo. Si agregas un avatar, se '
                'guarda el archivo de imagen. Stripe procesa los datos de pago '
                'en su interfaz; Lincefood no almacena el número de tarjeta ni '
                'el código de seguridad.',
          ),
          _NoticeSection(
            title: 'Finalidades',
            content:
                'Crear y proteger tu cuenta, mostrar tu perfil, recibir y '
                'atender pedidos, permitir el seguimiento y la recogida, '
                'gestionar pagos de prueba y, cuando lo permitas, enviarte '
                'avisos generales o locales. La ubicación del dispositivo se '
                'solicita solo si eliges centrar el mapa en tu posición; la '
                'app no necesita guardarla para realizar pedidos. La biometría '
                'se comprueba en el dispositivo para proteger el QR; la app no '
                'recibe ni guarda huellas, plantillas o imágenes biométricas.',
          ),
          _NoticeSection(
            title: 'Servicios que participan',
            content:
                'Firebase/Google proporciona autenticación, base de datos, '
                'almacenamiento y mensajería. Google o GitHub autentican la '
                'cuenta cuando eliges esos métodos. Google Maps presenta el '
                'mapa y puede recibir solicitudes de ubicación si eliges '
                'mostrar tu posición. Stripe procesa los pagos de prueba. ',
          ),
          _NoticeSection(
            title: 'Conservación y eliminación',
            content:
                'Propuesta académica para este prototipo: conservar los '
                'datos de prueba mientras dure la evaluación y eliminarlos o '
                'anonimizarlos dentro de los 90 días posteriores a su cierre. '
                'Retirar el avatar junto con el perfil al atender la baja. '
                'Esta propuesta no sustituye los plazos institucionales ni '
                'los plazos propios de Stripe y Google. La app no tiene una '
                'función de autoeliminación. Para el prototipo se propone '
                'solicitar la baja a direccion@itcelaya.edu.mx desde el correo '
                'de la cuenta; el equipo verificaría la solicitud y la '
                'tramitaría en un máximo propuesto de 30 días.',
          ),
          _NoticeSection(
            title: 'Tus solicitudes y cambios',
            content:
                'Puedes escribir a direccion@itcelaya.edu.mx para solicitar '
                'acceso, corrección o eliminación de tus datos. Incluye el '
                'correo de tu cuenta y describe la solicitud; no envíes '
                'contraseñas, tokens ni datos de tarjeta. Puedes cambiar tus '
                'preferencias de avisos desde Perfil y retirar permisos de '
                'notificación o ubicación desde los ajustes del dispositivo.',
          ),
          SizedBox(height: 8),
          Text(
            'Este borrador describe el funcionamiento previsto para la '
            'evaluación académica. Los plazos de 90 y 30 días son propuestas '
            'del equipo y no sustituyen los plazos institucionales ni los '
            'registros requeridos para producción. Los datos institucionales '
            'mostrados fueron confirmados por el equipo.',
          ),
        ],
      ),
    );
  }
}

class _DraftNoticeBanner extends StatelessWidget {
  const _DraftNoticeBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Aviso de Privacidad',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeSection extends StatelessWidget {
  const _NoticeSection({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(content),
        ],
      ),
    );
  }
}
