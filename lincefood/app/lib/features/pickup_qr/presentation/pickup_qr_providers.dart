import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/domain_exception.dart';
import '../../biometrics/biometric_protection.dart';
import '../data/callable_pickup_qr_gateway.dart';
import '../domain/pickup_qr_gateway.dart';

const pickupQrTestCode = 'lincefood://pickup-test/receipt';

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
    .family<PickupQrReveal, ({String orderId, bool requireBiometrics})>((
      ref,
      request,
    ) async {
      final authorized = await ref
          .read(biometricQrProtectionServiceProvider)
          .authorizeQrReveal(
            protectionEnabled:
                request.requireBiometrics || ref.read(protectPickupQrProvider),
          );
      if (!authorized) {
        return const PickupQrReveal.blocked(
          'Confirma tu identidad para mostrar el QR de recogida.',
        );
      }
      final token = await ref
          .read(pickupQrGatewayProvider)
          .issueToken(request.orderId);
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

  Future<void> handleCode(String code) {
    final trimmed = code.trim();
    if (kDebugMode && trimmed == pickupQrTestCode) {
      if (state.busy || state.delivered || state.lastCode == trimmed) {
        return Future<void>.value();
      }
      state = PickupScanState(
        lastCode: trimmed,
        delivered: true,
        message: 'Pedido de prueba entregado (solo en este dispositivo).',
      );
      return Future<void>.value();
    }
    return _deliver(trimmed, (gateway) => gateway.consumeToken(trimmed));
  }

  // Entrega manual con folio. Sigue requiriendo personal autorizado en el servidor.
  Future<void> handleFolio(String folio) {
    final normalized = folio.trim().toUpperCase();
    return _deliver(normalized, (gateway) => gateway.consumeFolio(normalized));
  }

  Future<void> _deliver(
    String input,
    Future<String> Function(PickupQrGateway gateway) send,
  ) async {
    if (input.isEmpty || state.busy || state.delivered) return;
    if (input == state.lastCode) return;

    state = PickupScanState(busy: true, lastCode: input);
    try {
      final orderId = await send(ref.read(pickupQrGatewayProvider));
      state = PickupScanState(
        lastCode: input,
        delivered: true,
        message: 'Pedido $orderId entregado.',
      );
    } on DomainException catch (error) {
      state = PickupScanState(lastCode: input, message: error.message);
    } catch (_) {
      state = PickupScanState(
        lastCode: input,
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
