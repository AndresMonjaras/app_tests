import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/domain_exception.dart';
import '../../biometrics/biometric_protection.dart';
import '../data/callable_pickup_qr_gateway.dart';
import '../domain/pickup_qr_gateway.dart';

final pickupQrGatewayProvider = Provider<PickupQrGateway>((ref) {
  return CallablePickupQrGateway();
});

// Cancelar la biometría no es un error: el QR queda oculto y la pantalla
// ofrece volver a intentarlo.
class PickupQrReveal {
  const PickupQrReveal.revealed(PickupQrToken this.token)
    : blockedReason = null;

  const PickupQrReveal.blocked(String this.blockedReason) : token = null;

  final PickupQrToken? token;
  final String? blockedReason;
}

final pickupQrProvider = FutureProvider.autoDispose
    .family<PickupQrReveal, String>((ref, orderId) async {
      final authorized = await ref
          .read(biometricQrProtectionServiceProvider)
          .authorizeQrReveal(
            protectionEnabled: ref.read(protectPickupQrProvider),
          );
      if (!authorized) {
        return const PickupQrReveal.blocked(
          'Confirma tu identidad para mostrar el QR de recogida.',
        );
      }
      final token = await ref.read(pickupQrGatewayProvider).issueToken(orderId);
      return PickupQrReveal.revealed(token);
    });

class PickupScanState {
  const PickupScanState({
    this.busy = false,
    this.lastCode,
    this.message,
    this.delivered = false,
  });

  final bool busy;
  final String? lastCode;
  final String? message;
  final bool delivered;
}

// Ignora lecturas repetidas de la cámara: un mismo código no se envía dos veces.
class PickupScanController extends Notifier<PickupScanState> {
  @override
  PickupScanState build() => const PickupScanState();

  Future<void> handleCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty || state.busy || state.delivered) return;
    if (trimmed == state.lastCode) return;

    state = PickupScanState(busy: true, lastCode: trimmed);
    try {
      final orderId = await ref
          .read(pickupQrGatewayProvider)
          .consumeToken(trimmed);
      state = PickupScanState(
        lastCode: trimmed,
        delivered: true,
        message: 'Pedido $orderId entregado.',
      );
    } on DomainException catch (error) {
      state = PickupScanState(lastCode: trimmed, message: error.message);
    } catch (_) {
      state = PickupScanState(
        lastCode: trimmed,
        message: 'No se pudo completar la entrega. Inténtalo de nuevo.',
      );
    }
  }

  void reset() => state = const PickupScanState();
}

final pickupScanControllerProvider =
    NotifierProvider.autoDispose<PickupScanController, PickupScanState>(
      PickupScanController.new,
    );
