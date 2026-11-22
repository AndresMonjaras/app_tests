import 'email_verification_policy.dart'
    show canResendVerification, resendCooldownSeconds;

const Duration cooldownSolicitudContrasena = Duration(
  seconds: resendCooldownSeconds,
);

bool esCorreoValido(String correo) {
  final texto = correo.trim();
  if (texto.isEmpty) return false;
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texto);
}

bool puedeEnviarSolicitud({
  required DateTime? ultimoEnvio,
  required DateTime ahora,
}) {
  return canResendVerification(ultimoEnvio, ahora);
}
