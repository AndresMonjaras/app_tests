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
      final protectionEnabled = ref.read(protectPickupQrProvider);
      final protection = ref.read(biometricQrProtectionServiceProvider);
      final gateway = ref.read(pickupQrGatewayProvider);
      final authorized =
          !protectionEnabled ||
          !await protection.authenticator.isBiometricAvailable ||
          await protection.authorizeQrReveal(protectionEnabled: true);
      if (!authorized) {
        return const PickupQrReveal.blocked(
          'Confirma tu identidad para mostrar el QR de recogida.',
        );
      }
      if (!ref.mounted) {
        return const PickupQrReveal.blocked('El QR no está disponible.');
      }
      final token = await gateway.issueToken(orderId);
      return PickupQrReveal.revealed(token);
    });

class PickupScanState {
  const PickupScanState({
    this.busy = false,
    this.message,
    this.delivered = false,
  });

  final bool busy;
  final String? message;
  final bool delivered;
}

// Ignora lecturas repetidas de la cámara: un mismo código no se envía dos veces.
class PickupScanController extends Notifier<PickupScanState> {
  @override
  PickupScanState build() => const PickupScanState();

  Future<void> handleCode(String code) async {
    final input = code.trim();
    if (input.isEmpty || state.busy || state.message != null) return;

    state = PickupScanState(busy: true);
    try {
      final orderId = await ref
          .read(pickupQrGatewayProvider)
          .consumeToken(input);
      if (!ref.mounted) return;
      state = PickupScanState(
        delivered: true,
        message: 'Pedido $orderId entregado.',
      );
    } on DomainException catch (error) {
      if (!ref.mounted) return;
      state = PickupScanState(message: error.message);
    } catch (_) {
      if (!ref.mounted) return;
      state = PickupScanState(
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
