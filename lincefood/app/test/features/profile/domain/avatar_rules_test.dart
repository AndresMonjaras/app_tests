import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/profile/domain/avatar_rules.dart';

void main() {
  group('puedeEditarAvatar', () {
    test('permite cambiar la foto de una cuenta de correo', () {
      expect(puedeEditarAvatar('password'), isTrue);
    });

    test('no permite cambiar la foto de cuentas de proveedor', () {
      expect(puedeEditarAvatar('google.com'), isFalse);
      expect(puedeEditarAvatar('apple.com'), isFalse);
      expect(puedeEditarAvatar(''), isFalse);
      expect(puedeEditarAvatar('otro'), isFalse);
    });
  });
}
