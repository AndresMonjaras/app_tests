import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lincefood_app/core/errors/domain_exception.dart';
import 'package:lincefood_app/features/biometrics/biometric_protection.dart';
import 'package:lincefood_app/features/pickup_qr/domain/pickup_qr_gateway.dart';
import 'package:lincefood_app/features/pickup_qr/presentation/pickup_qr_providers.dart';

class FakeAuthenticator implements BiometricAuthenticator {
  FakeAuthenticator({this.allow = true});

  bool allow;
  int calls = 0;

  @override
  Future<bool> get isBiometricAvailable async => true;

  @override
  Future<bool> authenticateForPickupQr() async {
    calls++;
    return allow;
  }
}

class FakePickupGateway implements PickupQrGateway {
  final issued = <String>[];
  final consumed = <String>[];
  Completer<void>? consumeGate;
  String? consumeError;

  @override
  Future<PickupQrToken> issueToken(String orderId) async {
    issued.add(orderId);
    return PickupQrToken(
      token: 'token-$orderId',
      expiresAt: DateTime(2026, 11, 22, 12, 30),
    );
  }

  @override
  Future<String> consumeToken(String token) async {
    consumed.add(token);
    if (consumeGate != null) await consumeGate!.future;
    if (consumeError != null) throw DomainException(consumeError!);
    return 'ord1';
  }
}

ProviderContainer _container({
  required FakeAuthenticator authenticator,
  required FakePickupGateway gateway,
  bool protect = true,
}) {
  return ProviderContainer(
    overrides: [
      biometricAuthenticatorProvider.overrideWithValue(authenticator),
      protectPickupQrProvider.overrideWithValue(protect),
      pickupQrGatewayProvider.overrideWithValue(gateway),
    ],
  );
}

// El provider es autoDispose: se mantiene un listener mientras se espera.
Future<PickupQrReveal> _requestPickup(ProviderContainer container, String orderId) {
  final subscription = container.listen(pickupQrProvider(orderId), (_, _) {});
  addTearDown(subscription.close);
  return container.read(pickupQrProvider(orderId).future);
}

void main() {
  test('cancelar la biometría no pide el QR al servidor', () async {
    final authenticator = FakeAuthenticator(allow: false);
    final gateway = FakePickupGateway();
    final container = _container(authenticator: authenticator, gateway: gateway);
    addTearDown(container.dispose);

    final reveal = await _requestPickup(container, 'ord1');

    expect(reveal.token, isNull);
    expect(reveal.blockedReason, isNotNull);
    expect(gateway.issued, isEmpty);
    expect(authenticator.calls, 1);
  });

  test('con biometría aprobada se emite el QR del pedido', () async {
    final gateway = FakePickupGateway();
    final container = _container(
      authenticator: FakeAuthenticator(),
      gateway: gateway,
    );
    addTearDown(container.dispose);

    final reveal = await _requestPickup(container, 'ord1');

    expect(reveal.token?.token, 'token-ord1');
    expect(gateway.issued, ['ord1']);
  });

  test('sin protección activa no se llama al sensor', () async {
    final authenticator = FakeAuthenticator(allow: false);
    final gateway = FakePickupGateway();
    final container = _container(
      authenticator: authenticator,
      gateway: gateway,
      protect: false,
    );
    addTearDown(container.dispose);

    await _requestPickup(container, 'ord1');

    expect(authenticator.calls, 0);
    expect(gateway.issued, ['ord1']);
  });

  test('escanear un código entrega el pedido una vez', () async {
    final gateway = FakePickupGateway();
    final container = _container(
      authenticator: FakeAuthenticator(),
      gateway: gateway,
    );
    addTearDown(container.dispose);
    final controller = container.read(pickupScanControllerProvider.notifier);

    await controller.handleCode('token-ord1');
    await controller.handleCode('token-ord1');

    final state = container.read(pickupScanControllerProvider);
    expect(state.delivered, isTrue);
    expect(state.message, 'Pedido ord1 entregado.');
    expect(gateway.consumed, ['token-ord1']);
  });

  test('lecturas simultáneas no envían el código dos veces', () async {
    final gateway = FakePickupGateway()..consumeGate = Completer<void>();
    final container = _container(
      authenticator: FakeAuthenticator(),
      gateway: gateway,
    );
    addTearDown(container.dispose);
    final controller = container.read(pickupScanControllerProvider.notifier);

    final first = controller.handleCode('token-ord1');
    final second = controller.handleCode('token-ord1');
    gateway.consumeGate!.complete();
    await Future.wait([first, second]);

    expect(gateway.consumed, hasLength(1));
  });

  test('un error del servidor muestra su mensaje y permite reintentar', () async {
    final gateway = FakePickupGateway()
      ..consumeError = 'Este código ya fue usado.';
    final container = _container(
      authenticator: FakeAuthenticator(),
      gateway: gateway,
    );
    addTearDown(container.dispose);
    final controller = container.read(pickupScanControllerProvider.notifier);

    await controller.handleCode('token-ord1');
    final state = container.read(pickupScanControllerProvider);
    expect(state.busy, isFalse);
    expect(state.delivered, isFalse);
    expect(state.message, 'Este código ya fue usado.');

    controller.reset();
    gateway.consumeError = null;
    await controller.handleCode('token-ord1');
    expect(container.read(pickupScanControllerProvider).delivered, isTrue);
  });
}
