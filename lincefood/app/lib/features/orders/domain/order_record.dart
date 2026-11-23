import 'package:flutter/widgets.dart' show StringCharacters;

import '../../../core/errors/domain_exception.dart';
import '../../cart/domain/cart.dart';
import '../../catalog/domain/product.dart';
import 'pickup_mode.dart';
import 'order_status.dart';

bool isValidRejectionReason(String reason) {
  final length = reason.trim().characters.length;
  return length >= 5 && length <= 200;
}

class OrderRecord {
  OrderRecord({
    required this.id,
    required this.status,
    required List<CartLine> lines,
    this.ownerUid = '',
    this.folio,
    this.pickupMode = PickupMode.inStore,
    this.isCancelled = false,
    this.createdAt,
    this.rejectionReason,
    this.rejectedAt,
    this.rejectedBy,
    int? totalCents,
  }) : lines = List.unmodifiable(lines),
       totalCents =
           totalCents ??
           lines.fold(0, (total, line) => total + line.totalCents);

  factory OrderRecord.fromMap(String id, Map<dynamic, dynamic> values) {
    final map = <String, dynamic>{};
    values.forEach((key, value) {
      map[key.toString()] = value;
    });

    final rawTotalCents = map['totalCents'];
    final totalCents =
        rawTotalCents is num &&
            rawTotalCents.isFinite &&
            rawTotalCents >= 0 &&
            rawTotalCents % 1 == 0
        ? rawTotalCents.round()
        : _parseTotalCents(map['total']);
    final lines = _parseLines(map['lines']);
    final reason = map['rejectionReason'];
    final rejectedBy = map['rejectedBy'];

    final rawStatus = map['status'] ?? map['estado'];
    final statusCode = rawStatus?.toString().trim().toLowerCase();

    return OrderRecord(
      id: id,
      status: orderStatusFromCode(rawStatus),
      lines: lines,
      ownerUid: (map['ownerUid'] ?? map['uid'] ?? '').toString(),
      folio: map['folio']?.toString(),
      pickupMode: PickupMode.fromCode(map['pickupMode']),
      isCancelled:
          map['isCancelled'] == true ||
          statusCode == 'cancelled' ||
          statusCode == 'canceled' ||
          statusCode == 'cancelado',
      createdAt: _parseDate(map['fecha'] ?? map['createdAt']),
      rejectionReason: reason is String ? reason : null,
      rejectedAt: _parseDate(map['rejectedAt']),
      rejectedBy: rejectedBy is String ? rejectedBy : null,
      totalCents: totalCents,
    );
  }

  final String id;
  final OrderStatus status;
  final List<CartLine> lines;
  final String ownerUid;
  final String? folio;
  final PickupMode pickupMode;
  final bool isCancelled;
  final DateTime? createdAt;
  final String? rejectionReason;
  final DateTime? rejectedAt;
  final String? rejectedBy;
  final int totalCents;

  String get displayFolio => folio?.isNotEmpty == true ? folio! : 'LF-$id';

  Map<String, Object?> toMap() {
    return {
      'folio': displayFolio,
      'ownerUid': ownerUid,
      'lines': [
        for (final line in lines)
          {
            'product': {'id': line.product.id, 'name': line.product.name},
            'variant': line.variant?.label,
            'quantity': line.quantity,
            'priceCents': line.unitPriceCents,
          },
      ],
      'totalCents': totalCents,
      'pickupMode': pickupMode.code,
      'status': status.code,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (rejectedAt != null) 'rejectedAt': rejectedAt!.millisecondsSinceEpoch,
      if (rejectedBy != null) 'rejectedBy': rejectedBy,
    };
  }

  OrderRecord transitionTo(OrderStatus nextStatus) {
    if (nextStatus == OrderStatus.rejected) {
      throw const DomainException('Indica el motivo del rechazo.');
    }
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
        'No se puede cancelar un pedido que ya está en cocina.',
      );
    }

    return _copyWith(status: OrderStatus.cancelled, isCancelled: true);
  }

  OrderRecord reject(String reason, DateTime rejectedAt) {
    if (isCancelled || !status.allowsRejection) {
      throw const DomainException(
        'Solo se pueden rechazar pedidos pagados o confirmados.',
      );
    }
    if (!isValidRejectionReason(reason)) {
      throw const DomainException('Escribe una nota de 5 a 200 caracteres.');
    }
    return _copyWith(
      status: OrderStatus.rejected,
      rejectionReason: reason.trim(),
      rejectedAt: rejectedAt,
    );
  }

  OrderRecord _copyWith({
    OrderStatus? status,
    List<CartLine>? lines,
    bool? isCancelled,
    DateTime? createdAt,
    String? rejectionReason,
    DateTime? rejectedAt,
    int? totalCents,
  }) {
    final updatedLines = lines ?? this.lines;
    return OrderRecord(
      id: id,
      status: status ?? this.status,
      lines: updatedLines,
      ownerUid: ownerUid,
      folio: folio,
      pickupMode: pickupMode,
      isCancelled: isCancelled ?? this.isCancelled,
      createdAt: createdAt ?? this.createdAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectedBy: rejectedBy,
      totalCents:
          totalCents ??
          (lines == null
              ? this.totalCents
              : updatedLines.fold<int>(
                  0,
                  (total, line) => total + line.totalCents,
                )),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } on RangeError {
        return null;
      }
    }
    return null;
  }

  static int _parseTotalCents(Object? value) {
    if (value is! num || !value.isFinite || value < 0) return 0;
    return (value * 100).round();
  }

  static List<CartLine> _parseLines(Object? value) {
    final Iterable<dynamic> entries;
    if (value is List) {
      entries = value;
    } else if (value is Map) {
      entries = value.values;
    } else {
      return const [];
    }

    final lines = <CartLine>[];
    for (final entry in entries) {
      if (entry is! Map) continue;
      final rawProduct = entry['product'];
      final productMap = rawProduct is Map ? rawProduct : const {};
      final productId = (productMap['id'] ?? entry['productId'] ?? '')
          .toString();
      final productName =
          (productMap['name'] ?? entry['productName'] ?? 'Producto').toString();
      final rawPrice = entry['priceCents'] ?? entry['unitPriceCents'];
      final rawQuantity = entry['quantity'];
      if (productId.isEmpty ||
          rawPrice is! num ||
          !rawPrice.isFinite ||
          rawPrice < 0 ||
          rawPrice % 1 != 0 ||
          rawQuantity is! num ||
          rawQuantity < 1 ||
          rawQuantity % 1 != 0) {
        continue;
      }

      final priceCents = rawPrice.round();
      final quantity = rawQuantity.round();
      final rawVariant = entry['variant'] ?? entry['variantLabel'];
      final variantLabel = rawVariant is String && rawVariant.isNotEmpty
          ? rawVariant
          : null;
      if (variantLabel != null && variantLabel.length > 40) continue;
      final variant = variantLabel == null
          ? null
          : ProductVariant(label: variantLabel, priceCents: priceCents);
      final product = Product(
        id: productId,
        name: productName,
        priceCents: variant == null ? priceCents : 0,
        variants: variant == null ? const [] : [variant],
      );

      try {
        lines.add(
          CartLine(product: product, variant: variant, quantity: quantity),
        );
      } on DomainException {
        continue;
      }
    }
    return List.unmodifiable(lines);
  }
}
