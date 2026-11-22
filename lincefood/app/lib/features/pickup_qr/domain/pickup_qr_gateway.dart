class PickupQrToken {
  const PickupQrToken({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;
}

// El servidor valida el token; la app solo lo muestra o lo envía.
abstract interface class PickupQrGateway {
  Future<PickupQrToken> issueToken(String orderId);

  Future<String> consumeToken(String token);

  // Alternativa manual cuando la cámara falla. El servidor exige que quien
  // llama sea personal autorizado.
  Future<String> consumeFolio(String folio);
}
