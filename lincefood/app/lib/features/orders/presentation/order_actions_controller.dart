import 'dart:convert';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/domain_exception.dart';
import '../../cart/domain/cart.dart';
import '../domain/order_record.dart';
import '../domain/order_status.dart';
import '../domain/orders_repository.dart';
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
  String? _pendingCreateSignature;
  String? _pendingCreateKey;

  @override
  OrderActionsState build() => const OrderActionsState();

  Future<OrderRecord?> submitOrder({
    required String ownerUid,
    required Cart cart,
    required PickupMode pickupMode,
  }) async {
    if (state.isWorking) return null;
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
      final signature = jsonEncode({
        'ownerUid': ownerUid,
        'pickupMode': pickupMode.code,
        'lines': [
          for (final line in cart.lines)
            [line.product.id, line.variant?.label, line.quantity],
        ],
      });
      if (_pendingCreateSignature != signature || _pendingCreateKey == null) {
        _pendingCreateSignature = signature;
        final random = Random.secure();
        _pendingCreateKey = base64Url
            .encode(List.generate(24, (_) => random.nextInt(256)))
            .replaceAll('=', '');
      }
      final order = await _trackWrite(
        'Crear pedido',
        () => repository.createOrder(
          ownerUid: ownerUid,
          cart: cart,
          pickupMode: pickupMode,
          idempotencyKey: _pendingCreateKey!,
        ),
      );
      _pendingCreateSignature = null;
      _pendingCreateKey = null;
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
  }) {
    return _writeWithPermission(
      permission: staffPermissionProvider,
      deniedMessage: 'Solo el personal puede cambiar el estado.',
      operation: 'Cambiar estado del pedido',
      write: (repository) => repository.updateOrderStatus(orderId, status),
    );
  }

  Future<void> rejectOrder({required String orderId, required String reason}) {
    return _writeWithPermission(
      permission: staffPermissionProvider,
      deniedMessage: 'Solo el personal puede rechazar pedidos.',
      operation: 'Rechazar pedido',
      write: (repository) => repository.rejectOrder(orderId, reason),
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> reportIncident({
    required String orderId,
    required String reason,
  }) {
    return _writeWithPermission(
      permission: adminPermissionProvider,
      deniedMessage: 'Solo administración puede marcar incidencias.',
      operation: 'Marcar incidencia',
      write: (repository) => repository.reportIncident(orderId, reason),
    );
  }

  Future<void> resolveIncident({
    required String orderId,
    required String resolution,
  }) {
    return _writeWithPermission(
      permission: adminPermissionProvider,
      deniedMessage: 'Solo administración puede resolver incidencias.',
      operation: 'Resolver incidencia',
      write: (repository) => repository.resolveIncident(orderId, resolution),
    );
  }

  Future<void> _writeWithPermission({
    required FutureProvider<bool> permission,
    required String deniedMessage,
    required String operation,
    required Future<OrderRecord> Function(OrdersRepository repository) write,
  }) async {
    state = const OrderActionsState(isWorking: true);
    try {
      if (!await ref.read(permission.future)) {
        state = OrderActionsState(errorMessage: deniedMessage);
        return;
      }

      final order = await _trackWrite(
        operation,
        () => write(ref.read(ordersRepositoryProvider)),
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
