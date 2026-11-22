import '../../../core/errors/domain_exception.dart';
import '../../cart/domain/cart.dart';
import 'order_status.dart';

class OrderRecord {
  OrderRecord({
    required this.id,
    required this.status,
    required List<CartLine> lines,
    this.isCancelled = false,
  }) : lines = List.unmodifiable(lines);

  final String id;
  final OrderStatus status;
  final List<CartLine> lines;
  final bool isCancelled;

  OrderRecord transitionTo(OrderStatus nextStatus) {
    if (isCancelled) {
      throw const DomainException('Un pedido cancelado no puede cambiar.');
    }
    if (nextStatus.index <= status.index) {
      throw const DomainException('El estado del pedido solo puede avanzar.');
    }

    return _copyWith(status: nextStatus);
  }

  OrderRecord editLines(List<CartLine> updatedLines) {
    if (isCancelled || status.index >= OrderStatus.paid.index) {
      throw const DomainException(
        'No se pueden editar las líneas después del pago.',
      );
    }

    return _copyWith(lines: updatedLines);
  }

  OrderRecord cancel() {
    if (isCancelled || !canCustomerCancel(status)) {
      throw const DomainException(
        'No se puede cancelar un pedido después del pago.',
      );
    }

    return _copyWith(isCancelled: true);
  }

  OrderRecord _copyWith({
    OrderStatus? status,
    List<CartLine>? lines,
    bool? isCancelled,
  }) {
    return OrderRecord(
      id: id,
      status: status ?? this.status,
      lines: lines ?? this.lines,
      isCancelled: isCancelled ?? this.isCancelled,
    );
  }
}
