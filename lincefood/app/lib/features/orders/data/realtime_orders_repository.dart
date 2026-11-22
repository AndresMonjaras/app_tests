import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../core/errors/domain_exception.dart';
import '../../cart/domain/cart.dart';
import '../domain/order_record.dart';
import '../domain/orders_repository.dart';
import '../domain/order_status.dart';
import '../domain/pickup_mode.dart';

typedef OrderCallable = Future<Object?> Function(
  String name,
  Map<String, Object?> data,
);

class RealtimeOrdersRepository implements OrdersRepository {
  RealtimeOrdersRepository({this.database, this.callable});

  final FirebaseDatabase? database;
  final OrderCallable? callable;

  @override
  Stream<List<OrderRecord>> watchOrdersFor(String uid) {
    final instance = _databaseOrThrow();
    return instance.ref('ordersByUser/$uid').onValue.map((event) {
      final data = event.snapshot.value;
      if (data is! Map) return const <OrderRecord>[];

      final orders = <OrderRecord>[];
      data.forEach((key, rawValue) {
        if (rawValue is! Map) return;
        orders.add(OrderRecord.fromMap(key.toString(), rawValue));
      });
      return List.unmodifiable(orders);
    });
  }

  @override
  Stream<List<OrderRecord>> watchPaidOrdersForStaff() {
    final instance = _databaseOrThrow();
    final ordersReference = instance.ref('orders');

    return Stream<List<OrderRecord>>.multi((controller) {
      final subscriptions = <String, StreamSubscription<DatabaseEvent>>{};
      final ordersById = <String, OrderRecord>{};

      void emitOrders() {
        final orders = ordersById.values.where(_isPaidAndActive).toList()
          ..sort(_newestFirst);
        controller.add(List.unmodifiable(orders));
      }

      final queueSubscription = instance.ref('staffQueue').onValue.listen((
        event,
      ) {
        final orderIds = _orderIdsFromQueue(event.snapshot.value);
        final removedIds = subscriptions.keys
            .where((id) => !orderIds.contains(id))
            .toList();
        for (final id in removedIds) {
          subscriptions.remove(id)?.cancel();
          ordersById.remove(id);
        }

        for (final id in orderIds) {
          if (subscriptions.containsKey(id)) continue;
          subscriptions[id] = ordersReference.child(id).onValue.listen((
            orderEvent,
          ) {
            final value = orderEvent.snapshot.value;
            if (value is Map) {
              ordersById[id] = OrderRecord.fromMap(id, value);
            } else {
              ordersById.remove(id);
            }
            emitOrders();
          }, onError: controller.addError);
        }
        emitOrders();
      }, onError: controller.addError);

      controller.onCancel = () async {
        await queueSubscription.cancel();
        await Future.wait(subscriptions.values.map((item) => item.cancel()));
        subscriptions.clear();
      };
    });
  }

  @override
  Future<OrderRecord> createOrder({
    required String ownerUid,
    required Cart cart,
    required PickupMode pickupMode,
    DateTime? createdAt,
  }) async {
    if (ownerUid.isEmpty) {
      throw const DomainException('Inicia sesión para crear un pedido.');
    }
    if (cart.isEmpty) throw const DomainException('El carrito está vacío.');

    final lines = [
      for (final line in cart.lines)
        {
          'productId': line.product.id,
          if (line.variant != null) 'variantLabel': line.variant!.label,
          'quantity': line.quantity,
        },
    ];
    final result = await _callableOrThrow('createOrder', {
      'lines': lines,
      'pickupMode': pickupMode.code,
    });
    if (result is! Map) {
      throw const DomainException(
        'No se pudo crear el pedido. Inténtalo de nuevo.',
      );
    }
    final id = result['orderId']?.toString();
    if (id == null || id.isEmpty) {
      throw const DomainException('No se pudo generar el folio del pedido.');
    }
    final rawFolio = result['folio'];

    final order = OrderRecord(
      id: id,
      ownerUid: ownerUid,
      folio: rawFolio is String && rawFolio.isNotEmpty
          ? rawFolio
          : _folioFor(id),
      status: OrderStatus.paymentPending,
      lines: cart.lines,
      pickupMode: pickupMode,
      createdAt: createdAt ?? DateTime.now(),
      totalCents: cart.totalCents,
    );

    return order;
  }

  @override
  Future<OrderRecord> updateOrderStatus(String orderId, OrderStatus status) {
    return _orderFromCallable('updateOrderStatus', orderId, {
      'orderId': orderId,
      'status': status.code,
    });
  }

  @override
  Future<OrderRecord> rejectOrder(String orderId, String reason) {
    return _orderFromCallable('rejectOrder', orderId, {
      'orderId': orderId,
      'reason': reason.trim(),
    });
  }

  @override
  Future<OrderRecord> reportIncident(String orderId, String reason) {
    return _orderFromCallable('updateOrderStatus', orderId, {
      'orderId': orderId,
      'status': OrderStatus.incident.code,
      'reason': reason,
    });
  }

  @override
  Future<OrderRecord> resolveIncident(String orderId, String resolution) {
    return _orderFromCallable('resolveOrderIncident', orderId, {
      'orderId': orderId,
      'resolution': resolution,
    });
  }

  Future<OrderRecord> _orderFromCallable(
    String name,
    String orderId,
    Map<String, Object?> data,
  ) async {
    final result = await _callableOrThrow(name, data);
    if (result is! Map || result['order'] is! Map) {
      throw const DomainException('No se pudo leer el pedido actualizado.');
    }
    return OrderRecord.fromMap(orderId, result['order'] as Map);
  }

  Future<Object?> _callableOrThrow(
    String name,
    Map<String, Object?> data,
  ) async {
    try {
      final fakeCallable = callable;
      if (fakeCallable != null) return await fakeCallable(name, data);

      final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable(name)
          .call(data);
      return result.data;
    } on FirebaseFunctionsException catch (error) {
      throw DomainException(_messageForCallableError(error));
    }
  }

  String _messageForCallableError(FirebaseFunctionsException error) {
    if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
      return 'No se pudo conectar con la cafetería. Inténtalo de nuevo.';
    }
    final message = error.message?.trim();
    if (message != null &&
        message.isNotEmpty &&
        message.toLowerCase() != error.code) {
      return message;
    }

    return switch (error.code) {
      'unauthenticated' => 'Inicia sesión para continuar.',
      'permission-denied' => 'No tienes permiso para actualizar este pedido.',
      'invalid-argument' => 'La solicitud del pedido no es válida.',
      'not-found' => 'No se encontró el pedido.',
      'failed-precondition' => 'No se pudo actualizar el pedido.',
      _ => 'No se pudo completar la operación. Inténtalo de nuevo.',
    };
  }

  FirebaseDatabase _databaseOrThrow() {
    final instance = database;
    if (instance == null) {
      throw StateError(
        'Firebase Realtime Database no está configurada. '
        'Configura una instancia antes de leer pedidos.',
      );
    }
    return instance;
  }

  static String _folioFor(String id) {
    final suffix = id.substring(id.length > 6 ? id.length - 6 : 0);
    return 'LF-${suffix.toUpperCase()}';
  }

  static Set<String> _orderIdsFromQueue(Object? value) {
    final ids = <String>{};
    if (value is Map) {
      value.forEach((key, item) {
        final itemId = item is Map ? item['orderId'] : null;
        final id = itemId?.toString() ?? key.toString();
        if (id.isNotEmpty) ids.add(id);
      });
    } else if (value is List) {
      for (final item in value) {
        final id = item is Map ? item['orderId']?.toString() : item?.toString();
        if (id != null && id.isNotEmpty) ids.add(id);
      }
    }
    return ids;
  }

  static bool _isPaidAndActive(OrderRecord order) {
    return order.status == OrderStatus.paid ||
        order.status == OrderStatus.confirmed ||
        order.status == OrderStatus.preparing ||
        order.status == OrderStatus.ready ||
        order.status == OrderStatus.incident;
  }

  static int _newestFirst(OrderRecord first, OrderRecord second) {
    return (second.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(first.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
  }
}
