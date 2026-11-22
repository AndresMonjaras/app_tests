import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../orders/domain/order_record.dart';
import '../../orders/domain/pickup_mode.dart';
import '../../orders/presentation/order_actions_controller.dart';
import '../../orders/presentation/orders_providers.dart';
import '../../payments/domain/payment_state.dart';
import '../../payments/presentation/payment_providers.dart';
import '../domain/cart.dart';

class CartCheckoutState {
  const CartCheckoutState({this.isWorking = false, this.order, this.message});

  final bool isWorking;
  final OrderRecord? order;
  final String? message;
}

final cartCheckoutProvider =
    NotifierProvider<CartCheckoutController, CartCheckoutState>(
      CartCheckoutController.new,
    );

class CartCheckoutController extends Notifier<CartCheckoutState> {
  Cart? _submittedCart;
  OrderRecord? _pendingOrder;

  @override
  CartCheckoutState build() => const CartCheckoutState();

  bool matches(Cart cart, String? uid, PickupMode pickupMode) =>
      identical(_submittedCart, cart) &&
      _pendingOrder?.ownerUid == uid &&
      _pendingOrder?.pickupMode == pickupMode;

  Future<OrderRecord?> pay({
    required Cart cart,
    required String uid,
    required PickupMode pickupMode,
  }) async {
    if (state.isWorking ||
        cart.isEmpty ||
        uid.isEmpty ||
        !ref.read(paymentConfiguredProvider)) {
      return null;
    }

    final retry = matches(cart, uid, pickupMode);
    if (!retry) _pendingOrder = null;
    _submittedCart = cart;
    OrderRecord? serverOrder = retry ? state.order : null;
    state = CartCheckoutState(isWorking: true, order: serverOrder);
    String? message;

    try {
      final pendingOrder = _pendingOrder ??= await ref
          .read(orderActionsProvider.notifier)
          .submitOrder(ownerUid: uid, cart: cart, pickupMode: pickupMode);
      if (!ref.mounted) return null;
      if (pendingOrder == null) {
        message = ref.read(orderActionsProvider).errorMessage;
        return null;
      }

      // El registro de RTDB contiene los precios calculados por el servidor.
      serverOrder ??= await _readServerOrder(uid, pendingOrder.id);
      if (!ref.mounted || ref.read(uidActivoProvider) != uid) return null;
      state = CartCheckoutState(isWorking: true, order: serverOrder);

      final payment = ref.read(paymentControllerProvider.notifier)..reset();
      await payment.pay(orderId: serverOrder.id);
      if (!ref.mounted || ref.read(uidActivoProvider) != uid) return null;
      final result = ref.read(paymentControllerProvider);
      if (result.status == PaymentStatus.esperandoConfirmacion) {
        _pendingOrder = null;
        return serverOrder;
      }
      message = result.message;
      return null;
    } on TimeoutException {
      message = 'Sin conexión con la cafetería. Inténtalo de nuevo.';
      return null;
    } catch (_) {
      message = 'No se pudo consultar el pedido. Inténtalo de nuevo.';
      return null;
    } finally {
      if (ref.mounted) {
        state = CartCheckoutState(order: serverOrder, message: message);
      }
    }
  }

  Future<OrderRecord> _readServerOrder(String uid, String orderId) async {
    final match = Completer<OrderRecord>();
    final subscription = ref
        .read(ordersRepositoryProvider)
        .watchOrdersFor(uid)
        .expand((orders) => orders)
        .where((order) => order.id == orderId)
        .listen(
          (order) {
            if (!match.isCompleted) match.complete(order);
          },
          onError: (Object error, StackTrace stack) {
            if (!match.isCompleted) match.completeError(error, stack);
          },
          onDone: () {
            if (!match.isCompleted) {
              match.completeError(StateError('No se encontró el pedido.'));
            }
          },
        );
    try {
      return await match.future.timeout(const Duration(seconds: 12));
    } finally {
      unawaited(subscription.cancel());
    }
  }
}
