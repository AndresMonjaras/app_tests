import '../../cart/domain/cart.dart';
import 'order_record.dart';
import 'order_status.dart';
import 'pickup_mode.dart';

abstract interface class OrdersRepository {
  Stream<List<OrderRecord>> watchOrdersFor(String uid);

  Stream<List<OrderRecord>> watchPaidOrdersForStaff();

  Future<OrderRecord> createOrder({
    required String ownerUid,
    required Cart cart,
    required PickupMode pickupMode,
    DateTime? createdAt,
  });

  Future<OrderRecord> updateOrderStatus(String orderId, OrderStatus status);

  /// Solo administración. Pasa un pedido activo a incidencia con motivo.
  Future<OrderRecord> reportIncident(String orderId, String reason);

  /// Solo administración. Cierra una incidencia con una nota.
  Future<OrderRecord> resolveIncident(String orderId, String resolution);
}
