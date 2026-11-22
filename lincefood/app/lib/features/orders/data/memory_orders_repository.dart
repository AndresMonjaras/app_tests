import 'dart:async';

import '../../../core/errors/domain_exception.dart';
import '../../cart/domain/cart.dart';
import '../domain/order_record.dart';
import '../domain/orders_repository.dart';
import '../domain/order_status.dart';
import '../domain/pickup_mode.dart';

class MemoryOrdersRepository implements OrdersRepository {
  final Map<String, List<OrderRecord>> _actuales = {};
  final Map<String, StreamController<List<OrderRecord>>> _controles = {};
  final StreamController<List<OrderRecord>> _cambiosDePersonal =
      StreamController<List<OrderRecord>>.broadcast();
  final Set<String> _incidentesResueltas = {};
  bool _dispuesto = false;
  int _siguienteFolio = 1;

  @override
  Stream<List<OrderRecord>> watchOrdersFor(String uid) {
    _comprobarDisponible();

    return Stream<List<OrderRecord>>.multi((controller) {
      if (_dispuesto) {
        controller.addError(
          StateError('El repositorio de pedidos ya fue cerrado.'),
        );
        controller.close();
        return;
      }

      controller.add(_actuales[uid] ?? const <OrderRecord>[]);

      final streamController = _controles.putIfAbsent(
        uid,
        () => StreamController<List<OrderRecord>>.broadcast(),
      );
      final subscription = streamController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Stream<List<OrderRecord>> watchPaidOrdersForStaff() {
    _comprobarDisponible();

    return Stream<List<OrderRecord>>.multi((controller) {
      controller.add(_pedidosPagados());
      final subscription = _cambiosDePersonal.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  Future<OrderRecord> createOrder({
    required String ownerUid,
    required Cart cart,
    required PickupMode pickupMode,
    DateTime? createdAt,
  }) async {
    _comprobarDisponible();
    if (cart.isEmpty) throw const DomainException('El carrito está vacío.');

    final sequence = _siguienteFolio++;
    final id = 'pedido-$sequence';
    final order = OrderRecord(
      id: id,
      ownerUid: ownerUid,
      folio: 'LF-${sequence.toString().padLeft(6, '0')}',
      status: OrderStatus.paymentPending,
      lines: cart.lines,
      pickupMode: pickupMode,
      createdAt: createdAt ?? DateTime.now(),
      totalCents: cart.totalCents,
    );
    _guardarPedido(ownerUid, order);
    return order;
  }

  @override
  Future<OrderRecord> updateOrderStatus(
    String orderId,
    OrderStatus status,
  ) async {
    _comprobarDisponible();
    return _cambiarPedido(orderId, (order) {
      if (order.status.nextStaffStep != status) {
        throw const DomainException(
          'Ese cambio de estado no está permitido para este pedido.',
        );
      }
      return order.transitionTo(status);
    });
  }

  @override
  Future<OrderRecord> reportIncident(String orderId, String reason) async {
    _comprobarDisponible();
    if (reason.trim().isEmpty) {
      throw const DomainException('Indica el motivo de la incidencia.');
    }
    return _cambiarPedido(orderId, (order) {
      if (!order.status.allowsIncident) {
        throw const DomainException(
          'Solo un pedido pagado y activo puede pasar a incidencia.',
        );
      }
      return order.transitionTo(OrderStatus.incident);
    });
  }

  @override
  Future<OrderRecord> resolveIncident(String orderId, String resolution) async {
    _comprobarDisponible();
    if (resolution.trim().isEmpty) {
      throw const DomainException('Indica cómo se resolvió la incidencia.');
    }
    final order = _buscarPedido(orderId);
    if (order.status != OrderStatus.incident) {
      throw const DomainException('El pedido no está en incidencia.');
    }
    if (_incidentesResueltas.contains(orderId)) {
      throw const DomainException('La incidencia ya está resuelta.');
    }
    _incidentesResueltas.add(orderId);
    return _cambiarPedido(orderId, (current) => current);
  }

  OrderRecord _buscarPedido(String orderId) {
    for (final orders in _actuales.values) {
      for (final order in orders) {
        if (order.id == orderId) return order;
      }
    }
    throw const DomainException('No se encontró el pedido.');
  }

  Future<OrderRecord> _cambiarPedido(
    String orderId,
    OrderRecord Function(OrderRecord order) cambio,
  ) async {
    for (final entry in _actuales.entries) {
      final index = entry.value.indexWhere((order) => order.id == orderId);
      if (index < 0) continue;

      final updated = cambio(entry.value[index]);
      final orders = [...entry.value];
      orders[index] = updated;
      _actuales[entry.key] = List.unmodifiable(orders);
      _controles[entry.key]?.add(_actuales[entry.key]!);
      _cambiosDePersonal.add(_pedidosPagados());
      return updated;
    }
    throw const DomainException('No se encontró el pedido.');
  }

  void setOrders(String uid, List<OrderRecord> orders) {
    _comprobarDisponible();
    _actuales[uid] = List.unmodifiable(orders);
    _controles[uid]?.add(_actuales[uid]!);
    _cambiosDePersonal.add(_pedidosPagados());
  }

  void dispose() {
    if (_dispuesto) return;
    _dispuesto = true;

    for (final controller in _controles.values) {
      controller.close();
    }
    _controles.clear();
    _cambiosDePersonal.close();
  }

  void _guardarPedido(String uid, OrderRecord order) {
    final orders = [...?_actuales[uid], order];
    _actuales[uid] = List.unmodifiable(orders);
    _controles[uid]?.add(_actuales[uid]!);
    _cambiosDePersonal.add(_pedidosPagados());
  }

  List<OrderRecord> _pedidosPagados() {
    return List.unmodifiable(
      _actuales.values
          .expand((orders) => orders)
          .where(
            (order) =>
                order.status == OrderStatus.paid ||
                order.status == OrderStatus.confirmed ||
                order.status == OrderStatus.preparing ||
                order.status == OrderStatus.ready ||
                (order.status == OrderStatus.incident &&
                    !_incidentesResueltas.contains(order.id)),
          ),
    );
  }

  void _comprobarDisponible() {
    if (_dispuesto) {
      throw StateError('El repositorio de pedidos ya fue cerrado.');
    }
  }
}
