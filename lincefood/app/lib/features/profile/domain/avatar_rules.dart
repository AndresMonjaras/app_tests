/// Solo las cuentas de correo pueden cambiar su foto de perfil.
bool puedeEditarAvatar(String proveedor) => proveedor == 'password';
