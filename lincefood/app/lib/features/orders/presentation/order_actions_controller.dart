import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/domain_exception.dart';
import '../../cart/domain/cart.dart';
import '../domain/order_record.dart';
import '../domain/order_status.dart';
import '../domain/pickup_mode.dart';
import 'orders_providers.dart';

class OrderWriteResult {
  const OrderWriteResult({
    required this.operation,
    required this.succeeded,
    this.errorMessage,
  });

  final String operation;
  final bool succeeded;
  final String? errorMessage;
}

class OrderActionsState {
  const OrderActionsState({
    this.isWorking = false,
    this.errorMessage,
    this.order,
    this.writeResults = const [],
  });

  final bool isWorking;
  final String? errorMessage;
  final OrderRecord? order;
  final List<OrderWriteResult> writeResults;

  OrderActionsState copyWith({
    bool? isWorking,
    String? errorMessage,
    OrderRecord? order,
    List<OrderWriteResult>? writeResults,
    bool clearError = false,
    bool clearOrder = false,
  }) {
    return OrderActionsState(
      isWorking: isWorking ?? this.isWorking,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      order: clearOrder ? null : order ?? this.order,
      writeResults: writeResults ?? this.writeResults,
    );
  }
}

class OrderActionsController extends Notifier<OrderActionsState> {
  @override
  OrderActionsState build() => const OrderActionsState();

  Future<OrderRecord?> submitOrder({
    required String ownerUid,
    required Cart cart,
    required PickupMode pickupMode,
  }) async {
    state = const OrderActionsState(isWorking: true);
    if (ownerUid.isEmpty) {
      state = const OrderActionsState(
        errorMessage: 'Inicia sesión para confirmar tu pedido.',
      );
      return null;
    }
    if (cart.isEmpty) {
      state = const OrderActionsState(
        errorMessage: 'Agrega productos antes de confirmar tu pedido.',
      );
      return null;
    }

    try {
      final repository = ref.read(ordersRepositoryProvider);
      final order = await _trackWrite(
        'Crear pedido',
        () => repository.createOrder(
          ownerUid: ownerUid,
          cart: cart,
          pickupMode: pickupMode,
        ),
      );
      state = state.copyWith(isWorking: false, order: order, clearError: true);
      return order;
    } catch (error) {
      state = state.copyWith(
        isWorking: false,
        errorMessage: _friendlyError(error),
      );
      return null;
    }
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
  }) async {
    state = const OrderActionsState(isWorking: true);
    try {
      final isStaff = await ref.read(staffPermissionProvider.future);
      if (!isStaff) {
        state = const OrderActionsState(
          errorMessage: 'Solo el personal puede cambiar el estado.',
        );
        return;
      }

      final order = await _trackWrite(
        'Cambiar estado del pedido',
        () => ref
            .read(ordersRepositoryProvider)
            .updateOrderStatus(orderId, status),
      );
      state = state.copyWith(isWorking: false, order: order, clearError: true);
    } catch (error) {
      state = state.copyWith(
        isWorking: false,
        errorMessage: _friendlyError(error),
      );
    }
  }

  Future<T> _trackWrite<T>(String operation, Future<T> Function() write) async {
    try {
      final result = await write();
      state = state.copyWith(
        writeResults: [
          ...state.writeResults,
          OrderWriteResult(operation: operation, succeeded: true),
        ],
      );
      return result;
    } catch (error) {
      final message = _friendlyError(error);
      state = state.copyWith(
        writeResults: [
          ...state.writeResults,
          OrderWriteResult(
            operation: operation,
            succeeded: false,
            errorMessage: message,
          ),
        ],
      );
      rethrow;
    }
  }

  String _friendlyError(Object error) {
    if (error is DomainException) return error.message;
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'No se pudo guardar el pedido. Las reglas actuales de '
          'Realtime Database no permiten esta operación.';
    }
    if (error is StateError) return error.message.toString();
    return 'No se pudo completar el pedido. Inténtalo de nuevo.';
  }
}

final orderActionsProvider =
    NotifierProvider<OrderActionsController, OrderActionsState>(
      OrderActionsController.new,
    );

class PickupModeController extends Notifier<PickupMode> {
  @override
  PickupMode build() => PickupMode.inStore;

  void select(PickupMode mode) => state = mode;
}

final pickupModeProvider = NotifierProvider<PickupModeController, PickupMode>(
  PickupModeController.new,
);
