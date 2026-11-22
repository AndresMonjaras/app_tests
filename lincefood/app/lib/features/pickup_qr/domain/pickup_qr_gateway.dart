class PickupQrToken {
  const PickupQrToken({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;
}

// El servidor valida el token; la app solo lo muestra o lo envía.
abstract interface class PickupQrGateway {
  Future<PickupQrToken> issueToken(String orderId);

  Future<String> consumeToken(String token);
}
