/// Origen del avatar que se muestra en el perfil.
enum AvatarSource {
  /// Foto entregada por el proveedor de autenticación.
  proveedor,

  /// Foto personalizada de una cuenta de correo.
  correo,

  /// Iniciales cuando no hay una foto disponible.
  iniciales,
}

/// Resuelve qué foto puede mostrarse según la cuenta y las fotos disponibles.
AvatarSource resolverFuenteAvatar({
  required String proveedor,
  required bool tieneFotoPersonalizada,
  required bool tieneFotoProveedor,
}) {
  if (proveedor == 'password') {
    return tieneFotoPersonalizada
        ? AvatarSource.correo
        : AvatarSource.iniciales;
  }

  return tieneFotoProveedor ? AvatarSource.proveedor : AvatarSource.iniciales;
}
