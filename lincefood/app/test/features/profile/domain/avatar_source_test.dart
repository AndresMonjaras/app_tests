import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/features/profile/domain/avatar_source.dart';

void main() {
  group('resolverFuenteAvatar', () {
    test('usa la foto personalizada de una cuenta de correo', () {
      expect(
        resolverFuenteAvatar(
          proveedor: 'password',
          tieneFotoPersonalizada: true,
          tieneFotoProveedor: false,
        ),
        AvatarSource.correo,
      );
    });

    test('usa iniciales si una cuenta de correo no tiene foto', () {
      expect(
        resolverFuenteAvatar(
          proveedor: 'password',
          tieneFotoPersonalizada: false,
          tieneFotoProveedor: false,
        ),
        AvatarSource.iniciales,
      );
    });

    test('usa la foto del proveedor si está disponible', () {
      expect(
        resolverFuenteAvatar(
          proveedor: 'google.com',
          tieneFotoPersonalizada: false,
          tieneFotoProveedor: true,
        ),
        AvatarSource.proveedor,
      );
    });

    test('ignora la foto personalizada en cuentas de proveedor', () {
      expect(
        resolverFuenteAvatar(
          proveedor: 'apple.com',
          tieneFotoPersonalizada: true,
          tieneFotoProveedor: false,
        ),
        AvatarSource.iniciales,
      );
    });
  });
}
