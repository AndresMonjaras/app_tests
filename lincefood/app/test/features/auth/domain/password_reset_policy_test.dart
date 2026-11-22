import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/auth/domain/password_reset_policy.dart';

void main() {
  group('esCorreoValido', () {
    test('acepta un correo válido y espacios exteriores', () {
      expect(esCorreoValido('usuario@dominio.com'), isTrue);
      expect(esCorreoValido('  usuario@dominio.com  '), isTrue);
    });

    test('rechaza formatos incompletos o con espacios internos', () {
      expect(esCorreoValido(''), isFalse);
      expect(esCorreoValido('usuariodominio.com'), isFalse);
      expect(esCorreoValido('usuario@'), isFalse);
      expect(esCorreoValido('usuario@dominio'), isFalse);
      expect(esCorreoValido('usu ario@dominio.com'), isFalse);
    });
  });

  group('puedeEnviarSolicitud', () {
    final ultimo = DateTime(2024, 1, 1, 12);

    test('permite enviar si nunca se ha enviado', () {
      expect(puedeEnviarSolicitud(ultimoEnvio: null, ahora: ultimo), isTrue);
    });

    test('bloquea antes de 60 segundos y permite al cumplirlos', () {
      expect(
        puedeEnviarSolicitud(
          ultimoEnvio: ultimo,
          ahora: ultimo.add(const Duration(seconds: 59)),
        ),
        isFalse,
      );
      expect(
        puedeEnviarSolicitud(
          ultimoEnvio: ultimo,
          ahora: ultimo.add(const Duration(seconds: 60)),
        ),
        isTrue,
      );
    });
  });
}
