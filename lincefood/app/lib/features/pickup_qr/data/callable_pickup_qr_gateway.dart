import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/errors/domain_exception.dart';
import '../domain/pickup_qr_gateway.dart';

typedef PickupFunctionsFactory = FirebaseFunctions Function();

class CallablePickupQrGateway implements PickupQrGateway {
  CallablePickupQrGateway({PickupFunctionsFactory? functions})
    : _functions =
          functions ??
          (() => FirebaseFunctions.instanceFor(region: 'us-central1'));

  final PickupFunctionsFactory _functions;

  @override
  Future<PickupQrToken> issueToken(String orderId) async {
    final data = await _call('issuePickupToken', {'orderId': orderId});
    final token = data is Map ? data['token'] : null;
    final expiresAt = data is Map ? data['expiresAt'] : null;
    if (token is! String || expiresAt is! num) {
      throw const DomainException('No se pudo generar el QR de recogida.');
    }
    return PickupQrToken(
      token: token,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt.toInt()),
    );
  }

  @override
  Future<String> consumeToken(String token) async {
    final data = await _call('consumePickupToken', {'token': token});
    final orderId = data is Map ? data['orderId'] : null;
    if (orderId is! String) {
      throw const DomainException('No se pudo confirmar la entrega.');
    }
    return orderId;
  }

  Future<Object?> _call(String name, Map<String, Object?> data) async {
    try {
      final result = await _functions().httpsCallable(name).call(data);
      return result.data;
    } on FirebaseFunctionsException catch (error) {
      throw DomainException(_messageFor(error));
    }
  }

  String _messageFor(FirebaseFunctionsException error) {
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) return message;

    return switch (error.code) {
      'unauthenticated' => 'Inicia sesión para continuar.',
      'permission-denied' => 'Solo el personal puede entregar pedidos.',
      'not-found' => 'El código no es válido.',
      'failed-precondition' => 'El código no se puede usar en este momento.',
      _ => 'No se pudo completar la operación. Inténtalo de nuevo.',
    };
  }
}
